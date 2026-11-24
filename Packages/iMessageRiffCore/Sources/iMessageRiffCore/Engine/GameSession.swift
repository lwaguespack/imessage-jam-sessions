/// A deterministic run. Inputs are queued until an inclusive song-time watermark commits them.
public struct GameSession: Sendable {
    public enum State: Equatable, Sendable {
        case ready
        case leadIn
        case playing
        case paused
        case finished
    }

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidState
        case invalidChart
        case invalidChartHash
        case invalidScrollTime
        case invalidLane(Int)
        case timeOutOfRange
        case watermarkMovedBackwards
        case pauseAtCommittedTime
        case pendingInputAfterPause
        case replayMismatch
        case incompleteReplay
        case invalidReplayInput
        case overflow
    }

    static let timeLimitMicros: Int64 = 28_800_000_000

    let chart: CompiledChart
    let config: GameConfig
    var judge: Judge
    var holds: HoldTracker
    var hype: HypeMeter
    var queued: [QueuedInput] = []
    var scheduled: [Scheduled] = []
    var activeTouches: [ActiveTouch] = []
    var output: [OutputEvent] = []
    var nextSequence: Int

    public let startTime: Int64
    public internal(set) var watermark: Int64
    public internal(set) var state: State = .ready
    public internal(set) var scoring: ScoreKeeper
    public internal(set) var runLog: RunLog
    public internal(set) var lateInputCount = 0
    public internal(set) var hypeActivations = 0

    public var activeHoldCount: Int { holds.activeCount }
    public var hypeActive: Bool { hype.isActive }
    public var hypeMeter: Int64 { hype.meter }

    public init(
        chart: CompiledChart, config: GameConfig, chartHash: String, scrollTimeMicros: Int64? = nil
    ) throws {
        let hashLength = config.payload.chartHashBytes.multipliedReportingOverflow(by: 2)
        guard !hashLength.overflow, hashLength.partialValue > 0,
            chartHash.utf8.count == hashLength.partialValue,
            chartHash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { throw Error.invalidChartHash }
        guard
            chart.notes.allSatisfy({ note in
                guard note.tick >= 0, note.time >= 0, note.missDeadline <= Self.timeLimitMicros else {
                    return false
                }
                switch (note.endTick, note.endTime) {
                case (nil, nil): return true
                case (let endTick?, let endTime?):
                    return endTick > note.tick && endTime > note.time && endTime <= Self.timeLimitMicros
                default: return false
                }
            })
        else { throw Error.invalidChart }

        let scroll = scrollTimeMicros ?? config.highway.scrollTimeMicros[chart.difficulty]
        guard config.highway.minScrollTimeMicros <= scroll, scroll <= config.highway.maxScrollTimeMicros
        else { throw Error.invalidScrollTime }
        let start = try Self.leadIn(chart: chart, config: config, scroll: scroll)
        let initialWatermark = start - 1
        let initialTick = try Self.safeTick(at: initialWatermark, map: chart.tempoMap)

        self.chart = chart
        self.config = config
        judge = try Judge(chart: chart, config: config)
        scoring = try ScoreKeeper(config: config, difficulty: chart.difficulty, resolution: chart.tempoMap.resolution)
        holds = HoldTracker(chart: chart, initialTick: initialTick)
        hype = try HypeMeter(chart: chart, config: config, initialTick: initialTick)
        startTime = start
        watermark = initialWatermark
        runLog = RunLog(
            chartHash: chartHash, rulesVersion: config.rulesVersion, difficulty: chart.difficulty,
            scrollTimeMicros: scroll)
        scheduled = chart.notes.enumerated().map { index, note in
            Scheduled(
                time: note.missDeadline, priority: 5, lane: note.lane, tie: index, sequence: index,
                kind: .miss(noteIndex: index))
        }
        nextSequence = chart.notes.count
    }

    public mutating func start() throws {
        guard state == .ready else { throw Error.invalidState }
        state = startTime < 0 ? .leadIn : .playing
    }

    /// Queues an input. An input at or before the watermark is moved to the first uncommitted microsecond.
    public mutating func apply(_ event: InputEvent) throws {
        guard state == .leadIn || state == .playing else { throw Error.invalidState }
        try validate(event)
        let late = event.time <= watermark
        let effective: InputEvent
        if late {
            let (time, overflow) = watermark.addingReportingOverflow(1)
            guard !overflow, time <= Self.timeLimitMicros else { throw Error.timeOutOfRange }
            effective = event.at(time)
        } else {
            effective = event
        }
        try enqueue(
            RunLog.RecordedInput(
                event: effective, originalTime: event.time, wasLate: late, synthetic: false))
    }

    /// Processes every queued input and scheduled event at or before `time`.
    public mutating func advance(to time: Int64) throws {
        guard state == .leadIn || state == .playing else { throw Error.invalidState }
        guard (-Self.timeLimitMicros...Self.timeLimitMicros).contains(time) else {
            throw Error.timeOutOfRange
        }
        guard time >= watermark else { throw Error.watermarkMovedBackwards }
        while let next = nextEvent(through: time) {
            try advanceComponents(to: next.time)
            if state == .leadIn, next.time >= 0 { state = .playing }
            try process(next)
            if judge.allJudged && holds.activeCount == 0 {
                let score = try scoring.totalScore()
                watermark = next.time
                state = .finished
                runLog.finishedAt = next.time
                output.append(.runFinished(time: next.time, score: score))
                queued.removeAll()
                scheduled.removeAll()
                return
            }
            if state == .paused {
                watermark = next.time
                return
            }
        }
        try advanceComponents(to: time)
        watermark = time
        if state == .leadIn, time >= 0 { state = .playing }
    }

    /// Releases all touches at the pause time, after same-time touch-downs and before hold ends.
    public mutating func pause(at time: Int64) throws {
        guard state == .leadIn || state == .playing else { throw Error.invalidState }
        guard (-Self.timeLimitMicros...Self.timeLimitMicros).contains(time) else {
            throw Error.timeOutOfRange
        }
        guard time > watermark else { throw Error.pauseAtCommittedTime }
        guard !queued.contains(where: { $0.event.time > time }) else { throw Error.pendingInputAfterPause }
        try schedule(time: time, priority: 2, lane: 0, tie: 0, kind: .pauseBegin)
        try schedule(time: time, priority: 7, lane: 0, tie: 0, kind: .pauseEnd)
        try advance(to: time)
    }

    public mutating func resume() throws {
        guard state == .paused else { throw Error.invalidState }
        state = watermark < 0 ? .leadIn : .playing
    }

    public mutating func drainOutput() -> [OutputEvent] {
        let events = output
        output.removeAll(keepingCapacity: true)
        return events
    }

    /// Replays effective inputs, including synthetic pause releases and recorded late-input counts.
    public static func replay(
        _ log: RunLog, chart: CompiledChart, config: GameConfig, chartHash: String
    ) throws -> GameSession {
        guard log.chartHash == chartHash, log.rulesVersion == config.rulesVersion,
            log.difficulty == chart.difficulty
        else { throw Error.replayMismatch }
        guard let finishedAt = log.finishedAt else { throw Error.incompleteReplay }
        var session = try GameSession(
            chart: chart, config: config, chartHash: chartHash, scrollTimeMicros: log.scrollTimeMicros)
        try session.start()
        for input in log.inputs {
            try session.validate(input.event)
            guard input.event.time > session.watermark,
                (-Self.timeLimitMicros...Self.timeLimitMicros).contains(input.originalTime),
                input.wasLate ? input.originalTime < input.event.time : input.originalTime == input.event.time
            else { throw Error.invalidReplayInput }
            if input.synthetic {
                guard !input.wasLate, case .touchUp = input.event else { throw Error.invalidReplayInput }
            }
            try session.enqueue(input)
        }
        try session.advance(to: finishedAt)
        guard session.state == .finished, session.watermark == finishedAt else {
            throw Error.invalidReplayInput
        }
        return session
    }

    func validate(_ event: InputEvent) throws {
        guard (-Self.timeLimitMicros...Self.timeLimitMicros).contains(event.time) else {
            throw Error.timeOutOfRange
        }
        if case .touchDown(_, let lane, _) = event, !(0..<config.highway.laneCount).contains(lane) {
            throw Error.invalidLane(lane)
        }
    }

    private static func leadIn(chart: CompiledChart, config: GameConfig, scroll: Int64) throws -> Int64 {
        guard let first = chart.notes.first, let tempo = chart.tempoMap.segments.first,
            config.playback.minLeadInMicros >= 0, config.playback.startCountdownBeats >= 0,
            config.playback.inputGuardMicros >= 0
        else { throw Error.invalidChart }
        let (approach, subtractOverflow) = scroll.subtractingReportingOverflow(first.time)
        guard !subtractOverflow else { throw Error.overflow }
        let required = max(config.playback.minLeadInMicros, approach)
        let (numerator, multiplyOverflow) = required.multipliedReportingOverflow(by: Int64(tempo.mbpm))
        guard !multiplyOverflow else { throw Error.overflow }
        let scale: Int64 = 60_000_000_000
        let beats = numerator / scale + (numerator.isMultiple(of: scale) ? 0 : 1)
        let count = max(beats, Int64(config.playback.startCountdownBeats))
        let (ticks, tickOverflow) = count.multipliedReportingOverflow(by: Int64(chart.tempoMap.resolution))
        guard !tickOverflow, let tick = Int(exactly: -ticks) else { throw Error.overflow }
        return try safeTime(ofTick: tick, map: chart.tempoMap)
    }
}
