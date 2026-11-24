import Testing
import iMessageRiffCore

@Suite("Judge")
struct JudgeTests {
    private struct Edge: Sendable {
        let offset: Int64
        let judgement: Judgement
    }

    private func chart(
        _ notes: [Note], difficulty: Difficulty = .expert, config: GameConfig = .standard
    ) throws -> CompiledChart {
        let chart = Chart(
            songId: "judge-test", part: .lead, difficulty: difficulty, lanes: 4, resolution: 192,
            tempo: [TempoSegment(tick: 0, mbpm: 120_000)],
            timeSignatures: [TimeSignature(tick: 0, numerator: 4, denominator: 4)],
            notes: notes, hype: [], sections: [],
            computed: ChartComputed(
                rulesVersion: 0, noteCount: 0, baseScore: 0, maxScore: 0, starCutoffs: [], hash: "")
        )
        return try CompiledChart(chart: chart, config: config)
    }

    @Test(
        "Judgement windows include both edges",
        arguments: [
            Edge(offset: -130_000, judgement: .good), Edge(offset: -90_001, judgement: .good),
            Edge(offset: -90_000, judgement: .great), Edge(offset: -45_001, judgement: .great),
            Edge(offset: -45_000, judgement: .perfect), Edge(offset: 45_000, judgement: .perfect),
            Edge(offset: 45_001, judgement: .great), Edge(offset: 90_000, judgement: .great),
            Edge(offset: 90_001, judgement: .good), Edge(offset: 130_000, judgement: .good),
        ]
    )
    private func windowEdges(_ edge: Edge) throws {
        var judge = try Judge(chart: chart([Note(tick: 384, lane: 0)]), config: .standard)
        #expect(
            try judge.touchDown(lane: 0, at: 1_000_000 + edge.offset)
                == .hit(noteIndex: 0, judgement: edge.judgement, offsetMicros: edge.offset))
        #expect(judge.allJudged)
    }

    @Test(
        "Easy scales every judgement window",
        arguments: [
            Edge(offset: -54_000, judgement: .perfect), Edge(offset: -54_001, judgement: .great),
            Edge(offset: 108_000, judgement: .great), Edge(offset: 108_001, judgement: .good),
            Edge(offset: 156_000, judgement: .good),
        ]
    )
    private func easyWindows(_ edge: Edge) throws {
        var judge = try Judge(chart: chart([Note(tick: 384, lane: 0)], difficulty: .easy), config: .standard)
        #expect(
            try judge.touchDown(lane: 0, at: 1_000_000 + edge.offset)
                == .hit(noteIndex: 0, judgement: edge.judgement, offsetMicros: edge.offset))
    }

    @Test("An exact deadline is still a hit, and its later scheduled miss is stale")
    func deadlineIsInclusive() throws {
        var judge = try Judge(chart: chart([Note(tick: 384, lane: 0)]), config: .standard)
        #expect(throws: Judge.Error.prematureMiss(noteIndex: 0)) {
            try judge.miss(noteIndex: 0, at: 1_129_999)
        }
        #expect(
            try judge.touchDown(lane: 0, at: 1_130_000)
                == .hit(noteIndex: 0, judgement: .good, offsetMicros: 130_000))
        #expect(try !judge.miss(noteIndex: 0, at: 1_130_000))
        #expect(try judge.judgement(ofNoteAt: 0) == .good)
    }

    @Test("A missed note does not capture the next same-lane Perfect")
    func skippedNote() throws {
        var judge = try Judge(
            chart: chart([Note(tick: 384, lane: 0), Note(tick: 456, lane: 0)]), config: .standard)
        #expect(try judge.miss(noteIndex: 0, at: 1_130_000))
        #expect(try judge.judgement(ofNoteAt: 0) == .miss)
        #expect(
            try judge.touchDown(lane: 0, at: 1_187_500)
                == .hit(noteIndex: 1, judgement: .perfect, offsetMicros: 0))
    }

    @Test("Overlapping windows use the earliest unjudged note in that lane")
    func earliestMatch() throws {
        var judge = try Judge(
            chart: chart([Note(tick: 384, lane: 0), Note(tick: 456, lane: 0)]), config: .standard)
        #expect(
            try judge.touchDown(lane: 0, at: 1_080_000)
                == .hit(noteIndex: 0, judgement: .great, offsetMicros: 80_000))
        #expect(
            try judge.touchDown(lane: 0, at: 1_187_500)
                == .hit(noteIndex: 1, judgement: .perfect, offsetMicros: 0))
    }

    @Test("Chord lanes are judged independently")
    func chord() throws {
        var judge = try Judge(
            chart: chart([Note(tick: 384, lane: 0), Note(tick: 384, lane: 2)]), config: .standard)
        #expect(
            try judge.touchDown(lane: 2, at: 1_000_000)
                == .hit(noteIndex: 1, judgement: .perfect, offsetMicros: 0))
        #expect(
            try judge.touchDown(lane: 0, at: 1_000_000)
                == .hit(noteIndex: 0, judgement: .perfect, offsetMicros: 0))
    }

    @Test("The first window, bounce grace and final judgement exemptions have exact boundaries")
    func ghostExemptions() throws {
        var judge = try Judge(
            chart: chart([Note(tick: 384, lane: 0), Note(tick: 768, lane: 0)]), config: .standard)
        #expect(try judge.touchDown(lane: 1, at: 869_999) == .ignored(.beforeFirstWindow))
        #expect(try judge.touchDown(lane: 1, at: 870_000) == .ghost(penalty: .resetStreak))
        #expect(
            try judge.touchDown(lane: 0, at: 1_000_000)
                == .hit(noteIndex: 0, judgement: .perfect, offsetMicros: 0))
        #expect(try judge.touchDown(lane: 0, at: 1_080_000) == .ignored(.bounce))
        #expect(try judge.touchDown(lane: 0, at: 1_080_001) == .ghost(penalty: .resetStreak))
        #expect(
            try judge.touchDown(lane: 0, at: 2_000_000)
                == .hit(noteIndex: 1, judgement: .perfect, offsetMicros: 0))
        #expect(try judge.touchDown(lane: 1, at: 2_000_001) == .ignored(.allJudged))
    }

    @Test("The configured penalty is attached to each non-ignored ghost tap")
    func ghostPenalty() throws {
        for penalty in GameConfig.GhostTapPenalty.allCases {
            var config = GameConfig.standard
            config.judging.ghostTapPenalty.expert = penalty
            var judge = try Judge(chart: chart([Note(tick: 384, lane: 0)], config: config), config: config)
            #expect(try judge.touchDown(lane: 1, at: 870_000) == .ghost(penalty: penalty))
        }
    }

    @Test("Invalid input, backwards time and unprocessed earlier misses are explicit errors")
    func rejectsInvalidOrdering() throws {
        let compiled = try chart([Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)])
        var judge = try Judge(chart: compiled, config: .standard)
        #expect(throws: Judge.Error.invalidLane(-1)) { try judge.touchDown(lane: -1, at: 0) }
        #expect(try judge.touchDown(lane: 1, at: 0) == .ignored(.beforeFirstWindow))
        #expect(throws: Judge.Error.timeMovedBackwards) { try judge.touchDown(lane: 1, at: -1) }
        #expect(throws: Judge.Error.overdueMiss(noteIndex: 0)) {
            try judge.touchDown(lane: 1, at: 1_130_001)
        }
        #expect(throws: Judge.Error.invalidNoteIndex(2)) { try judge.miss(noteIndex: 2, at: 1_130_000) }

        var different = GameConfig.standard
        different.judging.good.windowMicros += 1
        #expect(throws: Judge.Error.deadlineMismatch(noteIndex: 0)) {
            try Judge(chart: compiled, config: different)
        }
    }
}
