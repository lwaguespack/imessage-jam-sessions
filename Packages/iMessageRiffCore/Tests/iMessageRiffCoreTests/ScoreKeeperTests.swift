import Testing
import iMessageRiffCore

@Suite("Score keeper")
struct ScoreKeeperTests {
    @Test("Hits use the streak before the hit and Hype multiplies the note")
    func hitMultiplier() throws {
        var score = try ScoreKeeper(config: .standard, difficulty: .easy, resolution: 192)
        for _ in 0..<4 { try score.hit(.perfect, hypeActive: false) }
        #expect(score.notePoints == 400)
        #expect(score.streakMultiplier == 2)
        try score.hit(.great, hypeActive: true)
        #expect(score.notePoints == 720)
        #expect(score.streak == 5)
        #expect(score.perfectCount == 4)
        #expect(score.greatCount == 1)
        #expect(score.accuracyNumerator == 48_000)
    }

    @Test("Sustain is floored once for the whole run")
    func singleSustainFloor() throws {
        var score = try ScoreKeeper(config: .standard, difficulty: .expert, resolution: 192)
        try score.addSustain(ticks: 3, hypeActive: false)
        try score.addSustain(ticks: 5, hypeActive: false)
        #expect(score.sustainUnits == 8)
        #expect(try score.totalScore() == 1)
        try score.addSustain(ticks: 192, hypeActive: true)
        #expect(try score.totalScore() == 51)
    }

    @Test("An early Perfect changes a concurrent hold's multiplier before base score does")
    func earlyPerfectCanBeatBase() throws {
        func run(stepTick: Int64) throws -> Int64 {
            var score = try ScoreKeeper(config: .standard, difficulty: .expert, resolution: 192)
            for _ in 0..<9 { try score.hit(.perfect, hypeActive: false) }
            try score.addSustain(ticks: stepTick, hypeActive: false)
            try score.hit(.perfect, hypeActive: false)
            try score.addSustain(ticks: 1_920 - stepTick, hypeActive: false)
            return try score.totalScore()
        }
        #expect(try run(stepTick: 864) == 1_387)
        #expect(try run(stepTick: 846) == 1_389)
    }

    @Test("A penalised ghost before the first hit remains visible for Full Combo")
    func earlyGhost() throws {
        var score = try ScoreKeeper(config: .standard, difficulty: .expert, resolution: 192)
        try score.ghost()
        for _ in 0..<3 { try score.hit(.perfect, hypeActive: false) }
        #expect(score.longestStreak == 3)
        #expect(score.ghostTapCount == 1)
        #expect(score.penalizedGhostTapCount == 1)
    }

    @Test("Drop-tier lowers even a capped multiplier, while none leaves the streak alone")
    func ghostPolicies() throws {
        var config = GameConfig.standard
        config.judging.ghostTapPenalty.expert = .dropTier
        var score = try ScoreKeeper(config: config, difficulty: .expert, resolution: 192)
        for _ in 0..<60 { try score.hit(.perfect, hypeActive: false) }
        #expect(score.streakMultiplier == 4)
        try score.ghost()
        #expect(score.streak == 20)
        #expect(score.streakMultiplier == 3)
        #expect(score.longestStreak == 60)

        config.judging.ghostTapPenalty.expert = .none
        var unpenalized = try ScoreKeeper(config: config, difficulty: .expert, resolution: 192)
        try unpenalized.hit(.perfect, hypeActive: false)
        try unpenalized.ghost()
        #expect(unpenalized.streak == 1)
        #expect(unpenalized.ghostTapCount == 1)
        #expect(unpenalized.penalizedGhostTapCount == 0)
    }

    @Test("Misses reset the streak and invalid inputs do not mutate the score")
    func missAndErrors() throws {
        var score = try ScoreKeeper(config: .standard, difficulty: .expert, resolution: 192)
        try score.hit(.good, hypeActive: false)
        try score.miss()
        #expect(score.streak == 0)
        #expect(score.missCount == 1)
        #expect(score.goodCount == 1)
        #expect(throws: ScoreKeeper.Error.invalidJudgement) { try score.hit(.miss, hypeActive: false) }
        #expect(throws: ScoreKeeper.Error.negativeSustainTicks) {
            try score.addSustain(ticks: -1, hypeActive: false)
        }
        #expect(try score.totalScore() == 50)

        var invalid = GameConfig.standard
        invalid.judging.good.points = invalid.judging.perfect.points + 1
        #expect(throws: ScoreKeeper.Error.invalidConfiguration) {
            try ScoreKeeper(config: invalid, difficulty: .expert, resolution: 192)
        }
    }
}
