import Foundation

/// Normalises and validates the nickname carried by a match entry.
public enum Nickname {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case empty
        case tooManyCharacters
        case tooManyBytes
        case forbiddenScalar(UInt32)
    }

    public enum Decoded: Equatable, Sendable {
        case valid(String)
        case replaced(reason: Error)

        public var value: String {
            switch self {
            case .valid(let value): value
            case .replaced: "Player"
            }
        }
    }

    public static func normalize(_ input: String, config: GameConfig) throws -> String {
        guard config.payload.maxNicknameCharacters >= 6, config.payload.maxNicknameBytes >= 6 else {
            throw Error.invalidConfiguration
        }
        let value = input.precomposedStringWithCanonicalMapping
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Error.empty }
        guard value.count <= config.payload.maxNicknameCharacters else { throw Error.tooManyCharacters }
        guard value.utf8.count <= config.payload.maxNicknameBytes else { throw Error.tooManyBytes }
        for scalar in value.unicodeScalars {
            let code = scalar.value
            if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar)
                || code == 0x061C || code == 0x200E || code == 0x200F
                || (0x202A...0x202E).contains(code) || (0x2066...0x2069).contains(code)
            {
                throw Error.forbiddenScalar(code)
            }
        }
        return value
    }

    /// Invalid received names use the documented fallback and expose the reason to the caller.
    public static func decode(_ input: String, config: GameConfig) throws -> Decoded {
        do {
            return .valid(try normalize(input, config: config))
        } catch let error as Error {
            guard error != .invalidConfiguration else { throw error }
            return .replaced(reason: error)
        }
    }
}
