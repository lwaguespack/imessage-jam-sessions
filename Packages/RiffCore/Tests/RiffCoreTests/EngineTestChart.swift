import RiffCore

enum EngineTestChart {
    static func make(
        notes: [Note],
        hype: [HypePhrase] = [],
        resolution: Int = 192,
        difficulty: Difficulty = .expert,
        config: GameConfig = .standard
    ) throws -> CompiledChart {
        var chart = ExampleChart.make()
        chart.notes = notes
        chart.hype = hype
        chart.resolution = resolution
        chart.difficulty = difficulty
        chart.tempo = [TempoSegment(tick: 0, mbpm: 120_000)]
        return try CompiledChart(chart: chart, config: config)
    }
}
