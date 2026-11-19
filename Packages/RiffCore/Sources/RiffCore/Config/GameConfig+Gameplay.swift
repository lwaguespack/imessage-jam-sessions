extension GameConfig {
    /// Lanes, on-screen geometry and note travel times (plan 4.1, 4.2).
    public struct Highway: Codable, Equatable, Sendable {
        /// Number of lanes, the same on every difficulty (plan 4.1).
        public var laneCount = 4

        /// Most notes that may share one tick (plan 4.2).
        public var maxNotesPerChord = 2

        /// Height of the strike line above the bottom edge, as a percentage of the view height (plan 4.1).
        public var strikeLinePercentFromBottom = 18

        /// Height of the touch zones, measured up from the bottom edge, as a percentage of the view height
        /// (plan 4.1).
        public var touchZoneHeightPercent = 35

        /// Default time a note spends on screen, per difficulty, in microseconds (plan 4.1).
        ///
        /// The plan gives only the endpoints: Easy 1.6 s and Expert 1.1 s. Medium and Hard are interpolated
        /// between them (linear, rounded to 50 ms), pending playtest.
        public var scrollTimeMicros = PerDifficulty<Int64>(
            easy: 1_600_000,
            medium: 1_450_000,
            hard: 1_250_000,
            expert: 1_100_000
        )

        /// Shortest scroll time a player may choose, in microseconds (plan 4.1).
        public var minScrollTimeMicros: Int64 = 700_000

        /// Longest scroll time a player may choose, in microseconds (plan 4.1).
        public var maxScrollTimeMicros: Int64 = 2_000_000
    }

    /// One row of the judgement table (plan 4.3).
    public struct JudgementRule: Codable, Equatable, Sendable {
        /// Half-width of the timing window, in microseconds either side of the note, before the per-difficulty
        /// scale is applied.
        public var windowMicros: Int64

        /// Points for the note, before the multiplier.
        public var points: Int

        /// Share of a full note this judgement adds to accuracy, in basis points (10,000 = 1.0).
        public var accuracyBasisPoints: Int

        public init(windowMicros: Int64, points: Int, accuracyBasisPoints: Int) {
            self.windowMicros = windowMicros
            self.points = points
            self.accuracyBasisPoints = accuracyBasisPoints
        }
    }

    /// Timing windows, points and accuracy weights (plan 4.3).
    ///
    /// A miss has no row: it is any note left unhit once the Good window has passed, and it is worth nothing.
    public struct Judging: Codable, Equatable, Sendable {
        /// Perfect: within 45 ms, 100 points, weight 1.0 (plan 4.3).
        public var perfect = JudgementRule(windowMicros: 45_000, points: 100, accuracyBasisPoints: 10_000)

        /// Great: within 90 ms, 80 points, weight 0.8 (plan 4.3).
        public var great = JudgementRule(windowMicros: 90_000, points: 80, accuracyBasisPoints: 8_000)

        /// Good: within 130 ms, 50 points, weight 0.5 (plan 4.3).
        public var good = JudgementRule(windowMicros: 130_000, points: 50, accuracyBasisPoints: 5_000)

        /// Scale applied to every window, per difficulty, in percent. Easy widens every window by 20% (plan 4.3).
        public var windowScalePercent = PerDifficulty(easy: 120, medium: 100, hard: 100, expert: 100)

        /// What a touch that matches no note costs, per difficulty (D-052).
        public var ghostTapPenalty = PerDifficulty<GhostTapPenalty>(
            easy: .resetStreak,
            medium: .resetStreak,
            hard: .resetStreak,
            expert: .resetStreak
        )

        /// A touch this soon after a hit in the same lane is ignored instead of counted as a ghost tap (D-052).
        public var bounceGraceMicros: Int64 = 80_000
    }

    /// What a touch that matches no note costs (D-052). It is never a Miss.
    public enum GhostTapPenalty: String, CaseIterable, Codable, Sendable {
        case none
        case dropTier
        case resetStreak
    }

    /// Streak multiplier and sustain points (plan 4.4).
    public struct Scoring: Codable, Equatable, Sendable {
        /// Streak length that adds one step to the multiplier, per difficulty: m = 1 + floor(streak / step) (D-053).
        public var streakPerMultiplierStep = PerDifficulty(easy: 4, medium: 6, hard: 8, expert: 10)

        /// Highest streak multiplier, before Hype (plan 4.4).
        public var maxStreakMultiplier = 4

        /// Points a hold earns per beat held, before the multiplier (plan 4.4).
        public var sustainPointsPerBeat = 25
    }

    /// The Hype meter (plan 4.5).
    ///
    /// The meter is counted in beats of active Hype, which turns the plan's 25%, 50% and 1/32-per-beat into
    /// whole numbers.
    public struct Hype: Codable, Equatable, Sendable {
        /// A full meter: it lasts 32 beats once active (plan 4.5).
        public var meterCapacity = 32

        /// Meter gained by completing a phrase: 25% of a full meter (plan 4.5).
        public var phraseGain = 8

        /// Least meter needed to activate: 50% of a full meter (plan 4.5).
        public var activationMinimum = 16

        /// Meter drained per beat while active: 1/32 of a full meter (plan 4.5).
        public var drainPerBeat = 1

        /// Factor applied to the streak multiplier while active (plan 4.4, 4.5).
        public var multiplier = 2
    }

    /// Star thresholds and the Gold rule (plan 4.6).
    public struct Stars: Codable, Equatable, Sendable {
        /// Score needed for each star, 1 to 5 in order, as a percentage of the chart's base score, per difficulty
        /// (D-053).
        public var sharesPercent = PerDifficulty(
            easy: [10, 25, 45, 65, 85],
            medium: [10, 25, 45, 65, 85],
            hard: [10, 25, 45, 65, 85],
            expert: [10, 25, 45, 65, 85]
        )

        /// Stars a run needs, together with a Full Combo, to count as Gold (plan 4.6).
        public var goldMinimumStars = 5

        /// The star count that stands for Gold in payloads and in XP (plan 6.1, appendix C).
        public var goldStarValue = 6
    }

    /// Lead-in, countdowns, the miss duck and clock drift (plan 4.7, 4.8, 7.3).
    public struct Playback: Codable, Equatable, Sendable {
        /// Shortest lead-in before the music starts, in microseconds. The first notes always get their full
        /// scroll time, so this must cover the longest scroll time a player may choose (plan 4.7).
        public var minLeadInMicros: Int64 = 2_000_000

        /// Beats counted in before the song starts: 3-2-1 (plan 4.7).
        public var startCountdownBeats = 3

        /// Beats counted in before play resumes after a pause (plan 4.7).
        public var resumeCountdownBeats = 3

        /// How far behind real time the driver advances the engine, in microseconds, so a touch that is delivered
        /// late is never swept as a miss first (D-050).
        public var inputGuardMicros: Int64 = 50_000

        /// Shortest time a miss ducks the instrument stem, in microseconds; the duck ends at the next hit (D-038).
        public var missDuckMinMicros: Int64 = 120_000

        /// Longest time a miss ducks the instrument stem, in microseconds (D-038).
        public var missDuckMaxMicros: Int64 = 600_000

        /// How often the clock estimate is compared with the rendered sample time, in microseconds (plan 7.3).
        public var driftCheckIntervalMicros: Int64 = 1_000_000

        /// Clock drift beyond this many microseconds is corrected gradually (plan 7.3).
        public var driftCorrectionThresholdMicros: Int64 = 3_000
    }
}

extension GameConfig.Judging {
    /// Half-width of a judgement's window on a difficulty, in microseconds, rounded down (GAME_RULES section 3).
    public func windowMicros(of rule: GameConfig.JudgementRule, on difficulty: Difficulty) -> Int64 {
        rule.windowMicros * Int64(windowScalePercent[difficulty]) / 100
    }
}
