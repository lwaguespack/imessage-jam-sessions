import RiffCore
import Testing

@Suite("Results and perfect runs")
struct ResultsTests {
    @Test("Accuracy is rounded down in basis points")
    func accuracy() throws {
        #expect(try Accuracy.basisPoints(weightedTotal: 23_000, noteCount: 3) == 7_666)
        #expect(throws: Accuracy.Error.invalidNoteCount) {
            try Accuracy.basisPoints(weightedTotal: 0, noteCount: 0)
        }
    }

    @Test("Star cutoffs round up and Gold requires a Full Combo")
    func stars() throws {
        let config = GameConfig.standard.stars
        #expect(try StarRating.cutoffs(baseScore: 101, shares: [10, 25, 45, 65, 85]) == [11, 26, 46, 66, 86])
        #expect(
            try StarRating.value(score: 85, baseScore: 101, fullCombo: false, difficulty: .expert, config: config)
                == 4)
        #expect(
            try StarRating.value(score: 86, baseScore: 101, fullCombo: true, difficulty: .expert, config: config)
                == 6)
    }

    @Test("The summary derives accuracy, stars and Full Combo from a finished session")
    func summary() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)])
        var game = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
        try game.start()
        try game.apply(.touchDown(id: 1, lane: 0, time: 1_000_000))
        try game.apply(.touchUp(id: 1, time: 1_000_001))
        try game.apply(.touchDown(id: 2, lane: 1, time: 2_130_000))
        try game.advance(to: 2_130_000)
        let result = try RunSummary(session: game, baseScore: 200)
        #expect(result.score == 150)
        #expect(result.accuracyBasisPoints == 7_500)
        #expect(result.fullCombo)
        #expect(result.stars == 4)
        #expect(result.perfectCount == 1)
        #expect(result.goodCount == 1)
    }

    @Test("A penalised ghost before the first hit prevents Gold despite a longest streak of all notes")
    func ghostBeforeFirstHit() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)])
        var game = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
        try game.start()
        try game.apply(.touchDown(id: 9, lane: 3, time: 870_000))
        try game.apply(.touchUp(id: 9, time: 870_001))
        try game.apply(.touchDown(id: 1, lane: 0, time: 1_000_000))
        try game.apply(.touchUp(id: 1, time: 1_000_001))
        try game.apply(.touchDown(id: 2, lane: 1, time: 2_000_000))
        try game.advance(to: 2_000_000)
        let result = try RunSummary(session: game, baseScore: 200)
        #expect(result.longestStreak == 2)
        #expect(result.ghostTapCount == 1)
        #expect(!result.fullCombo)
        #expect(result.stars == 5)
    }

    @Test("An unpenalised ghost is counted but does not disqualify Gold")
    func unpenalizedGhost() throws {
        var config = GameConfig.standard
        config.judging.ghostTapPenalty.expert = .none
        let chart = try EngineTestChart.make(
            notes: [Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)], config: config)
        var game = try GameSession(chart: chart, config: config, chartHash: "deadbeef")
        try game.start()
        try game.apply(.touchDown(id: 9, lane: 3, time: 870_000))
        try game.apply(.touchDown(id: 1, lane: 0, time: 1_000_000))
        try game.apply(.touchDown(id: 2, lane: 1, time: 2_000_000))
        try game.advance(to: 2_000_000)
        let result = try RunSummary(session: game, baseScore: 200)
        #expect(result.ghostTapCount == 1)
        #expect(result.fullCombo)
        #expect(result.stars == 6)
    }

    @Test("A perfect run defines base, but an early Perfect can exceed it without exceeding the ceiling")
    func baseIsNotCeiling() throws {
        var notes = [Note(tick: 0, lane: 0, length: 1_920)]
        notes += (1...9).map { Note(tick: $0 * 96, lane: 1) }
        let chart = try EngineTestChart.make(notes: notes)
        let values = try PerfectRun.compute(chart: chart, config: .standard, chartHash: "deadbeef")
        #expect(values.baseScore == 1_387)
        #expect(values.maxScore == 10_000)

        var game = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
        try game.start()
        try game.apply(.touchDown(id: 0, lane: 0, time: 0))
        try game.apply(.touchUp(id: 0, time: 5_000_000))
        for index in 1...9 {
            let time = chart.notes[index].time - (index == 9 ? 45_000 : 0)
            try game.apply(.touchDown(id: index, lane: 1, time: time))
            try game.apply(.touchUp(id: index, time: time + 1))
        }
        try game.advance(to: 5_000_000)
        #expect(try game.scoring.totalScore() == 1_389)
        #expect(try game.scoring.totalScore() <= values.maxScore)
    }

    @Test("An unfinished run cannot produce a summary")
    func unfinished() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 384, lane: 0)])
        let game = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
        #expect(throws: RunSummary.Error.notFinished) { try RunSummary(session: game, baseScore: 100) }
    }
}
