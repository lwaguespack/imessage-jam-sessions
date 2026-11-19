/// Converts between chart ticks and song time, in microseconds, for one chart (GAME_RULES section 1.1).
///
/// The arithmetic is exact and stays inside `Int64` for any chart within the validator's limits.
public struct TempoMap: Equatable, Sendable {
    /// Why a tempo list cannot make a map.
    public enum Invalid: Error, Equatable {
        case noSegments
        case firstSegmentNotAtTickZero

        /// The segment at `index` does not start after the one before it.
        case segmentsNotAscending(index: Int)

        case resolutionNotPositive
        case tempoNotPositive(index: Int)

        /// At the tempo of the segment at `index` a tick lasts under a microsecond, so two ticks could share a time.
        case tickShorterThanOneMicrosecond(index: Int)
    }

    /// One stretch of constant tempo.
    public struct Segment: Equatable, Sendable {
        public let startTick: Int

        /// Song time at `startTick`.
        public let startTime: Int64

        /// Tempo in milli-BPM.
        public let mbpm: Int
    }

    /// Microseconds per minute, times the 1,000 in milli-BPM.
    static let scale: Int64 = 60_000_000_000

    /// Ticks per quarter note.
    public let resolution: Int

    /// In ascending order; the first starts at tick 0 and time 0.
    public let segments: [Segment]

    public init(resolution: Int, tempo: [TempoSegment]) throws {
        guard resolution > 0 else { throw Invalid.resolutionNotPositive }
        guard !tempo.isEmpty else { throw Invalid.noSegments }
        var segments: [Segment] = []
        for (index, entry) in tempo.enumerated() {
            guard entry.mbpm > 0 else { throw Invalid.tempoNotPositive(index: index) }
            guard Int64(entry.mbpm) <= Self.scale / Int64(resolution) else {
                throw Invalid.tickShorterThanOneMicrosecond(index: index)
            }
            var startTime: Int64 = 0
            if let previous = segments.last {
                guard entry.tick > previous.startTick else { throw Invalid.segmentsNotAscending(index: index) }
                let span = Int64(entry.tick - previous.startTick) * Self.scale
                let previousRate = Int64(previous.mbpm) * Int64(resolution)
                startTime = previous.startTime + Self.ceilDivide(span, by: previousRate)
            } else {
                guard entry.tick == 0 else { throw Invalid.firstSegmentNotAtTickZero }
            }
            segments.append(Segment(startTick: entry.tick, startTime: startTime, mbpm: entry.mbpm))
        }
        self.resolution = resolution
        self.segments = segments
    }

    public init(chart: Chart) throws {
        try self.init(resolution: chart.resolution, tempo: chart.tempo)
    }

    /// The song time of a tick, rounded up to a whole microsecond.
    public func time(ofTick tick: Int) -> Int64 {
        let segment = segments.last(where: { $0.startTick <= tick }) ?? segments[0]
        let span = Int64(tick - segment.startTick) * Self.scale
        return segment.startTime + Self.ceilDivide(span, by: rate(of: segment))
    }

    /// The last tick whose time is at or before `time`.
    public func tick(atTime time: Int64) -> Int {
        let segment = segments.last(where: { $0.startTime <= time }) ?? segments[0]
        let ticks = Self.floorDivide((time - segment.startTime) * rate(of: segment), by: Self.scale)
        return segment.startTick + Int(ticks)
    }

    /// Ticks per `scale` microseconds.
    private func rate(of segment: Segment) -> Int64 {
        Int64(segment.mbpm) * Int64(resolution)
    }

    /// The quotient rounded toward minus infinity. `divisor` must be positive.
    private static func floorDivide(_ dividend: Int64, by divisor: Int64) -> Int64 {
        let quotient = dividend / divisor
        return dividend % divisor < 0 ? quotient - 1 : quotient
    }

    /// The quotient rounded toward plus infinity. `divisor` must be positive.
    private static func ceilDivide(_ dividend: Int64, by divisor: Int64) -> Int64 {
        let quotient = dividend / divisor
        return dividend % divisor > 0 ? quotient + 1 : quotient
    }
}
