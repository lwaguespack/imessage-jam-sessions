/// The hash that tells two charts apart in a match (CHART_FORMAT section 2).
///
/// It expects a chart that has passed validation, and writes the chart's lists in file order.
public enum ChartHash {
    /// The text the hash is taken over: six lines joined by newlines, with none after the last.
    public static func canonicalText(of chart: Chart, rulesVersion: Int) -> String {
        let header = [
            "song=\(chart.songId)", "part=\(chart.part.rawValue)", "difficulty=\(chart.difficulty.rawValue)",
            "lanes=\(chart.lanes)", "resolution=\(chart.resolution)",
        ]
        let tempo = chart.tempo.map { "\($0.tick):\($0.mbpm)" }
        let notes = chart.notes.map { "\($0.tick):\($0.lane):\($0.length ?? 0)" }
        let hype = chart.hype.map { "\($0.start):\($0.end)" }
        return [
            "riff-chart-v\(chart.version)",
            "rules=\(rulesVersion)",
            header.joined(separator: ";"),
            "tempo=" + tempo.joined(separator: ","),
            "notes=" + notes.joined(separator: ","),
            "hype=" + hype.joined(separator: ","),
        ].joined(separator: "\n")
    }

    /// The leading bytes of the SHA-256 of the canonical text, as many as the match payload carries.
    public static func bytes(of chart: Chart, config: GameConfig) -> [UInt8] {
        let text = canonicalText(of: chart, rulesVersion: config.rulesVersion)
        return Array(SHA256.hash(Array(text.utf8)).prefix(config.payload.chartHashBytes))
    }

    /// The hash as lowercase hex, the form a chart file stores.
    public static func hex(of chart: Chart, config: GameConfig) -> String {
        Hex.encode(bytes(of: chart, config: config))
    }
}
