extension GameConfig {
    /// Whether a difficulty's charts may use chords (plan 8.4).
    public enum ChordAllowance: String, CaseIterable, Codable, Sendable {
        /// No chords at all.
        case forbidden
        /// Chords are allowed but should be uncommon. The plan sets no number; chart review judges it.
        case rare
        /// Chords are a normal part of the chart.
        case allowed
    }

    /// One row of the difficulty table that chart validation enforces (plan 8.4).
    ///
    /// Note densities are in thousandths of a note per second so that 3.5 notes per second is the integer 3,500.
    public struct ChartRule: Codable, Equatable, Sendable {
        /// Lowest average density over the whole chart, in thousandths of a note per second.
        public var minAverageMilliNotesPerSecond: Int

        /// Highest average density over the whole chart, in thousandths of a note per second.
        public var maxAverageMilliNotesPerSecond: Int

        /// Highest density the busiest stretch may reach, in thousandths of a note per second.
        public var maxPeakMilliNotesPerSecond: Int

        /// Whether chords may appear.
        public var chords: ChordAllowance

        /// Shortest time between two notes on one lane, in microseconds.
        public var minSameLaneGapMicros: Int64

        /// Shortest hold, in beats.
        public var shortestHold: BeatFraction

        public init(
            minAverageMilliNotesPerSecond: Int,
            maxAverageMilliNotesPerSecond: Int,
            maxPeakMilliNotesPerSecond: Int,
            chords: ChordAllowance,
            minSameLaneGapMicros: Int64,
            shortestHold: BeatFraction
        ) {
            self.minAverageMilliNotesPerSecond = minAverageMilliNotesPerSecond
            self.maxAverageMilliNotesPerSecond = maxAverageMilliNotesPerSecond
            self.maxPeakMilliNotesPerSecond = maxPeakMilliNotesPerSecond
            self.chords = chords
            self.minSameLaneGapMicros = minSameLaneGapMicros
            self.shortestHold = shortestHold
        }
    }

    /// Chart format constants and the per-difficulty chart rules (plan 8.4, appendix A).
    public struct Charts: Codable, Equatable, Sendable {
        /// Version written into every chart file (plan appendix A).
        public var schemaVersion = RiffCoreInfo.chartSchemaVersion

        /// Ticks per quarter note used by the charting editor. Each chart states its own resolution; this is
        /// what generated charts use (plan appendix A).
        public var defaultTicksPerBeat = 192

        /// The difficulty table (plan 8.4).
        public var rules = PerDifficulty(
            easy: ChartRule(
                minAverageMilliNotesPerSecond: 1_000,
                maxAverageMilliNotesPerSecond: 2_000,
                maxPeakMilliNotesPerSecond: 3_000,
                chords: .forbidden,
                minSameLaneGapMicros: 400_000,
                shortestHold: BeatFraction(1, 1)
            ),
            medium: ChartRule(
                minAverageMilliNotesPerSecond: 2_000,
                maxAverageMilliNotesPerSecond: 3_500,
                maxPeakMilliNotesPerSecond: 5_000,
                chords: .rare,
                minSameLaneGapMicros: 250_000,
                shortestHold: BeatFraction(1, 2)
            ),
            hard: ChartRule(
                minAverageMilliNotesPerSecond: 3_500,
                maxAverageMilliNotesPerSecond: 5_000,
                maxPeakMilliNotesPerSecond: 7_000,
                chords: .allowed,
                minSameLaneGapMicros: 150_000,
                shortestHold: BeatFraction(1, 2)
            ),
            expert: ChartRule(
                minAverageMilliNotesPerSecond: 5_000,
                maxAverageMilliNotesPerSecond: 7_000,
                maxPeakMilliNotesPerSecond: 10_000,
                chords: .allowed,
                minSameLaneGapMicros: 90_000,
                shortestHold: BeatFraction(1, 4)
            )
        )
    }

    /// Requirements on song source material (plan 8.2).
    public struct Songs: Codable, Equatable, Sendable {
        /// Shortest song edit, in microseconds: 60 s (plan 8.2).
        public var minDurationMicros: Int64 = 60_000_000

        /// Longest song edit, in microseconds: 120 s (plan 8.2). Section 4 describes a typical run as 60 to 90 s;
        /// this is the hard limit.
        public var maxDurationMicros: Int64 = 120_000_000

        /// Sample rates accepted for source audio, in hertz (plan 8.2).
        public var sourceSampleRatesHz = [44_100, 48_000]

        /// Integrated loudness every song is matched to, in LUFS (plan 8.2).
        public var targetLoudnessLUFS = -14

        /// Edge length of the square artwork, in pixels (plan 8.2).
        public var artworkPixels = 1024
    }

    /// Performance budgets the app is measured against (plan 7.4).
    ///
    /// Each maximum is a value to stay under. Sizes read "KB" as 1,024 bytes and "MB" as 1,024 KB.
    public struct Budgets: Codable, Equatable, Sendable {
        /// Frame rate on every device (plan 7.4).
        public var targetFramesPerSecond = 60

        /// Frame rate on ProMotion iPhones (plan 7.4).
        public var proMotionFramesPerSecond = 120

        /// Dropped frames during a song, in basis points of all frames: 1% (plan 7.4).
        public var maxDroppedFramesBasisPoints = 100

        /// Time from opening the app to the Home screen, in microseconds: 1 s (plan 7.4).
        public var maxOpenToHomeMicros: Int64 = 1_000_000

        /// Time to load a song, in microseconds: 500 ms (plan 7.4).
        public var maxSongLoadMicros: Int64 = 500_000

        /// Size of the rendered score-card image, in bytes: 300 KB (plan 5.3, 7.4).
        public var maxScoreCardBytes = 300 * 1024

        /// App download size with five songs, in bytes: 60 MB (plan 7.4).
        public var maxAppDownloadBytes = 60 * 1024 * 1024
    }
}
