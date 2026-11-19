import RiffCore
import Testing

/// Each case changes the example chart in one way and names every rule the result breaks.
///
/// The example is Medium: 2 to 3.5 notes a second, at most 5 in a second, chords at most 5% of notes and a beat
/// apart, 250 ms between notes in a lane and 150 ms between ticks, two fingers at once, holds of half a beat and
/// 250 ms. Its second half is at 128 BPM, where an eighth note lasts 234 ms.
@Suite("Chart validator: content")
struct ChartValidatorContentTests {
    private typealias Case = (name: String, rules: [ChartIssue.Rule], change: (inout Chart) -> Void)

    private func check(_ cases: [Case]) {
        for testCase in cases {
            #expect(ExampleChart.rules(after: testCase.change) == testCase.rules, "\(testCase.name)")
        }
    }

    @Test("Average density is the note count over the time from the first note to the last")
    func averageDensity() {
        check([("the chart read as Hard, which needs 3.5 notes a second", [.averageDensity], { $0.difficulty = .hard })]
        )

        // Notes spread evenly over 4 beats at 120 BPM: 2 seconds from the first to the last.
        func accepts(noteCount: Int) -> Bool {
            var chart = ExampleChart.make()
            chart.notes = (0..<noteCount).map { Note(tick: $0 * 768 / (noteCount - 1), lane: $0 % 4) }
            return !brokenRules(chart).contains(.averageDensity)
        }
        #expect(!accepts(noteCount: 3))
        #expect(accepts(noteCount: 4), "exactly 2 notes a second")
        #expect(accepts(noteCount: 7), "exactly 3.5 notes a second")
        #expect(!accepts(noteCount: 8))
    }

    @Test("A chart needs notes on two ticks before density means anything")
    func noteSpan() {
        #expect(ExampleChart.rules { $0.notes = [$0.notes[0]] }.first == .noteSpan)
        #expect(ExampleChart.rules { $0.notes = [] }.first == .noteSpan)
    }

    @Test("Peak density counts the notes in a second that starts at a note and stops short of its end")
    func peakDensity() {
        check([
            ("a sixth note inside one second", [.peakDensity], { $0.addTap(bar: 19, slot: 3, lane: 2) }),
            ("five notes in a second and a sixth exactly 1,000 ms on", [], { $0.addTap(bar: 3, slot: 7, lane: 1) }),
        ])
        var chart = ExampleChart.make()
        chart.addTap(bar: 19, slot: 3, lane: 2)
        let issue = ChartValidator.issues(in: chart, config: .standard).first
        #expect(issue?.tick == ExampleChart.tick(bar: 19, slot: 2))
    }

    @Test("Chords are limited as a share of all notes, and on Medium are a beat apart")
    func chords() {
        check([
            ("one more chord: 8 of 164 notes", [], { $0.addTap(bar: 7, slot: 4, lane: 3) }),
            (
                "two more chords: 10 of 165 notes", [.chordShare],
                {
                    $0.addTap(bar: 7, slot: 4, lane: 3)
                    $0.addTap(bar: 15, slot: 4, lane: 3)
                }
            ),
            ("chords half a beat apart", [.chordSpacing], { $0.addTap(bar: 3, slot: 5, lane: 0) }),
            ("chords exactly a beat apart", [], { $0.addTap(bar: 3, slot: 6, lane: 1) }),
            (
                "chords half a beat apart on Hard, which sets no spacing", [.averageDensity],
                {
                    $0.difficulty = .hard
                    $0.addTap(bar: 3, slot: 5, lane: 0)
                }
            ),
        ])
        #expect(ExampleChart.rules { $0.difficulty = .easy }.contains(.chordShare), "Easy allows no chords")
    }

    @Test("The same-lane gap runs from the end of one note to the start of the next")
    func sameLaneGap() {
        check([
            ("a note inside a hold in its lane", [.noteDuringHold], { $0.add(Note(tick: 96, lane: 0)) }),
            (
                "two taps in a lane 234 ms apart", [.sameLaneGap],
                { $0.notes[$0.noteIndex(bar: 17, slot: 3, lane: 2)].lane = 1 }
            ),
            ("a tap 234 ms after a hold in its lane ends", [.sameLaneGap], { $0.addTap(bar: 16, slot: 4, lane: 0) }),
            ("a tap exactly 250 ms after a hold in its lane ends", [], { $0.addTap(bar: 0, slot: 4, lane: 0) }),
            ("a tap 469 ms after a hold in its lane ends", [], { $0.addTap(bar: 16, slot: 5, lane: 0) }),
        ])
        var chart = ExampleChart.make()
        chart.add(Note(tick: 96, lane: 0))
        let issue = ChartValidator.issues(in: chart, config: .standard).first
        #expect(issue?.tick == 96)
        #expect(issue?.lane == 0)
    }

