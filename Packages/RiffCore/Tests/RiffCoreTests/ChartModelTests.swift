import Foundation
import RiffCore
import Testing

@Suite("Chart model")
struct ChartModelTests {
    /// The example in CHART_FORMAT.md section 1.
    private static let exampleJSON = """
        {
          "format": "riff-chart",
          "version": 1,
          "songId": "neon-nights",
          "part": "lead",
          "difficulty": "expert",
          "lanes": 4,
          "resolution": 192,
          "tempo": [{ "tick": 0, "mbpm": 128000 }],
          "timeSignatures": [{ "tick": 0, "num": 4, "den": 4 }],
          "notes": [
            { "tick": 768, "lane": 0 },
            { "tick": 960, "lane": 2, "length": 192 },
            { "tick": 1152, "lane": 1 },
            { "tick": 1152, "lane": 3 }
          ],
          "hype": [{ "start": 3072, "end": 4608 }],
          "sections": [{ "tick": 0, "name": "Intro" }],
          "computed": {
            "rulesVersion": 1,
            "noteCount": 412,
            "baseScore": 0,
            "maxScore": 0,
            "starCutoffs": [0, 0, 0, 0, 0],
            "hash": "00000000"
          }
        }
        """

    private func example() throws -> Chart {
        try JSONDecoder().decode(Chart.self, from: Data(Self.exampleJSON.utf8))
    }

    private func canonicalText<Value: Encodable>(_ value: Value) throws -> String {
        String(decoding: try CanonicalJSON.encode(value), as: UTF8.self)
    }

    @Test("The example chart in the format spec decodes field for field")
    func decodesTheSpecExample() throws {
        let chart = try example()
        #expect(chart.format == Chart.formatName)
        #expect(chart.version == RiffCoreInfo.chartSchemaVersion)
        #expect(chart.songId == "neon-nights")
        #expect(chart.part == .lead)
        #expect(chart.difficulty == .expert)
        #expect(chart.lanes == 4)
        #expect(chart.resolution == 192)
        #expect(chart.tempo == [TempoSegment(tick: 0, mbpm: 128_000)])
        #expect(chart.timeSignatures == [TimeSignature(tick: 0, numerator: 4, denominator: 4)])
        let notes = [
            Note(tick: 768, lane: 0), Note(tick: 960, lane: 2, length: 192), Note(tick: 1152, lane: 1),
            Note(tick: 1152, lane: 3),
        ]
        #expect(chart.notes == notes)
        #expect(chart.hype == [HypePhrase(start: 3072, end: 4608)])
        #expect(chart.sections == [ChartSection(tick: 0, name: "Intro")])
        let computed = ChartComputed(
            rulesVersion: 1, noteCount: 412, baseScore: 0, maxScore: 0, starCutoffs: [0, 0, 0, 0, 0],
            hash: "00000000")
        #expect(chart.computed == computed)
    }

    @Test("A chart survives a round trip through JSON")
    func roundTrips() throws {
        let chart = try example()
        let data = try CanonicalJSON.encode(chart)
        #expect(try JSONDecoder().decode(Chart.self, from: data) == chart)
    }

    @Test("A tap is written without a length, a hold with one, and a time signature with the file's short keys")
    func keysMatchTheFile() throws {
        #expect(try canonicalText(Note(tick: 768, lane: 0)) == "{\n  \"lane\": 0,\n  \"tick\": 768\n}\n")
        #expect(
            try canonicalText(Note(tick: 960, lane: 2, length: 192))
                == "{\n  \"lane\": 2,\n  \"length\": 192,\n  \"tick\": 960\n}\n"
        )
        #expect(
            try canonicalText(TimeSignature(tick: 0, numerator: 4, denominator: 4))
                == "{\n  \"den\": 4,\n  \"num\": 4,\n  \"tick\": 0\n}\n"
        )
    }

    @Test(
        "A chart file with a required part missing is refused, rather than filled in",
        arguments: ["computed", "tempo", "hype", "sections", "timeSignatures"]
    )
    func decodingRequiresEveryKey(missing: String) throws {
        let data = Data(Self.exampleJSON.utf8)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object.removeValue(forKey: missing) != nil)
        let trimmed = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Chart.self, from: trimmed)
        }
    }
}
