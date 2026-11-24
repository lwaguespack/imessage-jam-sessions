/// A song's manifest file (CHART_FORMAT section 5).
///
/// Property names are the file's JSON keys. Times are whole milliseconds.
public struct SongManifest: Codable, Equatable, Sendable {
    /// The audio files of a song.
    public struct Stems: Codable, Equatable, Sendable {
        public var backing: String
        public var lead: String

        public init(backing: String, lead: String) {
            self.backing = backing
            self.lead = lead
        }
    }

    /// One value for each part. Version 1 ships the lead part only.
    public struct PerPart<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
        public var lead: Value

        public init(lead: Value) {
            self.lead = lead
        }
    }

    public var id: String
    public var title: String
    public var artist: String
    public var durationMs: Int
    public var previewStartMs: Int
    public var audioOffsetMs: Int
    public var stems: Stems

    /// The chart file for each part and difficulty.
    public var charts: PerPart<PerDifficulty<String>>

    public var intensity: PerPart<PerDifficulty<Int>>
    public var artwork: String
    public var license: String

    public init(
        id: String,
        title: String,
        artist: String,
        durationMs: Int,
        previewStartMs: Int,
        audioOffsetMs: Int,
        stems: Stems,
        charts: PerPart<PerDifficulty<String>>,
        intensity: PerPart<PerDifficulty<Int>>,
        artwork: String,
        license: String
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.durationMs = durationMs
        self.previewStartMs = previewStartMs
        self.audioOffsetMs = audioOffsetMs
        self.stems = stems
        self.charts = charts
        self.intensity = intensity
        self.artwork = artwork
        self.license = license
    }
}
