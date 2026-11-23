/// A chart identity carried by a round proposal.
public struct MatchChart: Equatable, Sendable {
    public let songID: String
    public let part: Part
    public let difficulty: Difficulty
    public let chartHash: UInt32

    public init(songID: String, part: Part, difficulty: Difficulty, chartHash: UInt32, config: GameConfig) throws {
        guard (1...24).contains(config.payload.maxSongIDBytes) else {
            throw MatchModelError.invalidConfiguration
        }
        guard SongID.isValid(songID, maxBytes: config.payload.maxSongIDBytes) else {
            throw MatchModelError.invalidSongID
        }
        self.songID = songID
        self.part = part
        self.difficulty = difficulty
        self.chartHash = chartHash
    }

    func validate(config: GameConfig) throws {
        _ = try MatchChart(
            songID: songID, part: part, difficulty: difficulty, chartHash: chartHash, config: config)
    }
}

public struct MatchDescriptor: Equatable, Sendable {
    public let chart: MatchChart
    public let starter: UInt64
    public let startTime: UInt32
    public let rosterSize: UInt8
    public let deadlineHours: UInt8

    public init(
        chart: MatchChart, starter: UInt64, startTime: UInt32, rosterSize: UInt8,
        deadlineHours: UInt8, mode: MatchMode, config: GameConfig
    ) throws {
        guard startTime > 0 else { throw MatchModelError.invalidTimestamp }
        self.chart = chart
        self.starter = starter
        self.startTime = startTime
        self.rosterSize = rosterSize
        self.deadlineHours = deadlineHours
        try validate(mode: mode, config: config)
    }

    func validate(mode: MatchMode, config: GameConfig) throws {
        try chart.validate(config: config)
        switch mode {
        case .duel:
            guard rosterSize == 2 else { throw MatchModelError.invalidRoster }
            guard deadlineHours == 0 else { throw MatchModelError.invalidDeadline }
        case .round:
            guard rosterSize >= 3, Int(rosterSize) <= config.payload.maxEntries, rosterSize <= 32 else {
                throw MatchModelError.invalidRoster
            }
            guard deadlineHours > 0 else { throw MatchModelError.invalidDeadline }
        }
    }

    static func precedes(_ left: MatchDescriptor, _ right: MatchDescriptor) -> Bool {
        if left.startTime != right.startTime { return left.startTime < right.startTime }
        if left.starter != right.starter { return left.starter < right.starter }
        if left.chart.songID != right.chart.songID {
            return left.chart.songID.utf8.lexicographicallyPrecedes(right.chart.songID.utf8)
        }
        if left.chart.part.matchWireValue != right.chart.part.matchWireValue {
            return left.chart.part.matchWireValue < right.chart.part.matchWireValue
        }
        if left.chart.difficulty.matchWireValue != right.chart.difficulty.matchWireValue {
            return left.chart.difficulty.matchWireValue < right.chart.difficulty.matchWireValue
        }
        if left.chart.chartHash != right.chart.chartHash { return left.chart.chartHash < right.chart.chartHash }
        if left.rosterSize != right.rosterSize { return left.rosterSize < right.rosterSize }
        return left.deadlineHours < right.deadlineHours
    }
}

public struct MatchProposal: Equatable, Sendable {
    public let descriptor: MatchDescriptor
    public let closedAt: UInt32?
    public let entries: [MatchEntry]

    public init(descriptor: MatchDescriptor, closedAt: UInt32? = nil, entries: [MatchEntry]) throws {
        if closedAt == 0 { throw MatchModelError.invalidTimestamp }
        guard entries.count <= Int(UInt8.max) else {
            throw MatchModelError.capacityExceeded(proposals: 1, entries: entries.count)
        }
        let sorted = entries.sorted { $0.playerID < $1.playerID }
        for (left, right) in zip(sorted, sorted.dropFirst()) where left.playerID == right.playerID {
            throw MatchModelError.duplicatePlayer(left.playerID)
        }
        self.descriptor = descriptor
        self.closedAt = closedAt
        self.entries = sorted
    }
}

public struct MatchHistory: Equatable, Sendable {
    public struct SeriesWin: Equatable, Sendable {
        public let playerID: UInt64
        public let wins: UInt32

        public init(playerID: UInt64, wins: UInt32) {
            self.playerID = playerID
            self.wins = wins
        }
    }

    public let series: [SeriesWin]
    public let previous: [MatchShortEntry]

    public init(series: [SeriesWin] = [], previous: [MatchShortEntry] = []) throws {
        guard series.count <= 2, previous.count <= 3 else { throw MatchModelError.invalidHistory }
        let sortedSeries = series.sorted { $0.playerID < $1.playerID }
        let sortedPrevious = previous.sorted { $0.playerID < $1.playerID }
        for (left, right) in zip(sortedSeries, sortedSeries.dropFirst()) where left.playerID == right.playerID {
            throw MatchModelError.duplicatePlayer(left.playerID)
        }
        for (left, right) in zip(sortedPrevious, sortedPrevious.dropFirst()) where left.playerID == right.playerID {
            throw MatchModelError.duplicatePlayer(left.playerID)
        }
        self.series = sortedSeries
        self.previous = sortedPrevious
    }

