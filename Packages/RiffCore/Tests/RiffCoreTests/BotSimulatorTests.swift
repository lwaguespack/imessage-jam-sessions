import RiffCore
import Testing

@Suite("Seeded bots")
struct BotSimulatorTests {
    @Test("The perfect bot equals the stored example-chart base score")
    func perfect() throws {
        let chart = try ExampleChart.computed()
        let simulator = try BotSimulator(chart: chart, config: .standard)
        let result = try simulator.run(.perfect, seed: 1)
        #expect(result.score == chart.computed.baseScore)
        #expect(result.fullCombo)
        #expect(result.stars == 6)
    }

    @Test("Skill bots are reproducible for a seed")
    func deterministic() throws {
        let simulator = try BotSimulator(chart: ExampleChart.computed(), config: .standard)
        for kind in [BotKind.skilled, .good, .casual, .beginner, .clustered] {
            #expect(try simulator.run(kind, seed: 42) == simulator.run(kind, seed: 42))
        }
    }

    @Test("The example-chart mashers cannot Full Combo and remain below the casual median")
    func masherAcceptance() throws {
        let config = GameConfig.standard
        let chart = try ExampleChart.computed()
        let compiled = try CompiledChart(chart: chart, config: config)
        let first = try #require(compiled.notes.first)
        let last = try #require(compiled.notes.last)
        let goodWindow = first.missDeadline - first.time
        let interval: Int64 = 500_000
        #expect(last.time - first.time >= interval)
        let possibleNotes =
            compiled.notes.indices.map { index in
                compiled.notes[index...].prefix { $0.time - compiled.notes[index].time <= interval + 2 * goodWindow }
                    .count
            }.max() ?? 0
        let simulator = try BotSimulator(chart: chart, config: config)
        let casual = try (0..<32).map { try simulator.run(.casual, seed: UInt64($0)).score }.sorted()
        let median = casual[(casual.count - 1) / 2]
        let step = config.scoring.streakPerMultiplierStep[chart.difficulty]
        let multiplier = min(config.scoring.maxStreakMultiplier, 1 + possibleNotes / step)
        let holdTicks = compiled.notes.reduce(0) { $0 + (($1.endTick ?? $1.tick) - $1.tick) }
        let noteBound = chart.notes.count * config.judging.perfect.points * multiplier
        let holdBound = holdTicks * config.scoring.sustainPointsPerBeat * multiplier / chart.resolution
        #expect(Int64(noteBound + holdBound) < median)
        for period in config.simulation.masherPeriodsMicros {
            // Every interval this long before the last hit contains a streak-resetting ghost.
            let minimumPresses = Int64(config.highway.laneCount) * (interval / period)
            #expect(period > config.judging.bounceGraceMicros)
            #expect(config.judging.ghostTapPenalty[chart.difficulty] == .resetStreak)
            #expect(minimumPresses > Int64(possibleNotes))
            for seed in UInt64(0)..<32 {
                let result = try simulator.run(.masher(periodMicros: period), seed: seed)
                #expect(!result.fullCombo, "period \(period), seed \(seed)")
                #expect(result.score < median, "period \(period), seed \(seed)")
            }
        }
    }

    @Test("Invalid simulator parameters and excessive inputs fail explicitly")
    func invalidConfiguration() throws {
        let chart = try ExampleChart.computed()
        var config = GameConfig.standard
        config.simulation.casual.missChanceBasisPoints = 10_001
        #expect(throws: BotSimulator.Error.invalidConfiguration) {
            try BotSimulator(chart: chart, config: config)
        }

        config = .standard
        config.simulation.maxInputEvents = 2
        let simulator = try BotSimulator(chart: chart, config: config)
        #expect(throws: BotSimulator.Error.tooManyInputs) {
            try simulator.run(.perfect, seed: 1)
        }
        #expect(throws: BotSimulator.Error.invalidConfiguration) {
            try simulator.run(.masher(periodMicros: config.simulation.tapDurationMicros), seed: 1)
        }
    }
}
