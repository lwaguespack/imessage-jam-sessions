import Foundation
import RiffCore
import Testing

@Suite("Example chart file")
struct ExampleChartTests {
    /// `Fixtures/example-medium.json`, beside this file.
    private static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("example-medium.json")

    // Run this test alone with RIFF_WRITE_FIXTURES=1 to rewrite the file, for example after a rules version bump.
    @Test("The committed file is the example chart with its computed values, as canonical JSON")
    func fileMatchesTheBuilder() throws {
        let expected = try CanonicalJSON.encode(ExampleChart.computed())
        if ProcessInfo.processInfo.environment["RIFF_WRITE_FIXTURES"] == "1" {
            let folder = Self.fixture.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try expected.write(to: Self.fixture)
        }
        #expect(try Data(contentsOf: Self.fixture) == expected)
    }

    @Test("The committed file reads back as a valid chart whose stored values are current")
    func fileIsValidAndCurrent() throws {
        let chart = try ChartDecoder.decode(Data(contentsOf: Self.fixture))
        #expect(try chart == ExampleChart.computed())
        #expect(ChartValidator.issues(in: chart, config: .standard).isEmpty)
        #expect(try ChartComputation.staleFields(in: chart, config: .standard).isEmpty)
        #expect(chart.computed.baseScore == 62_887)
        #expect(chart.computed.maxScore == 133_200)
        #expect(chart.computed.starCutoffs == [6_289, 15_722, 28_300, 40_877, 53_454])
    }

    @Test("Computed values include scores and detect every stale field")
    func computedValues() throws {
        var chart = try ExampleChart.computed()
        let expected = chart.computed
        chart.computed = ChartComputed(
            rulesVersion: 0, noteCount: 0, baseScore: 11, maxScore: 22, starCutoffs: [1, 2, 3, 4, 5], hash: "")
        #expect(
            try ChartComputation.staleFields(in: chart, config: .standard)
                == ["rulesVersion", "noteCount", "baseScore", "maxScore", "starCutoffs", "hash"])

        let computed = try ChartComputation.computed(for: chart, config: .standard)
        #expect(computed.rulesVersion == GameConfig.standard.rulesVersion)
        #expect(computed.noteCount == 163)
        #expect(computed.hash == ChartHash.hex(of: chart, config: .standard))
        #expect(computed.hash.count == 8)
        #expect(computed == expected)
        #expect(computed.baseScore > 0)
        #expect(computed.maxScore >= computed.baseScore)
        #expect(computed.starCutoffs.count == 5)

        chart.computed = computed
        #expect(try ChartComputation.staleFields(in: chart, config: .standard).isEmpty)
        chart.notes.removeLast()
        #expect(
            try ChartComputation.staleFields(in: chart, config: .standard)
                == ["noteCount", "baseScore", "maxScore", "starCutoffs", "hash"])
    }
}
