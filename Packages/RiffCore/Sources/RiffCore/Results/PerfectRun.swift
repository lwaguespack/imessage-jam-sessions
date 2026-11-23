/// Computes a chart's perfect no-Hype base score and a conservative score ceiling.
public enum PerfectRun {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidChart
        case incompleteRun
        case overflow
    }

    public struct Values: Equatable, Sendable {
        public let baseScore: Int64
        public let maxScore: Int64
        public let starCutoffs: [Int64]
    }

    public static func compute(chart: CompiledChart, config: GameConfig, chartHash: String) throws -> Values {
        guard !chart.notes.isEmpty else { throw Error.invalidChart }
        var game = try GameSession(chart: chart, config: config, chartHash: chartHash)
        try game.start()
        var lastTime: Int64 = 0
        var holdTicks: Int64 = 0
        for (index, note) in chart.notes.enumerated() {
            try game.apply(.touchDown(id: index, lane: note.lane, time: note.time))
            if let endTick = note.endTick, let endTime = note.endTime {
                let (length, overflow) = endTick.subtractingReportingOverflow(note.tick)
                guard !overflow, length > 0 else { throw Error.invalidChart }
                holdTicks = try add(holdTicks, Int64(length))
                try game.apply(.touchUp(id: index, time: endTime))
                lastTime = max(lastTime, endTime)
            } else {
                let (release, overflow) = note.time.addingReportingOverflow(1)
                guard !overflow else { throw Error.overflow }
                try game.apply(.touchUp(id: index, time: release))
                lastTime = max(lastTime, note.time)
            }
        }
        try game.advance(to: lastTime)
        guard game.state == .finished, game.scoring.missCount == 0 else { throw Error.incompleteRun }
        let base = try game.scoring.totalScore()
        let multiplier = try multiply(Int64(config.scoring.maxStreakMultiplier), Int64(config.hype.multiplier))
        let noteMaximum = try multiply(
            try multiply(Int64(config.judging.perfect.points), multiplier), Int64(chart.notes.count))
        let sustainUnits = try multiply(holdTicks, multiplier)
        let sustainNumerator = try multiply(Int64(config.scoring.sustainPointsPerBeat), sustainUnits)
        let maximum = try add(noteMaximum, sustainNumerator / Int64(chart.tempoMap.resolution))
        let cutoffs = try StarRating.cutoffs(baseScore: base, shares: config.stars.sharesPercent[chart.difficulty])
        return Values(baseScore: base, maxScore: maximum, starCutoffs: cutoffs)
    }

    private static func add(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw Error.overflow }
        return result
    }

    private static func multiply(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.multipliedReportingOverflow(by: right)
        guard !overflow else { throw Error.overflow }
        return result
    }
}
