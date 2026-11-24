/// Integer note points, streaks and the one run-wide sustain accumulator.
public struct ScoreKeeper: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case invalidJudgement
        case negativeSustainTicks
        case overflow
    }

    private let judging: GameConfig.Judging
    private let ghostPenalty: GameConfig.GhostTapPenalty
    private let step: Int
    private let maxMultiplier: Int
    private let hypeMultiplier: Int64
    private let sustainPointsPerBeat: Int64
    private let resolution: Int64

    public private(set) var streak = 0
    public private(set) var longestStreak = 0
    public private(set) var notePoints: Int64 = 0
    public private(set) var sustainUnits: Int64 = 0
    public private(set) var accuracyNumerator: Int64 = 0
    public private(set) var perfectCount = 0
    public private(set) var greatCount = 0
    public private(set) var goodCount = 0
    public private(set) var missCount = 0
    public private(set) var ghostTapCount = 0
    public private(set) var penalizedGhostTapCount = 0

    public var streakMultiplier: Int {
        let tier = streak / step
        return tier >= maxMultiplier - 1 ? maxMultiplier : tier + 1
    }

    public init(config: GameConfig, difficulty: Difficulty, resolution: Int) throws {
        let step = config.scoring.streakPerMultiplierStep[difficulty]
        let rules = [config.judging.perfect, config.judging.great, config.judging.good]
        guard
            resolution > 0, step > 0, config.scoring.maxStreakMultiplier > 0,
            config.scoring.sustainPointsPerBeat >= 0, config.hype.multiplier > 0,
            rules.allSatisfy({ $0.points >= 0 && (0...10_000).contains($0.accuracyBasisPoints) }),
            config.judging.perfect.points >= config.judging.great.points,
            config.judging.great.points >= config.judging.good.points,
            config.judging.perfect.accuracyBasisPoints >= config.judging.great.accuracyBasisPoints,
            config.judging.great.accuracyBasisPoints >= config.judging.good.accuracyBasisPoints
        else { throw Error.invalidConfiguration }
        judging = config.judging
        ghostPenalty = config.judging.ghostTapPenalty[difficulty]
        self.step = step
        maxMultiplier = config.scoring.maxStreakMultiplier
        hypeMultiplier = Int64(config.hype.multiplier)
        sustainPointsPerBeat = Int64(config.scoring.sustainPointsPerBeat)
        self.resolution = Int64(resolution)
    }

    /// Scores a hit with the multiplier before that hit increments the streak.
    public mutating func hit(_ judgement: Judgement, hypeActive: Bool) throws {
        let rule: GameConfig.JudgementRule
        var perfect = perfectCount
        var great = greatCount
        var good = goodCount
        switch judgement {
        case .perfect:
            rule = judging.perfect
            perfect = try Self.increment(perfect)
        case .great:
            rule = judging.great
            great = try Self.increment(great)
        case .good:
            rule = judging.good
            good = try Self.increment(good)
        case .miss:
            throw Error.invalidJudgement
        }
        let multiplier = try effectiveMultiplier(hypeActive: hypeActive)
        let points = try Self.multiply(Int64(rule.points), multiplier)
        let newPoints = try Self.add(notePoints, points)
        let newAccuracy = try Self.add(accuracyNumerator, Int64(rule.accuracyBasisPoints))
        let newStreak = try Self.increment(streak)
        notePoints = newPoints
        accuracyNumerator = newAccuracy
        streak = newStreak
        longestStreak = max(longestStreak, newStreak)
        perfectCount = perfect
        greatCount = great
        goodCount = good
    }

    public mutating func miss() throws {
        missCount = try Self.increment(missCount)
        streak = 0
    }

    /// Records a non-ignored ghost tap using the configured penalty.
    public mutating func ghost() throws {
        let count = try Self.increment(ghostTapCount)
        let penalized = ghostPenalty == .none ? penalizedGhostTapCount : try Self.increment(penalizedGhostTapCount)
        let nextStreak: Int
        switch ghostPenalty {
        case .none:
            nextStreak = streak
        case .resetStreak:
            nextStreak = 0
        case .dropTier:
            let multiplier = streakMultiplier
            if multiplier <= 1 {
                nextStreak = 0
            } else {
                let (value, overflow) = (multiplier - 2).multipliedReportingOverflow(by: step)
                guard !overflow else { throw Error.overflow }
                nextStreak = value
            }
        }
        ghostTapCount = count
        penalizedGhostTapCount = penalized
        streak = nextStreak
    }

    /// Adds the total live hold ticks in an interval with one fixed multiplier.
    public mutating func addSustain(ticks: Int64, hypeActive: Bool) throws {
        guard ticks >= 0 else { throw Error.negativeSustainTicks }
        let units = try Self.multiply(ticks, effectiveMultiplier(hypeActive: hypeActive))
        sustainUnits = try Self.add(sustainUnits, units)
    }

    /// Applies the single sustain floor when the score is read.
    public func totalScore() throws -> Int64 {
        let numerator = try Self.multiply(sustainPointsPerBeat, sustainUnits)
        return try Self.add(notePoints, numerator / resolution)
    }

    private func effectiveMultiplier(hypeActive: Bool) throws -> Int64 {
        try Self.multiply(Int64(streakMultiplier), hypeActive ? hypeMultiplier : 1)
    }

    private static func increment(_ value: Int) throws -> Int {
        let (result, overflow) = value.addingReportingOverflow(1)
        guard !overflow else { throw Error.overflow }
        return result
    }

    private static func add(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw Error.overflow }
        return result
    }

    private static func multiply(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.multipliedReportingOverflow(by: right)
        guard !overflow else { throw Error.overflow }
        return result
    }
}
