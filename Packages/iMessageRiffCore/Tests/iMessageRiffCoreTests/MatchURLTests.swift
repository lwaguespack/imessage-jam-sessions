import Testing
import iMessageRiffCore

@Suite("Match URLs")
struct MatchURLTests {
    @Test("All supported forms round-trip a payload")
    func forms() throws {
        let payload: [UInt8] = [0, 1, 2, 0xFB, 0xFF]
        for form in MatchURL.Form.allCases {
            let url = try MatchURL.make(payload: payload, form: form, host: "riff.invalid", config: .standard)
            #expect(try MatchURL.extract(url, host: "riff.invalid", config: .standard) == payload)
        }
        let data = try MatchURL.make(payload: payload, form: .data, config: .standard)
        #expect(try MatchURL.extract(data, config: .standard) == payload)
    }

    @Test("Wrong hosts, extra query fields, noncanonical data and oversized URLs are rejected")
    func rejectsInvalidURLs() throws {
        let payload: [UInt8] = [1, 2, 3]
        let url = try MatchURL.make(payload: payload, form: .query, host: "riff.invalid", config: .standard)
        #expect(throws: MatchURL.Error.invalidURL) {
            try MatchURL.extract(url, host: "other.invalid", config: .standard)
        }
        #expect(throws: MatchURL.Error.invalidEncoding) {
            try MatchURL.extract(url + "&x=1", host: "riff.invalid", config: .standard)
        }
        #expect(throws: MatchURL.Error.invalidEncoding) {
            try MatchURL.extract("data:text/plain,Zh", config: .standard)
        }
        #expect(throws: MatchURL.Error.invalidHost) {
            try MatchURL.make(payload: payload, form: .fragment, host: "Bad Host", config: .standard)
        }
        var short = GameConfig.standard
        short.payload.maxURLCharacters = 10
        #expect(throws: MatchURL.Error.tooLong) {
            try MatchURL.make(payload: payload, form: .data, config: short)
        }
    }
}
