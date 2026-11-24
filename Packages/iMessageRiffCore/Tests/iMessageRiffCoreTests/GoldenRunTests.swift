import Foundation
import Testing
import iMessageRiffCore

@Suite("Golden scoring runs")
struct GoldenRunTests {
    private struct Fixture: Decodable {
        let name: String
        let log: RunLog
        let expected: RunSummary
    }

    @Test("Recorded inputs reproduce independently calculated summaries")
    func goldenRuns() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/golden-runs.json")
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        let chart = try EngineTestChart.make(notes: [Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)])
        for fixture in fixtures {
            let game = try GameSession.replay(
                fixture.log, chart: chart, config: .standard, chartHash: "deadbeef")
            #expect(try RunSummary(session: game, baseScore: 200) == fixture.expected, "\(fixture.name)")
        }
    }
}
