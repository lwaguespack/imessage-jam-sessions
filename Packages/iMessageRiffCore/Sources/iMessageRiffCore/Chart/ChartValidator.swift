/// Checks a chart against the rules in CHART_FORMAT section 4.
public enum ChartValidator {
    /// Every rule the chart breaks; empty when the chart is valid.
    ///
    /// Structure is checked first, and a chart that fails it gets only those issues: the other rules are stated
    /// in milliseconds, and times cannot be worked out while ticks or tempo are out of range.
    public static func issues(in chart: Chart, manifest: SongManifest? = nil, config: GameConfig) -> [ChartIssue] {
        let structure = structureIssues(in: chart, config: config)
        guard structure.isEmpty else { return structure }
        guard let map = try? TempoMap(chart: chart) else {
            return [ChartIssue(.tempoList, "the tempo list cannot be turned into times")]
        }
        let timeline = ChartTimeline(chart: chart, map: map)
        let rule = config.charts.rules[chart.difficulty]
        var issues = densityIssues(timeline, rule: rule, config: config)
        issues += chordIssues(timeline, rule: rule)
        issues += gapIssues(timeline, rule: rule)
        issues += contactIssues(timeline, rule: rule)
        issues += holdIssues(timeline, rule: rule, config: config)
        issues += phraseIssues(timeline, config: config)
        issues += songLengthIssues(timeline, manifest: manifest, config: config)
        return issues
    }

    /// The last tick any valid chart can reach: the longest song at the fastest tempo and the finest resolution.
    static func lastPossibleTick(_ config: GameConfig) -> Int {
        let longestSong = config.songs.maxDurationMicros + config.songs.durationToleranceMicros
        let fastestRate = Int64(config.charts.maxTempoMilliBPM) * Int64(config.charts.maxTicksPerBeat)
        return Int(longestSong * fastestRate / TempoMap.scale)
    }

    private static func structureIssues(in chart: Chart, config: GameConfig) -> [ChartIssue] {
        let charts = config.charts
        var issues: [ChartIssue] = []
        if chart.format != Chart.formatName || chart.version != charts.schemaVersion {
            issues.append(
                ChartIssue(.format, "the format must be \(Chart.formatName), version \(charts.schemaVersion)"))
        }
        let idLimit = config.payload.maxSongIDBytes
        if !SongID.isValid(chart.songId, maxBytes: idLimit) {
            issues.append(ChartIssue(.songId, "songId must be 1 to \(idLimit) characters from a-z, 0-9 and '-'"))
        }
        if chart.lanes != config.highway.laneCount {
            issues.append(ChartIssue(.lanes, "lanes must be \(config.highway.laneCount)"))
        }
        if chart.resolution < 1 || chart.resolution > charts.maxTicksPerBeat {
            issues.append(ChartIssue(.resolution, "resolution must be 1 to \(charts.maxTicksPerBeat)"))
        }
        issues += tempoIssues(in: chart, config: config)
        issues += noteIssues(in: chart, config: config)
        issues += phraseRangeIssues(in: chart, config: config)
        return issues
    }

    private static func tempoIssues(in chart: Chart, config: GameConfig) -> [ChartIssue] {
        let charts = config.charts
        let lastTick = lastPossibleTick(config)
        var issues: [ChartIssue] = []
        if chart.tempo.first?.tick != 0 {
            issues.append(ChartIssue(.tempoList, tick: chart.tempo.first?.tick, "the tempo list must start at tick 0"))
        }
        for (previous, segment) in zip(chart.tempo, chart.tempo.dropFirst()) where segment.tick <= previous.tick {
            issues.append(ChartIssue(.tempoList, tick: segment.tick, "tempo changes must be in ascending tick order"))
        }
        for segment in chart.tempo where segment.tick > lastTick {
            issues.append(
                ChartIssue(.tempoList, tick: segment.tick, "a tempo change must be at tick \(lastTick) or earlier"))
        }
        for segment in chart.tempo
        where segment.mbpm < charts.minTempoMilliBPM || segment.mbpm > charts.maxTempoMilliBPM {
            let limits = "\(charts.minTempoMilliBPM) to \(charts.maxTempoMilliBPM)"
            issues.append(ChartIssue(.tempoRange, tick: segment.tick, "tempo must be \(limits) thousandths of a BPM"))
        }
        return issues
    }

    private static func noteIssues(in chart: Chart, config: GameConfig) -> [ChartIssue] {
        let lastTick = lastPossibleTick(config)
        let laneCount = config.highway.laneCount
        let chordLimit = config.highway.maxNotesPerChord
        var issues: [ChartIssue] = []
        var notesOnTick = 0
        for (index, note) in chart.notes.enumerated() {
            if note.tick < 0 || note.tick > lastTick {
                issues.append(
                    ChartIssue(.noteTick, tick: note.tick, lane: note.lane, "a tick must be 0 to \(lastTick)"))
            }
            if note.lane < 0 || note.lane >= laneCount {
                issues.append(
                    ChartIssue(.noteLane, tick: note.tick, lane: note.lane, "a lane must be 0 to \(laneCount - 1)"))
            }
            if let length = note.length, length < 1 || length > lastTick {
                let message = "a hold's length must be 1 to \(lastTick) ticks"
                issues.append(ChartIssue(.holdLength, tick: note.tick, lane: note.lane, message))
            }
            guard index > 0 else {
                notesOnTick = 1
                continue
            }
            let previous = chart.notes[index - 1]
            if (previous.tick, previous.lane) >= (note.tick, note.lane) {
                let message = "notes must be in ascending order of tick, then lane, with none repeated"
                issues.append(ChartIssue(.noteOrder, tick: note.tick, lane: note.lane, message))
            }
            notesOnTick = previous.tick == note.tick ? notesOnTick + 1 : 1
            if notesOnTick == chordLimit + 1 {
                issues.append(ChartIssue(.chordSize, tick: note.tick, "at most \(chordLimit) notes may share a tick"))
            }
        }
        return issues
    }

    private static func phraseRangeIssues(in chart: Chart, config: GameConfig) -> [ChartIssue] {
        let lastTick = lastPossibleTick(config)
        var issues: [ChartIssue] = []
        for phrase in chart.hype where phrase.start < 0 || phrase.start >= phrase.end || phrase.end > lastTick {
            let message = "a phrase must start at tick 0 or later, end after it starts, and end by tick \(lastTick)"
            issues.append(ChartIssue(.phraseRange, tick: phrase.start, message))
        }
        for (previous, phrase) in zip(chart.hype, chart.hype.dropFirst()) where phrase.start < previous.end {
            issues.append(ChartIssue(.phraseOrder, tick: phrase.start, "phrases must be in order and must not overlap"))
        }
        return issues
    }
}