    @Test("The cross-lane gap is between notes on neighbouring ticks")
    func crossLaneGap() {
        check([("a note 125 ms after the tick before", [.crossLaneGap], { $0.add(Note(tick: 48, lane: 2)) })])
    }

    @Test("Contacts are the notes starting on a tick plus the holds running through it")
    func contacts() {
        check([
            ("a chord during a hold", [.contacts], { $0.add(Note(tick: 192, lane: 3)) }),
            ("a chord on the tick where a hold ends", [], { $0.addTap(bar: 4, slot: 4, lane: 3) }),
        ])
    }

    @Test("A hold must be long enough in beats and in milliseconds")
    func holds() {
        check([
            ("a hold one tick short of half a beat", [.holdTooShort], { $0.notes[0].length = 95 }),
            (
                "a half-beat hold that lasts 234 ms", [.holdTooShort],
                { $0.notes[$0.noteIndex(bar: 16, slot: 0, lane: 0)].length = 96 }
            ),
            ("a half-beat hold that lasts exactly 250 ms", [], { $0.notes[0].length = 96 }),
        ])
    }

    @Test("Phrases are limited in number, size, place and total capacity")
    func phrases() {
        check([
            ("three phrases", [.phraseCount], { $0.hype.removeLast() }),
            (
                "seven phrases", [.phraseCount, .hypeCapacity],
                {
                    let bars = [1, 4, 8, 11, 15, 18, 25]
                    $0.hype = bars.map { ExampleChart.phrase(bar: $0) }
                }
            ),
            ("a phrase whose fourth note is on its end tick", [.phraseMembers], { $0.hype[0].end = 3648 }),
            ("a phrase whose fourth note is on its last tick", [], { $0.hype[0].end = 3649 }),
            (
                "a last phrase 11 beats before the final note", [.phraseTail],
                { $0.hype[3] = ExampleChart.phrase(bar: 28) }
            ),
            (
                "a last phrase exactly 16 beats before the final note", [],
                { $0.hype[3] = HypePhrase(start: 20736, end: 21312) }
            ),
            (
                "five phrases: 40 beats of Hype in a 127-beat song", [.hypeCapacity],
                { $0.hype.insert(ExampleChart.phrase(bar: 1), at: 0) }
            ),
            (
                "five phrases in a song stretched to exactly 133 1/3 beats", [],
                {
                    $0.hype.insert(ExampleChart.phrase(bar: 1), at: 0)
                    $0.notes[$0.notes.count - 1].length = 1216
                }
            ),
            (
                "five phrases in a song one tick shorter than that", [.hypeCapacity],
                {
                    $0.hype.insert(ExampleChart.phrase(bar: 1), at: 0)
                    $0.notes[$0.notes.count - 1].length = 1215
                }
            ),
        ])
    }

    // The first half lasts 32 seconds; at 60 BPM the second half's 63 beats bring the end to exactly 95.
    @Test("Without a manifest a chart may run to 95 seconds")
    func songLengthWithoutManifest() {
        #expect(!ExampleChart.rules { $0.tempo[1].mbpm = 60_000 }.contains(.songLength))
        #expect(ExampleChart.rules { $0.tempo[1].mbpm = 59_999 }.contains(.songLength))
    }

    // The example's last note is at 61,531.25 ms.
    @Test("With a manifest a chart must match its song and end within its duration")
    func manifest() {
        func rules(id: String = "riff-example", durationMs: Int) -> [ChartIssue.Rule] {
            brokenRules(ExampleChart.make(), manifest: ExampleChart.manifest(id: id, durationMs: durationMs))
        }
        #expect(rules(durationMs: 61_532) == [])
        #expect(rules(durationMs: 61_531) == [.songLength])
        #expect(rules(durationMs: 95_000) == [])
        #expect(rules(durationMs: 95_001) == [.manifestDuration])
        #expect(rules(durationMs: 55_000) == [.songLength])
        #expect(rules(durationMs: 54_999) == [.manifestDuration, .songLength])
        #expect(rules(id: "other-song", durationMs: 62_000) == [.manifestSong])
        #expect(rules(durationMs: .max) == [.manifestDuration])
        #expect(rules(durationMs: .min) == [.manifestDuration, .songLength])
    }
}
