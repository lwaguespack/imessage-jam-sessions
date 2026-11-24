extension GameConfig {
    /// XP awarded per run (plan 6.1).
    ///
    /// Order of operations: add the events, apply the streak bonus, apply the featured-song multiplier, round
    /// down.
    public struct XP: Codable, Equatable, Sendable {
        /// Finishing a song (plan 6.1).
        public var finishRun = 100

        /// Each star earned; Gold counts as `Stars.goldStarValue` stars (plan 6.1).
        public var perStar = 20

        /// A Full Combo (plan 6.1).
        public var fullCombo = 50

        /// Winning a duel round (plan 6.1).
        public var duelWin = 75

        /// Group round podium, first place first (plan 6.1).
        public var groupPodium = [75, 50, 25]

        /// The first finished run of a local calendar day (plan 6.1).
        public var firstRunOfDay = 100

        /// Daily-streak bonus per consecutive day, in percent (plan 6.1).
        public var streakBonusPercentPerDay = 10

        /// Cap on the daily-streak bonus, in percent (plan 6.1).
        public var maxStreakBonusPercent = 50

        /// XP earned on the featured song of the week, as a percentage of normal: 1.5 times (plan 6.1).
        public var featuredSongPercent = 150

        /// XP earned by a practice run, as a percentage of normal: half (plan 6.1).
        public var practicePercent = 50

        /// A skipped local day still advances the streak if less real time than this has elapsed (D-108).
        public var dailyTravelGraceSeconds: Int64 = 172_800

        /// Monday 2026-01-05 00:00 UTC, the fixed epoch for the featured rotation (D-074).
        public var featuredEpochUnixSeconds: Int64 = 1_767_571_200
    }

    /// The level curve: going from level L to L + 1 costs `xpToAdvanceBase + xpToAdvancePerLevel * L` (plan 6.2).
    public struct Levels: Codable, Equatable, Sendable {
        /// Constant term of the cost of a level: the 400 in 400 + 100L (plan 6.2).
        public var xpToAdvanceBase = 400

        /// Per-level term of the cost of a level: the 100 in 400 + 100L (plan 6.2).
        public var xpToAdvancePerLevel = 100

        /// Highest level a player can reach (plan section 6).
        public var maxLevel = 50
    }

    /// How many cosmetics of each kind v1 ships, and where the unlock table must hand them out (plan 6.3).
    public struct Unlocks: Codable, Equatable, Sendable {
        /// Titles, shown in the bubble next to the nickname (plan 6.3).
        public var titles = 15

        /// Score-card frames, shown in the bubble (plan 6.3).
        public var scoreCardFrames = 6

        /// Note skins, shown on the highway (plan 6.3).
        public var noteSkins = 8

        /// Highway themes (plan 6.3).
        public var highwayThemes = 6

        /// Strike-line effects (plan 6.3).
        public var strikeLineEffects = 5

        /// First of the early levels that must each unlock something (plan 6.3).
        public var guaranteedFromLevel = 2

        /// Last of the early levels that must each unlock something (plan 6.3).
        public var guaranteedThroughLevel = 10
    }
}
