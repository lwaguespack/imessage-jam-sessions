import Foundation
import RiffCore
import Testing

@Suite("Model enums")
struct ModelEnumTests {
    @Test("Difficulty raw values are the chart file's strings, easiest first")
    func difficultyRawValues() {
        #expect(Difficulty.allCases.map(\.rawValue) == ["easy", "medium", "hard", "expert"])
    }

    @Test("Part raw values are the chart file's strings")
    func partRawValues() {
        #expect(Part.allCases.map(\.rawValue) == ["lead"])
    }

    @Test("Judgement raw values run from best to worst")
    func judgementRawValues() {
        #expect(Judgement.allCases.map(\.rawValue) == ["perfect", "great", "good", "miss"])
    }

    @Test("Ghost-tap penalty raw values match the config JSON")
    func ghostTapPenaltyRawValues() {
        #expect(GameConfig.GhostTapPenalty.allCases.map(\.rawValue) == ["none", "dropTier", "resetStreak"])
    }

    @Test("Enums encode as their raw strings and reject anything else")
    func enumsCodeAsStrings() throws {
        // The same field names and values as a chart file's header (plan appendix A).
        struct ChartHeader: Codable, Equatable {
            var part: Part
            var difficulty: Difficulty
        }

        let json = Data(#"{"part":"lead","difficulty":"expert"}"#.utf8)
        let header = try JSONDecoder().decode(ChartHeader.self, from: json)
        #expect(header == ChartHeader(part: .lead, difficulty: .expert))
        #expect(try JSONDecoder().decode(ChartHeader.self, from: JSONEncoder().encode(header)) == header)

        let unknown = Data(#"{"part":"lead","difficulty":"Expert"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ChartHeader.self, from: unknown)
        }
    }

    @Test("PerDifficulty looks up the value stored for each difficulty")
    func perDifficultyLookup() {
        let values = PerDifficulty(easy: "e", medium: "m", hard: "h", expert: "x")
        #expect(Difficulty.allCases.map { values[$0] } == ["e", "m", "h", "x"])
    }

    @Test("PerDifficulty encodes as an object keyed by the difficulty raw values")
    func perDifficultyKeys() throws {
        let values = PerDifficulty(easy: 1, medium: 2, hard: 3, expert: 4)
        let decoded = try JSONDecoder().decode([String: Int].self, from: JSONEncoder().encode(values))
        let expected = Dictionary(uniqueKeysWithValues: Difficulty.allCases.map { ($0.rawValue, values[$0]) })
        #expect(decoded == expected)
    }

    @Test("PerDifficulty refuses JSON that leaves a difficulty out")
    func perDifficultyRequiresEveryKey() {
        let missingExpert = Data(#"{"easy":1,"medium":2,"hard":3}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PerDifficulty<Int>.self, from: missingExpert)
        }
    }
}
