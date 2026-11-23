import RiffCore
import Testing

@Suite("Game session replay properties")
struct GameSessionPropertyTests {
    @Test("SplitMix64 matches its published initial sequence")
    func generatorSequence() {
        var random = SplitMix64(seed: 0)
        #expect(random.next() == 0xE220_A839_7B1D_CDAF)
        #expect(random.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(random.next() == 0x06C4_5D18_8009_454F)
    }

    @Test("Complete watermarks produce identical output across 100 random partitions")
    func partitionInvariance() throws {
        let chart = try EngineTestChart.make(
            notes: [
                Note(tick: 192, lane: 0, length: 384), Note(tick: 192, lane: 1),
                Note(tick: 384, lane: 2), Note(tick: 600, lane: 3), Note(tick: 768, lane: 0),
            ],
            hype: [HypePhrase(start: 192, end: 601)])
        let inputs: [InputEvent] = [
            .touchDown(id: 2, lane: 1, time: 500_000),
            .touchDown(id: 1, lane: 0, time: 500_000),
            .touchUp(id: 2, time: 520_000),
            .touchDown(id: 3, lane: 2, time: 1_020_000),
            .touchUp(id: 3, time: 1_040_000),
            .touchUp(id: 1, time: 1_300_000),
            .touchDown(id: 4, lane: 3, time: 1_400_000),
            .touchUp(id: 4, time: 1_410_000),
            .touchDown(id: 5, lane: 3, time: 1_562_500),
            .touchUp(id: 5, time: 1_570_000),
        ]
        var baseline = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
        try baseline.start()
        for input in inputs { try baseline.apply(input) }
        try baseline.advance(to: 3_000_000)
        let expected = baseline.drainOutput()
        let expectedScore = try baseline.scoring.totalScore()

        for seed in UInt64(0)..<100 {
            var random = SplitMix64(seed: seed)
            var game = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
            try game.start()
            var cursor = 0
            var time = game.watermark
            while game.state != .finished && time < 3_000_000 {
                time = min(3_000_000, time + Int64(random.next() % 200_000) + 1)
                while cursor < inputs.count && inputs[cursor].time <= time {
                    try game.apply(inputs[cursor])
                    cursor += 1
                }
                try game.advance(to: time)
            }
            #expect(game.state == .finished, "seed \(seed)")
            #expect(try game.scoring.totalScore() == expectedScore, "seed \(seed)")
            #expect(game.drainOutput() == expected, "seed \(seed)")
        }
    }
}
