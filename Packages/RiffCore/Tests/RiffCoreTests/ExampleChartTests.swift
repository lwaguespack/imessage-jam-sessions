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
        let expected = try CanonicalJSON.encode(ExampleChart.make())
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
        #expect(chart == ExampleChart.make())
        #expect(ChartValidator.issues(in: chart, config: .standard).isEmpty)
        #expect(ChartComputation.staleFields(in: chart, config: .standard).isEmpty)
    }

    @Test("Computed values are the rules version, the note count and the hash; the scores are carried over")
    func computedValues() {
        var chart = ExampleChart.make()
        chart.computed = ChartComputed(
            rulesVersion: 0, noteCount: 0, baseScore: 11, maxScore: 22, starCutoffs: [1, 2, 3, 4, 5], hash: "")
        #expect(ChartComputation.staleFields(in: chart, config: .standard) == ["rulesVersion", "noteCount", "hash"])

        let computed = ChartComputation.computed(for: chart, config: .standard)
        #expect(computed.rulesVersion == GameConfig.standard.rulesVersion)
        #expect(computed.noteCount == 163)
        #expect(computed.hash == ChartHash.hex(of: chart, config: .standard))
        #expect(computed.hash.count == 8)
        #expect(computed.baseScore == 11)
        #expect(computed.maxScore == 22)
        #expect(computed.starCutoffs == [1, 2, 3, 4, 5])

        chart.computed = computed
        #expect(ChartComputation.staleFields(in: chart, config: .standard).isEmpty)
        chart.notes.removeLast()
        #expect(ChartComputation.staleFields(in: chart, config: .standard) == ["noteCount", "hash"])
    }
}
