/// Judges already ordered touch and miss-deadline events against a compiled chart.
///
/// The caller must process every earlier miss deadline before a touch, and all touches at a deadline
/// before that deadline. `GameSession` owns that ordering; the judge does not read a clock.
public struct Judge: Sendable {
    public enum IgnoreReason: Equatable, Sendable {
        case beforeFirstWindow
        case bounce
        case allJudged
    }

    public enum TouchResult: Equatable, Sendable {
        case hit(noteIndex: Int, judgement: Judgement, offsetMicros: Int64)
        case ghost(penalty: GameConfig.GhostTapPenalty)
        case ignored(IgnoreReason)
    }

    public enum Error: Swift.Error, Equatable, Sendable {
        case emptyChart
        case invalidConfiguration
        case invalidLane(Int)
        case invalidNoteIndex(Int)
        case invalidNoteLane(noteIndex: Int, lane: Int)
        case notesNotOrdered(noteIndex: Int)
        case deadlineMismatch(noteIndex: Int)
        case timeOutOfRange
        case timeMovedBackwards
        case overdueMiss(noteIndex: Int)
        case prematureMiss(noteIndex: Int)
        case missOutOfOrder(noteIndex: Int)
    }

    private let notes: [CompiledNote]
    private let indicesByLane: [[Int]]
    private let perfectWindow: Int64
    private let greatWindow: Int64
    private let goodWindow: Int64
    private let firstWindowStart: Int64
    private let bounceGrace: Int64
    private let ghostPenalty: GameConfig.GhostTapPenalty
    private var verdicts: [Judgement?]
    private var laneCursors: [Int]
    private var deadlineCursor = 0
    private var lastHitByLane: [Int64?]
    private var lastEventTime: Int64?

    public private(set) var judgedCount = 0
    public var allJudged: Bool { judgedCount == notes.count }

    public init(chart: CompiledChart, config: GameConfig) throws {
        guard let first = chart.notes.first else { throw Error.emptyChart }
        let laneCount = config.highway.laneCount
        let scale = config.judging.windowScalePercent[chart.difficulty]
        guard laneCount > 0, scale > 0, config.judging.bounceGraceMicros >= 0 else {
            throw Error.invalidConfiguration
        }
        let perfect = try Self.scaledWindow(config.judging.perfect.windowMicros, scale: scale)
        let great = try Self.scaledWindow(config.judging.great.windowMicros, scale: scale)
        let good = try Self.scaledWindow(config.judging.good.windowMicros, scale: scale)
        guard perfect > 0, perfect < great, great < good else { throw Error.invalidConfiguration }

        var lanes = [[Int]](repeating: [], count: laneCount)
        for (index, note) in chart.notes.enumerated() {
            guard (0..<laneCount).contains(note.lane) else {
                throw Error.invalidNoteLane(noteIndex: index, lane: note.lane)
            }
            if index > 0 {
                let previous = chart.notes[index - 1]
                guard (previous.time, previous.lane) < (note.time, note.lane) else {
                    throw Error.notesNotOrdered(noteIndex: index)
                }
            }
            let (deadline, overflow) = note.time.addingReportingOverflow(good)
            guard !overflow, deadline == note.missDeadline else {
                throw Error.deadlineMismatch(noteIndex: index)
            }
            lanes[note.lane].append(index)
        }
        let (windowStart, overflow) = first.time.subtractingReportingOverflow(good)
        guard !overflow else { throw Error.timeOutOfRange }

        notes = chart.notes
        indicesByLane = lanes
        perfectWindow = perfect
        greatWindow = great
        goodWindow = good
        firstWindowStart = windowStart
        bounceGrace = config.judging.bounceGraceMicros
        ghostPenalty = config.judging.ghostTapPenalty[chart.difficulty]
        verdicts = [Judgement?](repeating: nil, count: chart.notes.count)
        laneCursors = [Int](repeating: 0, count: laneCount)
        lastHitByLane = [Int64?](repeating: nil, count: laneCount)
    }

    /// Judges one touch at its effective song time.
    public mutating func touchDown(lane: Int, at time: Int64) throws -> TouchResult {
        guard indicesByLane.indices.contains(lane) else { throw Error.invalidLane(lane) }
        try checkTime(time)
        skipJudgedDeadlines()
        if deadlineCursor < notes.count, notes[deadlineCursor].missDeadline < time {
            throw Error.overdueMiss(noteIndex: deadlineCursor)
        }
        if allJudged {
            lastEventTime = time
            return .ignored(.allJudged)
        }
        if time < firstWindowStart {
            lastEventTime = time
            return .ignored(.beforeFirstWindow)
        }

        skipJudgedNotes(in: lane)
        if laneCursors[lane] < indicesByLane[lane].count {
            let index = indicesByLane[lane][laneCursors[lane]]
            let (offset, overflow) = time.subtractingReportingOverflow(notes[index].time)
            guard !overflow else { throw Error.timeOutOfRange }
            if offset >= -goodWindow && offset <= goodWindow {
                let distance = offset.magnitude
                let judgement: Judgement =
                    distance <= UInt64(perfectWindow)
                    ? .perfect
                    : distance <= UInt64(greatWindow) ? .great : .good
                verdicts[index] = judgement
                judgedCount += 1
                lastHitByLane[lane] = time
                lastEventTime = time
                return .hit(noteIndex: index, judgement: judgement, offsetMicros: offset)
            }
        }

        lastEventTime = time
        if let lastHit = lastHitByLane[lane] {
            let (elapsed, overflow) = time.subtractingReportingOverflow(lastHit)
            if !overflow, elapsed >= 0, elapsed <= bounceGrace {
                return .ignored(.bounce)
            }
        }
        return .ghost(penalty: ghostPenalty)
    }

    /// Processes a note's scheduled miss. Returns false if the note was already hit or missed.
    public mutating func miss(noteIndex: Int, at time: Int64) throws -> Bool {
        guard notes.indices.contains(noteIndex) else { throw Error.invalidNoteIndex(noteIndex) }
        try checkTime(time)
        guard time >= notes[noteIndex].missDeadline else { throw Error.prematureMiss(noteIndex: noteIndex) }
        if verdicts[noteIndex] != nil {
            lastEventTime = time
            return false
        }
        skipJudgedDeadlines()
        guard deadlineCursor == noteIndex else { throw Error.missOutOfOrder(noteIndex: noteIndex) }
        verdicts[noteIndex] = .miss
        judgedCount += 1
        lastEventTime = time
        return true
    }

    public func judgement(ofNoteAt index: Int) throws -> Judgement? {
        guard notes.indices.contains(index) else { throw Error.invalidNoteIndex(index) }
        return verdicts[index]
    }

    private func checkTime(_ time: Int64) throws {
        if let lastEventTime, time < lastEventTime { throw Error.timeMovedBackwards }
    }

    private mutating func skipJudgedDeadlines() {
        while deadlineCursor < notes.count && verdicts[deadlineCursor] != nil {
            deadlineCursor += 1
        }
    }

    private mutating func skipJudgedNotes(in lane: Int) {
        while laneCursors[lane] < indicesByLane[lane].count {
            let index = indicesByLane[lane][laneCursors[lane]]
            guard verdicts[index] != nil else { return }
            laneCursors[lane] += 1
        }
    }

    private static func scaledWindow(_ window: Int64, scale: Int) throws -> Int64 {
        let (scaled, overflow) = window.multipliedReportingOverflow(by: Int64(scale))
        guard !overflow, scaled > 0 else { throw Error.invalidConfiguration }
        return scaled / 100
    }
}