    var canonicalBytes: [UInt8] {
        var writer = ByteWriter()
        writer.byte(UInt8(series.count))
        for item in series {
            writer.fixed64(item.playerID)
            writer.varint(item.wins)
        }
        writer.byte(UInt8(previous.count))
        for item in previous { item.write(to: &writer) }
        return writer.bytes
    }
}

public struct MatchState: Equatable, Sendable {
    public let matchID: UInt64
    public let mode: MatchMode
    public let rulesVersion: UInt32
    public let contentRevision: UInt32
    public let round: UInt32
    public let history: MatchHistory
    public let proposals: [MatchProposal]

    public init(
        matchID: UInt64, mode: MatchMode, rulesVersion: UInt32, contentRevision: UInt32,
        round: UInt32, history: MatchHistory, proposals: [MatchProposal], config: GameConfig
    ) throws {
        guard rulesVersion > 0, contentRevision > 0, round > 0 else { throw MatchModelError.invalidRound }
        guard !proposals.isEmpty else { throw MatchModelError.emptyProposals }
        guard (3...32).contains(config.payload.maxEntries),
            (2...8).contains(config.payload.maxDuelEntries),
            (1...4).contains(config.payload.maxDuelProposals),
            (1...8).contains(config.payload.maxRoundProposals),
            (1...99).contains(config.match.maxTries),
            (6...16).contains(config.payload.maxNicknameCharacters),
            (6...32).contains(config.payload.maxNicknameBytes),
            (1...24).contains(config.payload.maxSongIDBytes)
        else { throw MatchModelError.invalidConfiguration }
        guard mode == .duel || history.series.isEmpty,
            history.previous.count <= (mode == .duel ? 2 : 3),
            round != 1 || history.previous.isEmpty
        else { throw MatchModelError.invalidHistory }
        for item in history.previous { try item.validate(config: config) }
        for proposal in proposals {
            try proposal.descriptor.validate(mode: mode, config: config)
            for entry in proposal.entries { try entry.validate(config: config) }
        }
        let sorted = proposals.sorted { MatchDescriptor.precedes($0.descriptor, $1.descriptor) }
        for (left, right) in zip(sorted, sorted.dropFirst()) where left.descriptor == right.descriptor {
            throw MatchModelError.duplicateProposal
        }
        let count = sorted.reduce(0) { $0 + $1.entries.count }
        let maxProposals = mode == .duel ? config.payload.maxDuelProposals : config.payload.maxRoundProposals
        let maxEntries = mode == .duel ? config.payload.maxDuelEntries : config.payload.maxEntries
        guard sorted.count <= maxProposals, count <= maxEntries else {
            throw MatchModelError.capacityExceeded(proposals: sorted.count, entries: count)
        }
        self.matchID = matchID
        self.mode = mode
        self.rulesVersion = rulesVersion
        self.contentRevision = contentRevision
        self.round = round
        self.history = history
        self.proposals = sorted
    }

    public var winningProposal: MatchProposal { proposals[0] }

    /// Entries from every proposal for the winning chart, deduplicated by player.
    public var winningEntries: [MatchEntry] {
        var result: [MatchEntry] = []
        for proposal in proposals where proposal.descriptor.chart == winningProposal.descriptor.chart {
            for entry in proposal.entries { MatchMerge.add(entry, to: &result) }
        }
        return result.sorted { $0.playerID < $1.playerID }
    }

    var canonicalBody: [UInt8] {
        var writer = ByteWriter()
        writer.fixed64(matchID)
        writer.byte(mode.rawValue)
        writer.varint(rulesVersion)
        writer.varint(contentRevision)
        writer.varint(round)
        writer.append(history.canonicalBytes)
        writer.byte(UInt8(proposals.count))
        for proposal in proposals {
            let descriptor = proposal.descriptor
            let song = Array(descriptor.chart.songID.utf8)
            writer.byte(UInt8(song.count))
            writer.append(song)
            writer.byte(descriptor.chart.part.matchWireValue)
            writer.byte(descriptor.chart.difficulty.matchWireValue)
            writer.fixed32(descriptor.chart.chartHash)
            writer.fixed64(descriptor.starter)
            writer.varint(descriptor.startTime)
            writer.byte(descriptor.rosterSize)
            writer.byte(descriptor.deadlineHours)
            writer.varint(proposal.closedAt ?? 0)
            writer.byte(UInt8(proposal.entries.count))
            for entry in proposal.entries { writer.append(entry.canonicalBytes) }
        }
        return writer.bytes
    }
}

extension Part {
    var matchWireValue: UInt8 {
        switch self {
        case .lead: 0
        }
    }
}

extension Difficulty {
    var matchWireValue: UInt8 {
        switch self {
        case .easy: 0
        case .medium: 1
        case .hard: 2
        case .expert: 3
        }
    }
}
