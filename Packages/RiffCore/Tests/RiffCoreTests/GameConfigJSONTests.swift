import Foundation
import RiffCore
import Testing

@Suite("GameConfig JSON")
struct GameConfigJSONTests {
    private func canonicalText(_ config: GameConfig) throws -> String {
        String(decoding: try CanonicalJSON.encode(config), as: UTF8.self)
    }

    /// The keys one level into a canonical document: lines indented by exactly two spaces.
    private func topLevelKeys(of text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("  \""), let end = line.dropFirst(3).firstIndex(of: "\"") else { return nil }
            return String(line.dropFirst(3)[..<end])
        }
    }

    @Test("The standard config survives a round trip through Foundation's JSON coder")
    func roundTripsThroughFoundation() throws {
        let data = try JSONEncoder().encode(GameConfig.standard)
        #expect(try JSONDecoder().decode(GameConfig.self, from: data) == GameConfig.standard)
    }

    @Test("The standard config survives a round trip through canonical JSON")
    func roundTripsThroughCanonicalJSON() throws {
        let data = try CanonicalJSON.encode(GameConfig.standard)
        #expect(try JSONDecoder().decode(GameConfig.self, from: data) == GameConfig.standard)
    }

    @Test("Encoding is deterministic: the same bytes every time, and again after a round trip")
    func encodingIsDeterministic() throws {
        let first = try CanonicalJSON.encode(GameConfig.standard)
        let second = try CanonicalJSON.encode(GameConfig.standard)
        #expect(first == second)

        let decoded = try JSONDecoder().decode(GameConfig.self, from: first)
        #expect(try CanonicalJSON.encode(decoded) == first)
    }

    @Test("The document is plain ASCII with Unix newlines and exactly one trailing newline")
    func documentIsPlainText() throws {
        let text = try canonicalText(.standard)
        #expect(text.utf8.allSatisfy { $0 == 0x0A || (0x20...0x7E).contains($0) })
        #expect(text.hasPrefix("{\n  \"budgets\": {\n"))
        #expect(text.hasSuffix("\n}\n"))
        #expect(!text.hasSuffix("\n\n"))
    }

    @Test("Top-level keys are the rules version and the config's groups, in sorted order")
    func topLevelKeysAreTheGroups() throws {
        let expected = [
            "budgets", "charts", "highway", "hype", "judging", "levels", "match", "payload", "playback",
            "rulesVersion", "scoring", "songs", "stars", "unlocks", "xp",
        ]
        #expect(topLevelKeys(of: try canonicalText(.standard)) == expected)
    }

    @Test("Times, percentages, fractions and choices appear as the integers and names the specs' tables imply")
    func valuesAppearAsWritten() throws {
        let text = try canonicalText(.standard)
        #expect(text.contains("\"rulesVersion\": 1"))
        #expect(text.contains("\"windowMicros\": 45000"))
        #expect(text.contains("\"minSameLaneGapMicros\": 180000"))
        #expect(text.contains("\"maxAverageMilliNotesPerSecond\": 3500"))
        #expect(text.contains("\"featuredSongPercent\": 150"))
        #expect(text.contains("\"easy\": \"resetStreak\""))
        #expect(text.contains("\"denominator\": 4"))
        #expect(!text.contains("."))
    }

    @Test("A changed value changes the document and still round-trips")
    func changedConfigRoundTrips() throws {
        var tuned = GameConfig.standard
        tuned.judging.perfect.windowMicros = 40_000
        tuned.judging.ghostTapPenalty.easy = .none
        tuned.stars.sharesPercent.easy = [15, 35, 55, 75, 90]
        tuned.charts.rules.medium.maxChordNoteSharePercent = 0
        tuned.highway.scrollTimeMicros.hard = 1_300_000

        let data = try CanonicalJSON.encode(tuned)
        #expect(data != (try CanonicalJSON.encode(GameConfig.standard)))
        let decoded = try JSONDecoder().decode(GameConfig.self, from: data)
        #expect(decoded == tuned)
        #expect(decoded != GameConfig.standard)
    }

    @Test(
        "Decoding refuses a config with a top-level key missing, rather than filling in a default",
        arguments: ["hype", "judging", "match", "rulesVersion", "xp"]
    )
    func decodingRequiresEveryGroup(missing: String) throws {
        let data = try JSONEncoder().encode(GameConfig.standard)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object.removeValue(forKey: missing) != nil)
        let trimmed = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GameConfig.self, from: trimmed)
        }
    }
}
