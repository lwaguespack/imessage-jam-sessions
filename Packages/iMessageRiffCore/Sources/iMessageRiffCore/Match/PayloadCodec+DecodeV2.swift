import Foundation

extension PayloadCodec {
    static func decodeV2(_ reader: inout ByteReader, config: GameConfig) throws -> Decoded {
        let matchID = try reader.fixed64()
        let mode = try readMode(&reader)
        let rulesVersion = try reader.varint()
        let contentRevision = try reader.varint()
        let round = try reader.varint()
        var warnings: [Warning] = []
        let (history, previousChart) = try readHistory(&reader, mode: mode, warnings: &warnings, config: config)
        let proposalCount = Int(try reader.byte())
        let maxProposals = mode == .duel ? config.payload.maxDuelProposals : config.payload.maxRoundProposals
        guard proposalCount > 0, proposalCount <= maxProposals else { throw Failure.invalidStructure }
        var proposals: [MatchProposal] = []
        var encodedEntries = 0
        for proposalIndex in 0..<proposalCount {
            let chart = try readChart(&reader, config: config)
            let starter = try reader.fixed64()
            let startTime = try reader.varint()
            let roster = try reader.byte()
            let deadline = try reader.byte()
            let closedAt = try reader.varint()
            let entryCount = Int(try reader.byte())
            encodedEntries += entryCount
            let maxEntries = mode == .duel ? config.payload.maxDuelEntries : config.payload.maxEntries
            guard encodedEntries <= maxEntries else { throw Failure.invalidStructure }
            var entries: [MatchEntry] = []
            for _ in 0..<entryCount {
                if let entry = try readEntry(
                    &reader, proposalIndex: proposalIndex, legacyStart: nil, warnings: &warnings, config: config)
                {
                    entries.append(entry)
                }
            }
            let descriptor = try MatchDescriptor(
                chart: chart, starter: starter, startTime: startTime, rosterSize: roster,
                deadlineHours: deadline, mode: mode, config: config)
            proposals.append(
                try MatchProposal(descriptor: descriptor, closedAt: closedAt == 0 ? nil : closedAt, entries: entries))
        }
        let state = try MatchState(
            matchID: matchID, mode: mode, rulesVersion: rulesVersion, contentRevision: contentRevision,
            round: round, history: history, proposals: proposals, config: config)
        let referenced = (previousChart.map { [$0] } ?? []) + proposals.map(\.descriptor.chart)
        return Decoded(wireVersion: 2, state: state, warnings: warnings, referencedCharts: referenced)
    }

    static func readMode(_ reader: inout ByteReader) throws -> MatchMode {
        guard let mode = MatchMode(rawValue: try reader.byte()) else { throw Failure.invalidEnum }
        return mode
    }

    static func readChart(_ reader: inout ByteReader, config: GameConfig) throws -> MatchChart {
        let count = Int(try reader.byte())
        guard count > 0, count <= config.payload.maxSongIDBytes, count <= 24 else {
            throw Failure.invalidStructure
        }
        guard let song = String(bytes: try reader.read(count), encoding: .utf8) else {
            throw Failure.invalidStructure
        }
        guard try reader.byte() == 0 else { throw Failure.invalidEnum }
        let difficulty: Difficulty
        switch try reader.byte() {
        case 0: difficulty = .easy
        case 1: difficulty = .medium
        case 2: difficulty = .hard
        case 3: difficulty = .expert
        default: throw Failure.invalidEnum
        }
        return try MatchChart(
            songID: song, part: .lead, difficulty: difficulty, chartHash: reader.fixed32(), config: config)
    }

    static func readHistory(
        _ reader: inout ByteReader, mode: MatchMode, warnings: inout [Warning], config: GameConfig
    ) throws -> (MatchHistory, MatchChart?) {
        let seriesCount = Int(try reader.byte())
        guard seriesCount <= 2, mode == .duel || seriesCount == 0 else { throw Failure.invalidStructure }
        var series: [MatchHistory.SeriesWin] = []
        for _ in 0..<seriesCount {
            series.append(.init(playerID: try reader.fixed64(), wins: try reader.varint()))
        }
        let flag = try reader.byte()
        guard flag <= 1 else { throw Failure.invalidEnum }
        let chart = try flag == 1 ? readChart(&reader, config: config) : nil
        let count = Int(try reader.byte())
        guard count <= (mode == .duel ? 2 : 3), (flag == 0) == (count == 0) else {
            throw Failure.invalidStructure
        }
        var previous: [MatchShortEntry] = []
        for _ in 0..<count {
            if let entry = try readShortEntry(&reader, warnings: &warnings, config: config) {
                previous.append(entry)
            }
        }
        let history = try MatchHistory(
            series: series, previousChart: previous.isEmpty ? nil : chart, previous: previous)
        return (history, chart)
    }
}
