import Testing
import iMessageRiffCore

@Suite("Match nicknames")
struct NicknameTests {
    @Test("Input is NFC-normalised and limited by characters and UTF-8 bytes")
    func normalizationAndBounds() throws {
        let config = GameConfig.standard
        #expect(try Nickname.normalize("e\u{301}", config: config) == "\u{e9}")
        #expect(throws: Nickname.Error.empty) { try Nickname.normalize("  ", config: config) }
        #expect(throws: Nickname.Error.tooManyCharacters) {
            try Nickname.normalize(String(repeating: "a", count: 17), config: config)
        }
        #expect(throws: Nickname.Error.tooManyBytes) {
            try Nickname.normalize(String(repeating: "😀", count: 9), config: config)
        }
    }

    @Test("Unsafe received names are replaced with a reported reason")
    func unsafeNames() throws {
        let config = GameConfig.standard
        #expect(throws: Nickname.Error.forbiddenScalar(0x202E)) {
            try Nickname.normalize("A\u{202E}B", config: config)
        }
        let decoded = try Nickname.decode("A\nB", config: config)
        #expect(decoded == .replaced(reason: .forbiddenScalar(10)))
        #expect(decoded.value == "Player")
    }
}
