extension GameConfig {
    /// Timing and miss parameters for seeded test bots, not player scoring rules.
    public struct BotSkill: Codable, Equatable, Sendable {
        public var timingStdDevMicros: Int64
        public var missChanceBasisPoints: Int

        public init(timingStdDevMicros: Int64, missChanceBasisPoints: Int) {
            self.timingStdDevMicros = timingStdDevMicros
            self.missChanceBasisPoints = missChanceBasisPoints
        }
    }

    public struct Simulation: Codable, Equatable, Sendable {
        public var skilled = BotSkill(timingStdDevMicros: 15_000, missChanceBasisPoints: 50)
        public var good = BotSkill(timingStdDevMicros: 25_000, missChanceBasisPoints: 150)
        public var casual = BotSkill(timingStdDevMicros: 35_000, missChanceBasisPoints: 400)
        public var beginner = BotSkill(timingStdDevMicros: 60_000, missChanceBasisPoints: 1_000)
        public var clusterStartBasisPoints = 300
        public var clusterContinueBasisPoints = 6_500
        public var tapDurationMicros: Int64 = 20_000
        public var masherPeriodsMicros: [Int64] = [200_000, 250_000]
        public var maxInputEvents = 100_000
        public var maxRuns = 10_000
    }
}
