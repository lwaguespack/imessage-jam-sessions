/// A replay records effective inputs as well as their original timestamps and late-input status.
public struct RunLog: Codable, Equatable, Sendable {
    public struct RecordedInput: Codable, Equatable, Sendable {
        public let event: InputEvent
        public let originalTime: Int64
        public let wasLate: Bool
        public let synthetic: Bool

        public init(event: InputEvent, originalTime: Int64, wasLate: Bool, synthetic: Bool) {
            self.event = event
            self.originalTime = originalTime
            self.wasLate = wasLate
            self.synthetic = synthetic
        }
    }

    public let chartHash: String
    public let rulesVersion: Int
    public let difficulty: Difficulty
    public let scrollTimeMicros: Int64
    public internal(set) var inputs: [RecordedInput]
    public internal(set) var finishedAt: Int64?

    public init(
        chartHash: String, rulesVersion: Int, difficulty: Difficulty,
        scrollTimeMicros: Int64, inputs: [RecordedInput] = [], finishedAt: Int64? = nil
    ) {
        self.chartHash = chartHash
        self.rulesVersion = rulesVersion
        self.difficulty = difficulty
        self.scrollTimeMicros = scrollTimeMicros
        self.inputs = inputs
        self.finishedAt = finishedAt
    }
}
