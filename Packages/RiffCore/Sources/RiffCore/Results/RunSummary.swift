/// The immutable result of a completed run.
public struct RunSummary: Codable, Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case notFinished
    }

    public let score: Int64
    public let accuracyBasisPoints: Int
    public let perfectCount: Int
    public let greatCount: Int
    public let goodCount: Int
    public let missCount: Int
    public let longestStreak: Int
    public let noteCount: Int
    public let fullCombo: Bool
    public let stars: Int
    public let hypeActivations: Int
    public let ghostTapCount: Int
    public let lateInputCount: Int
    public let chartHash: String
    public let rulesVersion: Int
    public let difficulty: Difficulty

    public init(session: GameSession, baseScore: Int64) throws {
        guard session.state == .finished else { throw Error.notFinished }
        let scoring = session.scoring
        let score = try scoring.totalScore()
        let noteCount = session.chart.notes.count
        let fullCombo = scoring.missCount == 0 && scoring.penalizedGhostTapCount == 0
        self.score = score
        accuracyBasisPoints = try Accuracy.basisPoints(weightedTotal: scoring.accuracyNumerator, noteCount: noteCount)
        perfectCount = scoring.perfectCount
        greatCount = scoring.greatCount
        goodCount = scoring.goodCount
        missCount = scoring.missCount
        longestStreak = scoring.longestStreak
        self.noteCount = noteCount
        self.fullCombo = fullCombo
        stars = try StarRating.value(
            score: score, baseScore: baseScore, fullCombo: fullCombo, difficulty: session.chart.difficulty,
            config: session.config.stars)
        hypeActivations = session.hypeActivations
        ghostTapCount = scoring.ghostTapCount
        lateInputCount = session.lateInputCount
        chartHash = session.runLog.chartHash
        rulesVersion = session.runLog.rulesVersion
        difficulty = session.chart.difficulty
    }
}
