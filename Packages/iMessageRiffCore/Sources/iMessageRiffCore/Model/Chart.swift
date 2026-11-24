/// One chart file: the note map for one song, part and difficulty (CHART_FORMAT section 1).
///
/// Property names are the file's JSON keys.
public struct Chart: Codable, Equatable, Sendable {
    /// The value of `format` in every chart file.
    public static let formatName = "riff-chart"

    public var format: String

    /// Version of the chart file format.
    public var version: Int

    public var songId: String
    public var part: Part
    public var difficulty: Difficulty
    public var lanes: Int

    /// Ticks per quarter note.
    public var resolution: Int

    public var tempo: [TempoSegment]

    /// For display only; never affects scoring.
    public var timeSignatures: [TimeSignature]

    /// Sorted by tick, then lane.
    public var notes: [Note]

    public var hype: [HypePhrase]

    /// For display only; never affects scoring.
    public var sections: [ChartSection]

    /// Written by `imessageriffcli chart compute`, never by hand.
    public var computed: ChartComputed

    public init(
        format: String = Chart.formatName,
        version: Int = IMessageRiffCoreInfo.chartSchemaVersion,
        songId: String,
        part: Part,
        difficulty: Difficulty,
        lanes: Int,
        resolution: Int,
        tempo: [TempoSegment],
        timeSignatures: [TimeSignature],
        notes: [Note],
        hype: [HypePhrase],
        sections: [ChartSection],
        computed: ChartComputed
    ) {
        self.format = format
        self.version = version
        self.songId = songId
        self.part = part
        self.difficulty = difficulty
        self.lanes = lanes
        self.resolution = resolution
        self.tempo = tempo
        self.timeSignatures = timeSignatures
        self.notes = notes
        self.hype = hype
        self.sections = sections
        self.computed = computed
    }
}

/// A tempo that applies from `tick` onward, in milli-BPM: 128 BPM is 128000.
public struct TempoSegment: Codable, Equatable, Sendable {
    public var tick: Int
    public var mbpm: Int

    public init(tick: Int, mbpm: Int) {
        self.tick = tick
        self.mbpm = mbpm
    }
}

public struct TimeSignature: Codable, Equatable, Sendable {
    public var tick: Int
    public var numerator: Int
    public var denominator: Int

    public init(tick: Int, numerator: Int, denominator: Int) {
        self.tick = tick
        self.numerator = numerator
        self.denominator = denominator
    }

    enum CodingKeys: String, CodingKey {
        case tick
        case numerator = "num"
        case denominator = "den"
    }
}

/// One note. Two notes on one tick form a chord.
public struct Note: Codable, Equatable, Sendable {
    public var tick: Int

    /// 0 to 3 in the file.
    public var lane: Int

    /// Length of a hold, in ticks; nil for a tap.
    public var length: Int?

    public init(tick: Int, lane: Int, length: Int? = nil) {
        self.tick = tick
        self.lane = lane
        self.length = length
    }
}

/// A Hype phrase: the half-open tick range from `start` up to, not including, `end`.
public struct HypePhrase: Codable, Equatable, Sendable {
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

public struct ChartSection: Codable, Equatable, Sendable {
    public var tick: Int
    public var name: String

    public init(tick: Int, name: String) {
        self.tick = tick
        self.name = name
    }
}

/// The values `imessageriffcli chart compute` writes into a chart (CHART_FORMAT section 3).
public struct ChartComputed: Codable, Equatable, Sendable {
    public var rulesVersion: Int

    /// A hold counts once; each note of a chord counts.
    public var noteCount: Int

    public var baseScore: Int
    public var maxScore: Int

    /// Five absolute scores, one per star.
    public var starCutoffs: [Int]

    /// The chart hash, as 8 lowercase hex characters.
    public var hash: String

    public init(
        rulesVersion: Int, noteCount: Int, baseScore: Int, maxScore: Int, starCutoffs: [Int], hash: String
    ) {
        self.rulesVersion = rulesVersion
        self.noteCount = noteCount
        self.baseScore = baseScore
        self.maxScore = maxScore
        self.starCutoffs = starCutoffs
        self.hash = hash
    }
}
