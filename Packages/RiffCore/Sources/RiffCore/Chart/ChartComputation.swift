/// The values `riffcli chart compute` stores in a chart (CHART_FORMAT section 3).
public enum ChartComputation {
    /// The chart's `computed` block with every value this build can work out filled in.
    ///
    /// The scores are carried over as they are until the engine exists to compute them.
    public static func computed(for chart: Chart, config: GameConfig) -> ChartComputed {
        var computed = chart.computed
        computed.rulesVersion = config.rulesVersion
        computed.noteCount = chart.notes.count
        computed.hash = ChartHash.hex(of: chart, config: config)
        return computed
    }

    /// Names of the stored values that a fresh computation would change; empty when the chart is current.
    public static func staleFields(in chart: Chart, config: GameConfig) -> [String] {
        let fresh = computed(for: chart, config: config)
        var names: [String] = []
        if chart.computed.rulesVersion != fresh.rulesVersion {
            names.append("rulesVersion")
        }
        if chart.computed.noteCount != fresh.noteCount {
            names.append("noteCount")
        }
        if chart.computed.hash != fresh.hash {
            names.append("hash")
        }
        return names
    }
}
