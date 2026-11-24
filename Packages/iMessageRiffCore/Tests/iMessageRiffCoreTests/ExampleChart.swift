import iMessageRiffCore

/// A Medium chart that passes every validation rule, built from a fixed pattern so that a test can break one rule
/// at a time. A bar is 4 beats and a slot is an eighth note: 250 ms in the first half, 234 ms in the second.
enum ExampleChart {
    static let ticksPerSlot = 96
    static let slotsPerBar = 8
    static let barCount = 32

    /// Bars with a chord on slot 4.
    static let chordBars = [3, 11, 19]

    /// Bars that are a Hype phrase.
    static let phraseBars = [4, 11, 18, 25]

    static func tick(bar: Int, slot: Int) -> Int {
        (bar * slotsPerBar + slot) * ticksPerSlot
    }

    static func phrase(bar: Int) -> HypePhrase {
        HypePhrase(start: tick(bar: bar, slot: 0), end: tick(bar: bar + 1, slot: 0))
    }

    static func make() -> Chart {
        // The slots that hold a note, by bar modulo 4. Lanes cycle 0 to 3 from note to note.
        let pattern = [[0, 2, 4, 6], [0, 2, 3, 4, 6], [0, 1, 2, 4, 6, 7], [0, 2, 4, 5, 6]]
        var notes: [Note] = []
        var laneCounter = 0
        for bar in 0..<barCount {
            for slot in pattern[bar % 4] {
                let lane = laneCounter % 4
                laneCounter += 1
                // Every fourth bar opens with a hold, of a beat and a half or of two beats.
                var length: Int?
                if bar % 4 == 0 && slot == 0 {
                    length = bar % 8 == 0 ? 288 : 384
                }
                notes.append(Note(tick: tick(bar: bar, slot: slot), lane: lane, length: length))
                if chordBars.contains(bar) && slot == 4 {
                    notes.append(Note(tick: tick(bar: bar, slot: slot), lane: (lane + 2) % 4))
                }
            }
        }
        let halfway = tick(bar: barCount / 2, slot: 0)
        return Chart(
            songId: "riff-example",
            part: .lead,
            difficulty: .medium,
            lanes: 4,
            resolution: 192,
            tempo: [TempoSegment(tick: 0, mbpm: 120_000), TempoSegment(tick: halfway, mbpm: 128_000)],
            timeSignatures: [TimeSignature(tick: 0, numerator: 4, denominator: 4)],
            notes: notes,
            hype: phraseBars.map { phrase(bar: $0) },
            sections: [ChartSection(tick: 0, name: "First half"), ChartSection(tick: halfway, name: "Second half")],
            computed: ChartComputed(
                rulesVersion: 0, noteCount: 0, baseScore: 0, maxScore: 0, starCutoffs: [0, 0, 0, 0, 0], hash: "")
        )
    }

    static func computed() throws -> Chart {
        var chart = make()
        chart.computed = try ChartComputation.computed(for: chart, config: .standard)
        return chart
    }

    /// The rules the example breaks after one change, in the validator's order.
    static func rules(after change: (inout Chart) -> Void) -> [ChartIssue.Rule] {
        var chart = make()
        change(&chart)
        return brokenRules(chart)
    }

    /// A manifest for the example's song.
    static func manifest(id: String = "riff-example", durationMs: Int) -> SongManifest {
        let charts = PerDifficulty(easy: "easy.json", medium: "medium.json", hard: "hard.json", expert: "expert.json")
        return SongManifest(
            id: id,
            title: "Example",
            artist: "Nobody",
            durationMs: durationMs,
            previewStartMs: 0,
            audioOffsetMs: 0,
            stems: SongManifest.Stems(backing: "backing.m4a", lead: "lead.m4a"),
            charts: SongManifest.PerPart(lead: charts),
            intensity: SongManifest.PerPart(lead: PerDifficulty(easy: 1, medium: 3, hard: 5, expert: 7)),
            artwork: "art.png",
            license: "LICENSES/riff-example.md"
        )
    }
}

/// The rules a chart breaks, in the validator's order.
func brokenRules(_ chart: Chart, manifest: SongManifest? = nil) -> [ChartIssue.Rule] {
    ChartValidator.issues(in: chart, manifest: manifest, config: .standard).map(\.rule)
}

extension Chart {
    /// Adds a note, keeping the notes in order of tick, then lane.
    mutating func add(_ note: Note) {
        let index = notes.firstIndex { ($0.tick, $0.lane) > (note.tick, note.lane) } ?? notes.endIndex
        notes.insert(note, at: index)
    }

    /// Adds a tap on an eighth-note slot of the example's grid.
    mutating func addTap(bar: Int, slot: Int, lane: Int) {
        add(Note(tick: ExampleChart.tick(bar: bar, slot: slot), lane: lane))
    }

    /// Where the example's note on a slot is in `notes`.
    func noteIndex(bar: Int, slot: Int, lane: Int) -> Int {
        let tick = ExampleChart.tick(bar: bar, slot: slot)
        guard let index = notes.firstIndex(where: { $0.tick == tick && $0.lane == lane }) else {
            fatalError("the example has no note at bar \(bar), slot \(slot), lane \(lane)")
        }
        return index
    }
}
