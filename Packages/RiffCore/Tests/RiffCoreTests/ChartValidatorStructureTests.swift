import RiffCore
import Testing

@Suite("Chart validator: structure")
struct ChartValidatorStructureTests {
    @Test("The example chart passes every rule")
    func exampleIsValid() {
        let issues = ChartValidator.issues(in: ExampleChart.make(), config: .standard)
        let found = issues.map { "\($0.rule) at tick \($0.tick ?? -1): \($0.message)" }
        #expect(issues.isEmpty, "\(found)")
        #expect(ExampleChart.make().notes.count == 163)
    }

    @Test("Each structure rule is reported, and on its own")
    func eachRule() {
        // The last tick any valid chart can reach: 95 seconds at 300 BPM and resolution 960.
        let lastTick = 456_000
        let cases: [(name: String, rules: [ChartIssue.Rule], change: (inout Chart) -> Void)] = [
            ("another format", [.format], { $0.format = "riff-song" }),
            ("another version", [.format], { $0.version = 2 }),
            ("an empty song id", [.songId], { $0.songId = "" }),
            ("a song id with a capital and a space", [.songId], { $0.songId = "Neon Nights" }),
            ("a song id of 25 characters", [.songId], { $0.songId = String(repeating: "a", count: 25) }),
            ("five lanes", [.lanes], { $0.lanes = 5 }),
            ("resolution 0", [.resolution], { $0.resolution = 0 }),
            ("resolution 961", [.resolution], { $0.resolution = 961 }),
            ("no tempo", [.tempoList], { $0.tempo = [] }),
            ("a tempo list that starts late", [.tempoList], { $0.tempo[0].tick = 96 }),
            ("a tempo tick repeated", [.tempoList], { $0.tempo[1].tick = 0 }),
            ("a tempo change past the last tick", [.tempoList], { $0.tempo[1].tick = lastTick + 1 }),
            ("a tempo under 40 BPM", [.tempoRange], { $0.tempo[0].mbpm = 39_999 }),
            ("a tempo over 300 BPM", [.tempoRange], { $0.tempo[1].mbpm = 300_001 }),
            ("a negative tick", [.noteTick], { $0.notes[0].tick = -1 }),
            ("a tick past the last one", [.noteTick], { $0.notes[$0.notes.count - 1].tick = lastTick + 1 }),
            ("lane 4", [.noteLane], { $0.notes[0].lane = 4 }),
            ("a hold of length 0", [.holdLength], { $0.notes[0].length = 0 }),
            ("a hold longer than any chart", [.holdLength], { $0.notes[0].length = lastTick + 1 }),
            ("notes out of order", [.noteOrder], { $0.notes.swapAt(1, 2) }),
            ("a note written twice", [.noteOrder], { $0.notes.insert($0.notes[1], at: 2) }),
            ("three notes on a tick", [.chordSize], { $0.addTap(bar: 3, slot: 4, lane: 0) }),
            ("an empty phrase", [.phraseRange], { $0.hype[0].end = $0.hype[0].start }),
            ("a phrase past the last tick", [.phraseRange], { $0.hype[3].end = lastTick + 1 }),
            ("phrases out of order", [.phraseOrder], { $0.hype.swapAt(0, 1) }),
            ("phrases that overlap", [.phraseOrder], { $0.hype[1].start = $0.hype[0].end - 1 }),
        ]
        for testCase in cases {
            #expect(ExampleChart.rules(after: testCase.change) == testCase.rules, "\(testCase.name)")
        }
    }

    @Test("The limits themselves are allowed")
    func limitsAreInclusive() {
        let lastTick = 456_000
        let valid: [(name: String, change: (inout Chart) -> Void)] = [
            ("a song id of 24 characters", { $0.songId = String(repeating: "a", count: 21) + "-09" }),
            ("a phrase that starts where the one before ends", { $0.hype[1].start = $0.hype[0].end }),
        ]
        for testCase in valid {
            #expect(ExampleChart.rules(after: testCase.change) == [], "\(testCase.name)")
        }
        // These move every time in the chart and so break content rules; only the structure rules are looked at.
        let structureRules: Set<ChartIssue.Rule> = [
            .resolution, .tempoList, .tempoRange, .noteTick, .holdLength, .phraseRange,
        ]
        let extremes: [(name: String, change: (inout Chart) -> Void)] = [
            ("resolution 960", { $0.resolution = 960 }),
            ("resolution 1", { $0.resolution = 1 }),
            ("40 BPM", { $0.tempo[0].mbpm = 40_000 }),
            ("300 BPM", { $0.tempo[1].mbpm = 300_000 }),
            ("a tempo change on the last tick", { $0.tempo[1].tick = lastTick }),
            ("a note on the last tick", { $0.notes[$0.notes.count - 1].tick = lastTick }),
            ("a hold as long as the longest chart", { $0.notes[0].length = lastTick }),
            ("a phrase that ends on the last tick", { $0.hype[3].end = lastTick }),
        ]
        for testCase in extremes {
            let rules = ExampleChart.rules(after: testCase.change)
            #expect(structureRules.isDisjoint(with: rules), "\(testCase.name)")
        }
    }

    @Test("A chart that fails structure gets only those issues")
    func structureComesFirst() {
        let rules = ExampleChart.rules {
            $0.lanes = 5
            $0.difficulty = .hard
            $0.hype = []
        }
        #expect(rules == [.lanes])
    }

    @Test("An issue says where the problem is")
    func issuesCarryTheirPlace() {
        var chart = ExampleChart.make()
        chart.notes[0].lane = 4
        let issue = ChartValidator.issues(in: chart, config: .standard).first
        #expect(issue?.rule == .noteLane)
        #expect(issue?.tick == 0)
        #expect(issue?.lane == 4)
        #expect(issue?.message.isEmpty == false)
    }

    // A chart file is outside data: no number in it may crash the validator.
    @Test("Extreme numbers are reported, not trapped on")
    func extremeNumbers() {
        let rules = ExampleChart.rules {
            $0.resolution = .max
            $0.tempo[1] = TempoSegment(tick: .max, mbpm: .max)
            $0.notes[0] = Note(tick: .min, lane: .min, length: .min)
            $0.notes[$0.notes.count - 1] = Note(tick: .max, lane: .max, length: .max)
            $0.hype[0] = HypePhrase(start: .min, end: .max)
        }
        let expected: Set<ChartIssue.Rule> = [
            .resolution, .tempoList, .tempoRange, .noteTick, .noteLane, .holdLength, .phraseRange,
        ]
        #expect(expected.isSubset(of: rules))
    }
}
