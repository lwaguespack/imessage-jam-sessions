extension GameConfig {
    /// One row of the difficulty table that chart validation enforces (plan 8.4, D-054, D-060).
    ///
    /// Note densities are in thousandths of a note per second so that 3.5 notes per second is the integer 3,500.
    public struct ChartRule: Codable, Equatable, Sendable {
        /// Lowest average density over the whole chart, in thousandths of a note per second.
        public var minAverageMilliNotesPerSecond: Int

        /// Highest average density over the whole chart, in thousandths of a note per second.
        public var maxAverageMilliNotesPerSecond: Int

        /// Highest density the busiest stretch may reach, in thousandths of a note per second.
        public var maxPeakMilliNotesPerSecond: Int

        /// Largest share of the chart's notes that may be chord notes, in percent. Zero forbids chords.
        public var maxChordNoteSharePercent: Int

        /// Fewest beats between one chord and the next. Zero sets no limit.
        public var minBeatsBetweenChords: Int

        /// Shortest time between two notes on one lane, in microseconds.
        public var minSameLaneGapMicros: Int64

        /// Shortest time between notes on different ticks, whatever their lanes, in microseconds.
        public var minCrossLaneGapMicros: Int64

        /// Most fingers the chart may ask for at once: live holds plus the notes starting on a tick.
        public var maxSimultaneousContacts: Int

        /// Shortest hold, in beats. `Charts.minHoldMicros` also applies; the longer of the two wins.
        public var shortestHold: BeatFraction

        public init(
            minAverageMilliNotesPerSecond: Int,
            maxAverageMilliNotesPerSecond: Int,
            maxPeakMilliNotesPerSecond: Int,
            maxChordNoteSharePercent: Int,
            minBeatsBetweenChords: Int,
            minSameLaneGapMicros: Int64,
            minCrossLaneGapMicros: Int64,
            maxSimultaneousContacts: Int,
            shortestHold: BeatFraction
        ) {
            self.minAverageMilliNotesPerSecond = minAverageMilliNotesPerSecond
            self.maxAverageMilliNotesPerSecond = maxAverageMilliNotesPerSecond
            self.maxPeakMilliNotesPerSecond = maxPeakMilliNotesPerSecond
            self.maxChordNoteSharePercent = maxChordNoteSharePercent
            self.minBeatsBetweenChords = minBeatsBetweenChords
            self.minSameLaneGapMicros = minSameLaneGapMicros
            self.minCrossLaneGapMicros = minCrossLaneGapMicros
            self.maxSimultaneousContacts = maxSimultaneousContacts
            self.shortestHold = shortestHold
        }
    }

    /// Chart format constants and the per-difficulty chart rules (plan 8.4, appendix A).
    public struct Charts: Codable, Equatable, Sendable {
        /// Version written into every chart file (plan appendix A).
        public var schemaVersion = IMessageRiffCoreInfo.chartSchemaVersion

        /// Ticks per quarter note used by the charting editor. Each chart states its own resolution; this is
        /// what generated charts use (plan appendix A).
        public var defaultTicksPerBeat = 192

        /// Shortest hold on any difficulty, in microseconds (D-056).
        public var minHoldMicros: Int64 = 250_000

        /// Fewest Hype phrases a chart carries (plan 4.5).
        public var minPhrasesPerSong = 4

        /// Most Hype phrases a chart carries (plan 4.5).
        public var maxPhrasesPerSong = 6

        /// Fewest notes a Hype phrase holds.
        public var minNotesPerPhrase = 4

        /// Fewest beats between the end of the last Hype phrase and the final note.
        public var minBeatsAfterLastPhrase = 16

        /// Largest share of the song's beats that the phrases' Hype can cover, in percent.
        public var maxHypeCapacitySharePercent = 30

        /// Finest resolution a chart may use, in ticks per quarter note (D-086).
        public var maxTicksPerBeat = 960

        /// Slowest tempo a chart may use, in milli-BPM.
        public var minTempoMilliBPM = 40_000

        /// Fastest tempo a chart may use, in milli-BPM.
        public var maxTempoMilliBPM = 300_000

        /// Length of the sliding window that peak density is counted over, in microseconds.
        public var peakWindowMicros: Int64 = 1_000_000

        /// The difficulty table (plan 8.4, D-054, D-060).
        public var rules = PerDifficulty(
            easy: ChartRule(
                minAverageMilliNotesPerSecond: 1_000,
                maxAverageMilliNotesPerSecond: 2_000,
                maxPeakMilliNotesPerSecond: 3_000,
                maxChordNoteSharePercent: 0,
                minBeatsBetweenChords: 0,
                minSameLaneGapMicros: 400_000,
                minCrossLaneGapMicros: 250_000,
                maxSimultaneousContacts: 1,
                shortestHold: BeatFraction(1, 1)
            ),
            medium: ChartRule(
                minAverageMilliNotesPerSecond: 2_000,
                maxAverageMilliNotesPerSecond: 3_500,
                maxPeakMilliNotesPerSecond: 5_000,
                maxChordNoteSharePercent: 5,
                minBeatsBetweenChords: 1,
                minSameLaneGapMicros: 250_000,
                minCrossLaneGapMicros: 150_000,
                maxSimultaneousContacts: 2,
                shortestHold: BeatFraction(1, 2)
            ),
            hard: ChartRule(
                minAverageMilliNotesPerSecond: 3_500,
                maxAverageMilliNotesPerSecond: 5_000,
                maxPeakMilliNotesPerSecond: 7_000,
                maxChordNoteSharePercent: 20,
                minBeatsBetweenChords: 0,
                minSameLaneGapMicros: 180_000,
                minCrossLaneGapMicros: 100_000,
                maxSimultaneousContacts: 2,
                shortestHold: BeatFraction(1, 2)
            ),
            expert: ChartRule(
                minAverageMilliNotesPerSecond: 5_000,
                maxAverageMilliNotesPerSecond: 7_000,
                maxPeakMilliNotesPerSecond: 10_000,
                maxChordNoteSharePercent: 35,
                minBeatsBetweenChords: 0,
                minSameLaneGapMicros: 180_000,
                minCrossLaneGapMicros: 70_000,
                maxSimultaneousContacts: 2,
                shortestHold: BeatFraction(1, 4)
            )
        )
    }

    /// Requirements on song source material (plan 8.2).
    public struct Songs: Codable, Equatable, Sendable {
        /// Shortest song edit, in microseconds: 60 s (plan 8.2).
        public var minDurationMicros: Int64 = 60_000_000

        /// Longest song edit, in microseconds: 90 s (D-062).
        public var maxDurationMicros: Int64 = 90_000_000

        /// How far outside the two limits above the chart validator still accepts a song, in microseconds.
        public var durationToleranceMicros: Int64 = 5_000_000

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
