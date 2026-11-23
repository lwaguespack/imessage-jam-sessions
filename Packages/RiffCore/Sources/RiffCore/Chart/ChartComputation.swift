/// The values `riffcli chart compute` stores in a chart (CHART_FORMAT section 3).
public enum ChartComputation {
    public enum Error: Swift.Error, Equatable, Sendable {
        case scoreOutOfRange
    }

    /// Computes every stored field from the chart and the current engine rules.
    public static func computed(for chart: Chart, config: GameConfig) throws -> ChartComputed {
        let hash = ChartHash.hex(of: chart, config: config)
        let compiled = try CompiledChart(chart: chart, config: config)
        let values = try PerfectRun.compute(chart: compiled, config: config, chartHash: hash)
        guard let base = Int(exactly: values.baseScore), let maximum = Int(exactly: values.maxScore) else {
            throw Error.scoreOutOfRange
        }
        var cutoffs: [Int] = []
        for value in values.starCutoffs {
            guard let cutoff = Int(exactly: value) else { throw Error.scoreOutOfRange }
            cutoffs.append(cutoff)
        }
        return ChartComputed(
            rulesVersion: config.rulesVersion, noteCount: chart.notes.count, baseScore: base,
            maxScore: maximum, starCutoffs: cutoffs, hash: hash)
    }

    /// Names of the stored values that a fresh computation would change; empty when the chart is current.
    public static func staleFields(in chart: Chart, config: GameConfig) throws -> [String] {
        let fresh = try computed(for: chart, config: config)
        var names: [String] = []
        if chart.computed.rulesVersion != fresh.rulesVersion {
            names.append("rulesVersion")
        }
        if chart.computed.noteCount != fresh.noteCount {
            names.append("noteCount")
        }
        if chart.computed.baseScore != fresh.baseScore {
            names.append("baseScore")
        }
        if chart.computed.maxScore != fresh.maxScore {
            names.append("maxScore")
        }
        if chart.computed.starCutoffs != fresh.starCutoffs {
            names.append("starCutoffs")
        }
        if chart.computed.hash != fresh.hash {
            names.append("hash")
        }
        return names
    }
}
