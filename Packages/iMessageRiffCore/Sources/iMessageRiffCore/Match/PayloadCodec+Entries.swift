extension PayloadCodec {
    static func readEntry(
        _ reader: inout ByteReader, proposalIndex: Int, legacyStart: UInt32?,
        warnings: inout [Warning], config: GameConfig
    ) throws -> MatchEntry? {
        let playerID = try reader.fixed64()
        let count = Int(try reader.byte())
        guard count <= config.payload.maxNicknameBytes, count <= 32 else { throw Failure.invalidStructure }
        let nickname = try Nickname.decode(reader.read(count), config: config)
        let score = try reader.varint()
        let rawAccuracy = try reader.varint()
        let streak = try reader.varint()
        let tries = try reader.byte()
        let level = try reader.byte()
        let title = try reader.byte()
        let frame = try reader.byte()
        let fullCombo: FullComboStatus
        if legacyStart == nil {
            guard let value = FullComboStatus(rawValue: try reader.byte()) else { throw Failure.invalidEnum }
            fullCombo = value
        } else {
            fullCombo = .unknown
        }
        let rawTime = try reader.varint()
        let finishedAt: UInt32
        if let legacyStart {
            let (time, overflow) = legacyStart.addingReportingOverflow(rawTime)
            if overflow {
                warnings.append(
                    .entryDropped(proposalIndex: proposalIndex, playerID: playerID, reason: .invalidTimestamp))
                return nil
            }
            finishedAt = time
        } else {
            finishedAt = rawTime
        }
        if case .replaced(let reason) = nickname {
            warnings.append(.nicknameReplaced(proposalIndex: proposalIndex, playerID: playerID, reason: reason))
        }
        guard let accuracy = UInt16(exactly: rawAccuracy), accuracy <= 10_000 else {
            warnings.append(.entryDropped(proposalIndex: proposalIndex, playerID: playerID, reason: .invalidAccuracy))
            return nil
        }
        do {
            return try MatchEntry(
                playerID: playerID, nickname: nickname.value, score: score, accuracy: accuracy,
                longestStreak: streak, tries: tries, level: level, titleID: title, frameID: frame,
                fullCombo: fullCombo, finishedAt: finishedAt, config: config)
        } catch let error as MatchModelError {
            switch error {
            case .invalidAccuracy, .invalidTryCount, .invalidLevel, .invalidCosmetic, .invalidTimestamp:
                warnings.append(.entryDropped(proposalIndex: proposalIndex, playerID: playerID, reason: error))
                return nil
            default:
                throw error
            }
        }
    }

    static func readShortEntry(
        _ reader: inout ByteReader, warnings: inout [Warning], config: GameConfig
    ) throws -> MatchShortEntry? {
        let playerID = try reader.fixed64()
        let score = try reader.varint()
        let rawAccuracy = try reader.varint()
        let streak = try reader.varint()
        let tries = try reader.byte()
        let time = try reader.varint()
        guard let fullCombo = FullComboStatus(rawValue: try reader.byte()) else { throw Failure.invalidEnum }
        guard let accuracy = UInt16(exactly: rawAccuracy), accuracy <= 10_000 else {
            warnings.append(.previousEntryDropped(playerID: playerID, reason: .invalidAccuracy))
            return nil
        }
        do {
            return try MatchShortEntry(
                playerID: playerID, score: score, accuracy: accuracy, longestStreak: streak,
                tries: tries, finishedAt: time, fullCombo: fullCombo, config: config)
        } catch let error as MatchModelError {
            switch error {
            case .invalidAccuracy, .invalidTryCount, .invalidTimestamp:
                warnings.append(.previousEntryDropped(playerID: playerID, reason: error))
                return nil
            default:
                throw error
            }
        }
    }
}
