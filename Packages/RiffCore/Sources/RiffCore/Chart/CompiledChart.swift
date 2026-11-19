/// One note of a compiled chart, with its times in microseconds of song time.
public struct CompiledNote: Equatable, Sendable {
    public let lane: Int
    public let tick: Int
    public let time: Int64

    /// Where a hold ends; nil for a tap.
    public let endTick: Int?

    /// Song time of `endTick`; nil for a tap.
    public let endTime: Int64?

    /// When the note becomes a Miss if it is still unjudged: `time` plus the difficulty's Good window.
    public let missDeadline: Int64

    /// Index in `CompiledChart.phrases` of the Hype phrase the note belongs to, by its head tick.
    public let phraseIndex: Int?
}

/// One Hype phrase of a compiled chart: the ticks from `startTick` up to, not including, `endTick`.
public struct CompiledPhrase: Equatable, Sendable {
    public let startTick: Int
    public let endTick: Int

    /// Indices in `CompiledChart.notes` of the member notes, ascending.
    public let noteIndices: [Int]
}

/// A chart with every time worked out, built once when a song loads (GAME_RULES section 1.1).
///
/// It expects a chart that has passed validation and does not check the chart rules itself.
public struct CompiledChart: Equatable, Sendable {
    public let difficulty: Difficulty
    public let tempoMap: TempoMap

    /// In the chart's order: by tick, then lane.
    public let notes: [CompiledNote]

    public let phrases: [CompiledPhrase]

    /// Throws `TempoMap.Invalid` when the chart's tempo list cannot make a map.
    public init(chart: Chart, config: GameConfig) throws {
        let tempoMap = try TempoMap(chart: chart)
        let goodWindow = config.judging.windowMicros(of: config.judging.good, on: chart.difficulty)
        var members = [[Int]](repeating: [], count: chart.hype.count)
        var notes: [CompiledNote] = []
        for (index, note) in chart.notes.enumerated() {
            let time = tempoMap.time(ofTick: note.tick)
            let endTick = note.length.map { note.tick + $0 }
            let phraseIndex = chart.hype.firstIndex { $0.start <= note.tick && note.tick < $0.end }
            if let phraseIndex {
                members[phraseIndex].append(index)
            }
            notes.append(
                CompiledNote(
                    lane: note.lane,
                    tick: note.tick,
                    time: time,
                    endTick: endTick,
                    endTime: endTick.map { tempoMap.time(ofTick: $0) },
                    missDeadline: time + goodWindow,
                    phraseIndex: phraseIndex
                )
            )
        }
        self.difficulty = chart.difficulty
        self.tempoMap = tempoMap
        self.notes = notes
        self.phrases = zip(chart.hype, members).map { phrase, indices in
            CompiledPhrase(startTick: phrase.start, endTick: phrase.end, noteIndices: indices)
        }
    }
}
