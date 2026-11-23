/// Versioned, authenticated match bytes. The tag is an integrity check, not a secret.
public enum PayloadCodec {
    public enum Failure: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case tooLarge
        case truncated
        case invalidVarint
        case nonCanonicalVarint
        case invalidEnum
        case invalidStructure
        case invalidTag
        case newerVersion(UInt8)
        case unsupportedVersion(UInt8)
        case unsupportedLegacy
        case invalidModel(MatchModelError)
        case invalidNicknameConfiguration
    }

    public enum Warning: Equatable, Sendable {
        case nicknameReplaced(proposalIndex: Int, playerID: UInt64, reason: Nickname.Error)
        case entryDropped(proposalIndex: Int, playerID: UInt64, reason: MatchModelError)
        case previousEntryDropped(playerID: UInt64, reason: MatchModelError)
    }

    public struct Decoded: Equatable, Sendable {
        public let wireVersion: UInt8
        public let state: MatchState
        public let warnings: [Warning]
    }

    public static func encode(_ state: MatchState, config: GameConfig) throws -> [UInt8] {
        try validateConfiguration(config)
        do {
            _ = try MatchMerge.merge(state, state, config: config)
        } catch let error as MatchModelError {
            throw Failure.invalidModel(error)
        }
        let body = [UInt8(config.payload.schemaVersion)] + state.canonicalBody
        let tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v2".utf8) + body, key: config.payload.integrityKeyV2)
        let bytes = body + tag.prefix(config.payload.tagBytes)
        guard bytes.count <= config.payload.maxURLCharacters * 3 / 4,
            state.mode != .duel || bytes.count <= config.payload.maxDuelEncodedBytes
        else { throw Failure.tooLarge }
        return bytes
    }

    public static func decode(_ bytes: [UInt8], config: GameConfig) throws -> Decoded {
        try validateConfiguration(config)
        guard bytes.count <= config.payload.maxURLCharacters * 3 / 4 else { throw Failure.tooLarge }
        guard let version = bytes.first else { throw Failure.truncated }
        if version > 2 { throw Failure.newerVersion(version) }
        guard version == 1 || version == 2 else { throw Failure.unsupportedVersion(version) }
        guard bytes.count >= 1 + config.payload.tagBytes else { throw Failure.truncated }
        let body = Array(bytes.dropLast(config.payload.tagBytes))
        let key = version == 1 ? config.payload.integrityKeyV1 : config.payload.integrityKeyV2
        let label = version == 1 ? "riff-match-v1" : "riff-match-v2"
        let expected = HMACSHA256.authenticationCode(for: Array(label.utf8) + body, key: key)
        var difference: UInt8 = 0
        for (left, right) in zip(bytes.suffix(config.payload.tagBytes), expected.prefix(config.payload.tagBytes)) {
            difference |= left ^ right
        }
        guard difference == 0 else { throw Failure.invalidTag }

        var reader = ByteReader(Array(body.dropFirst()))
        do {
            let result = try version == 1 ? decodeV1(&reader, config: config) : decodeV2(&reader, config: config)
            guard reader.remaining == 0 else { throw Failure.invalidStructure }
            guard result.state.mode != .duel || bytes.count <= config.payload.maxDuelEncodedBytes else {
                throw Failure.tooLarge
            }
            return result
        } catch let error as ByteReader.Error {
            switch error {
            case .truncated: throw Failure.truncated
            case .invalidVarint: throw Failure.invalidVarint
            case .nonCanonicalVarint: throw Failure.nonCanonicalVarint
            }
        } catch let error as MatchModelError {
            throw Failure.invalidModel(error)
        } catch is Nickname.Error {
            throw Failure.invalidNicknameConfiguration
        }
    }

    static func validateConfiguration(_ config: GameConfig) throws {
        do {
            try MatchConfiguration.validate(config)
        } catch MatchModelError.invalidConfiguration {
            throw Failure.invalidConfiguration
        }
        let payload = config.payload
        guard payload.schemaVersion == 2, payload.matchIDBytes == 8, payload.playerIDBytes == 8,
            payload.chartHashBytes == 4, payload.tagBytes == 8,
            payload.integrityKeyV1.count == 32, payload.integrityKeyV2.count == 32,
            (1...5_000).contains(payload.maxURLCharacters), (1...1_024).contains(payload.maxDuelEncodedBytes)
        else { throw Failure.invalidConfiguration }
    }
}
