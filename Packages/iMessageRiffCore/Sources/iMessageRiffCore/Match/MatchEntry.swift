public enum MatchMode: UInt8, Codable, Equatable, Sendable {
    case duel = 0
    case round = 1
}

public enum FullComboStatus: UInt8, Codable, Equatable, Sendable {
    case no = 0
    case yes = 1
    case unknown = 2
}

public enum MatchModelError: Swift.Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidSongID
    case invalidAccuracy
    case invalidTryCount
    case invalidLevel
    case invalidCosmetic
    case invalidTimestamp
    case invalidRoster
    case invalidDeadline
    case invalidClosure
    case invalidHistory
    case invalidRound
    case emptyProposals
    case duplicatePlayer(UInt64)
    case duplicateProposal
    case capacityExceeded(proposals: Int, entries: Int)
    case differentMatch
    case incompatibleMetadata
}

/// One submitted run. The score ceiling and note-count bounds are checked against the chart on decode.
public struct MatchEntry: Equatable, Sendable {
    public let playerID: UInt64
    public let nickname: String
    public let score: UInt32
    public let accuracy: UInt16
    public let longestStreak: UInt32
    public let tries: UInt8
    public let level: UInt8
    public let titleID: UInt8
    public let frameID: UInt8
    public let fullCombo: FullComboStatus
    public let finishedAt: UInt32

    public init(
        playerID: UInt64, nickname: String, score: UInt32, accuracy: UInt16, longestStreak: UInt32,
        tries: UInt8, level: UInt8, titleID: UInt8, frameID: UInt8,
        fullCombo: FullComboStatus, finishedAt: UInt32, config: GameConfig
    ) throws {
        try MatchConfiguration.validate(config)
        let nickname = try Nickname.normalize(nickname, config: config)
        try Self.validateCommon(accuracy: accuracy, tries: tries, finishedAt: finishedAt, config: config)
        guard level > 0, Int(level) <= config.levels.maxLevel else { throw MatchModelError.invalidLevel }
        guard Int(titleID) <= config.unlocks.titles, Int(frameID) <= config.unlocks.scoreCardFrames else {
            throw MatchModelError.invalidCosmetic
        }
        self.playerID = playerID
        self.nickname = nickname
        self.score = score
        self.accuracy = accuracy
        self.longestStreak = longestStreak
        self.tries = tries
        self.level = level
        self.titleID = titleID
        self.frameID = frameID
        self.fullCombo = fullCombo
        self.finishedAt = finishedAt
    }

    func validate(config: GameConfig) throws {
        _ = try MatchEntry(
            playerID: playerID, nickname: nickname, score: score, accuracy: accuracy,
            longestStreak: longestStreak, tries: tries, level: level, titleID: titleID,
            frameID: frameID, fullCombo: fullCombo, finishedAt: finishedAt, config: config)
    }

    static func validateCommon(
        accuracy: UInt16, tries: UInt8, finishedAt: UInt32, config: GameConfig
    ) throws {
        try MatchConfiguration.validate(config)
        guard accuracy <= 10_000 else { throw MatchModelError.invalidAccuracy }
        guard tries > 0, Int(tries) <= config.match.maxTries else { throw MatchModelError.invalidTryCount }
        guard finishedAt > 0 else { throw MatchModelError.invalidTimestamp }
    }

    var canonicalBytes: [UInt8] {
        var writer = ByteWriter()
        writer.fixed64(playerID)
        let name = Array(nickname.utf8)
        writer.byte(UInt8(name.count))
        writer.append(name)
        writer.varint(score)
        writer.varint(UInt32(accuracy))
        writer.varint(longestStreak)
        writer.byte(tries)
        writer.byte(level)
        writer.byte(titleID)
        writer.byte(frameID)
        writer.byte(fullCombo.rawValue)
        writer.varint(finishedAt)
        return writer.bytes
    }
}

/// The fields retained in the previous-round summary.
public struct MatchShortEntry: Equatable, Sendable {
    public let playerID: UInt64
    public let score: UInt32
    public let accuracy: UInt16
    public let longestStreak: UInt32
    public let tries: UInt8
    public let finishedAt: UInt32
    public let fullCombo: FullComboStatus

    public init(
        playerID: UInt64, score: UInt32, accuracy: UInt16, longestStreak: UInt32,
        tries: UInt8, finishedAt: UInt32, fullCombo: FullComboStatus, config: GameConfig
    ) throws {
        try MatchEntry.validateCommon(accuracy: accuracy, tries: tries, finishedAt: finishedAt, config: config)
        self.playerID = playerID
        self.score = score
        self.accuracy = accuracy
        self.longestStreak = longestStreak
        self.tries = tries
        self.finishedAt = finishedAt
        self.fullCombo = fullCombo
    }

    public init(_ entry: MatchEntry) {
        playerID = entry.playerID
        score = entry.score
        accuracy = entry.accuracy
        longestStreak = entry.longestStreak
        tries = entry.tries
        finishedAt = entry.finishedAt
        fullCombo = entry.fullCombo
    }

    func validate(config: GameConfig) throws {
        try MatchEntry.validateCommon(accuracy: accuracy, tries: tries, finishedAt: finishedAt, config: config)
    }

    func write(to writer: inout ByteWriter) {
        writer.fixed64(playerID)
        writer.varint(score)
        writer.varint(UInt32(accuracy))
        writer.varint(longestStreak)
        writer.byte(tries)
        writer.varint(finishedAt)
        writer.byte(fullCombo.rawValue)
    }
}
