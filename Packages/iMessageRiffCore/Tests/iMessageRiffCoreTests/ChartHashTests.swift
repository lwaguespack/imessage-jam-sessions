import Testing
import iMessageRiffCore

@Suite("Chart hash")
struct ChartHashTests {
    /// The example in CHART_FORMAT.md section 1, under another song id.
    private func chart() -> Chart {
        Chart(
            songId: "test-song",
            part: .lead,
            difficulty: .expert,
            lanes: 4,
            resolution: 192,
            tempo: [TempoSegment(tick: 0, mbpm: 128_000)],
            timeSignatures: [TimeSignature(tick: 0, numerator: 4, denominator: 4)],
            notes: [
                Note(tick: 768, lane: 0), Note(tick: 960, lane: 2, length: 192), Note(tick: 1152, lane: 1),
                Note(tick: 1152, lane: 3),
            ],
            hype: [HypePhrase(start: 3072, end: 4608)],
            sections: [ChartSection(tick: 0, name: "Intro")],
            computed: ChartComputed(
                rulesVersion: 1, noteCount: 412, baseScore: 0, maxScore: 0, starCutoffs: [0, 0, 0, 0, 0],
                hash: "00000000")
        )
    }

    private func config(rulesVersion: Int) -> GameConfig {
        var config = GameConfig.standard
        config.rulesVersion = rulesVersion
        return config
    }

    @Test("The canonical text is six lines with no newline after the last")
    func canonicalText() {
        let expected = """
            riff-chart-v1
            rules=7
            song=test-song;part=lead;difficulty=expert;lanes=4;resolution=192
            tempo=0:128000
            notes=768:0:0,960:2:192,1152:1:0,1152:3:0
            hype=3072:4608
            """
        #expect(ChartHash.canonicalText(of: chart(), rulesVersion: 7) == expected)
    }

    // Expected values are from Python's hashlib over the same text.
    @Test("The hash is the first 4 bytes of the SHA-256 of the canonical text")
    func knownHashes() {
        #expect(ChartHash.hex(of: chart(), config: config(rulesVersion: 7)) == "d11de56f")
        #expect(ChartHash.bytes(of: chart(), config: config(rulesVersion: 7)) == [0xd1, 0x1d, 0xe5, 0x6f])

        var other = chart()
        other.tempo.append(TempoSegment(tick: 768, mbpm: 140_000))
        other.hype = []
        let expected = """
            riff-chart-v1
            rules=7
            song=test-song;part=lead;difficulty=expert;lanes=4;resolution=192
            tempo=0:128000,768:140000
            notes=768:0:0,960:2:192,1152:1:0,1152:3:0
            hype=
            """
        #expect(ChartHash.canonicalText(of: other, rulesVersion: 7) == expected)
        #expect(ChartHash.hex(of: other, config: config(rulesVersion: 7)) == "7231d83e")
    }

    @Test("Display-only fields and the stored computed values do not change the hash")
    func ignoresDisplayFields() {
        let standard = ChartHash.hex(of: chart(), config: .standard)
        var edited = chart()
        edited.sections = [ChartSection(tick: 0, name: "Opening"), ChartSection(tick: 768, name: "Verse")]
        edited.timeSignatures = [TimeSignature(tick: 0, numerator: 3, denominator: 4)]
        edited.computed = ChartComputed(
            rulesVersion: 9, noteCount: 1, baseScore: 2, maxScore: 3, starCutoffs: [4], hash: "ffffffff")
        #expect(ChartHash.hex(of: edited, config: .standard) == standard)
    }

    @Test("A change to the notes, the tempo, the phrases, the header or the rules version changes the hash")
    func coversEverythingElse() {
        let edits: [(inout Chart) -> Void] = [
            { $0.notes[0].tick += 1 },
            { $0.notes[0].lane = 1 },
            { $0.notes[0].length = 96 },
            { $0.notes[1].length = 191 },
            { $0.notes.removeLast() },
            { $0.tempo[0].mbpm += 1 },
            { $0.tempo.append(TempoSegment(tick: 768, mbpm: 128_000)) },
            { $0.hype[0].end += 1 },
            { $0.hype = [] },
            { $0.songId = "test-sonh" },
            { $0.difficulty = .hard },
            { $0.resolution = 96 },
            { $0.lanes = 5 },
            { $0.version = 2 },
        ]
        let standard = ChartHash.hex(of: chart(), config: .standard)
        for (index, edit) in edits.enumerated() {
            var edited = chart()
            edit(&edited)
            #expect(ChartHash.hex(of: edited, config: .standard) != standard, "edit \(index)")
        }
        let nextRules = config(rulesVersion: GameConfig.standard.rulesVersion + 1)
        #expect(ChartHash.hex(of: chart(), config: nextRules) != standard)
    }
}
