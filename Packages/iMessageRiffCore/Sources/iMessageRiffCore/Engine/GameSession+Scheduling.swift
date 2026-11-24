extension GameSession {
    struct ActiveTouch: Sendable {
        let id: Int
        let lane: Int
    }

    struct QueuedInput: Sendable {
        let event: InputEvent
        let sequence: Int
    }

    enum ScheduledKind: Sendable {
        case miss(noteIndex: Int)
        case holdEnd(noteIndex: Int)
        case hypeExpiry(tick: Int)
        case pauseBegin
        case pauseEnd
    }

    struct Scheduled: Sendable {
        let time: Int64
        let priority: Int
        let lane: Int
        let tie: Int
        let sequence: Int
        let kind: ScheduledKind
    }

    struct EventKey: Comparable {
        let time: Int64
        let priority: Int
        let lane: Int
        let tie: Int
        let sequence: Int

        static func < (left: EventKey, right: EventKey) -> Bool {
            (left.time, left.priority, left.lane, left.tie, left.sequence)
                < (right.time, right.priority, right.lane, right.tie, right.sequence)
        }
    }

    enum NextEvent {
        case input(QueuedInput)
        case scheduled(Scheduled)

        var time: Int64 {
            switch self {
            case .input(let input): input.event.time
            case .scheduled(let event): event.time
            }
        }
    }

    mutating func enqueue(_ input: RunLog.RecordedInput) throws {
        let sequence = try takeSequence()
        let count: Int
        if input.wasLate {
            let (next, overflow) = lateInputCount.addingReportingOverflow(1)
            guard !overflow else { throw Error.overflow }
            count = next
        } else {
            count = lateInputCount
        }
        queued.append(QueuedInput(event: input.event, sequence: sequence))
        runLog.inputs.append(input)
        lateInputCount = count
    }

    mutating func schedule(
        time: Int64, priority: Int, lane: Int, tie: Int, kind: ScheduledKind
    ) throws {
        guard (-Self.timeLimitMicros...Self.timeLimitMicros).contains(time) else {
            throw Error.timeOutOfRange
        }
        let sequence = try takeSequence()
        scheduled.append(
            Scheduled(
                time: time, priority: priority, lane: lane, tie: tie,
                sequence: sequence, kind: kind))
    }

    mutating func nextEvent(through time: Int64) -> NextEvent? {
        var best: (key: EventKey, input: Bool, index: Int)?
        for (index, input) in queued.enumerated() where input.event.time <= time {
            let key = inputKey(input)
            if let current = best {
                if key < current.key { best = (key, true, index) }
            } else {
                best = (key, true, index)
            }
        }
        for (index, event) in scheduled.enumerated() where event.time <= time {
            let key = EventKey(
                time: event.time, priority: event.priority, lane: event.lane, tie: event.tie,
                sequence: event.sequence)
            if let current = best {
                if key < current.key { best = (key, false, index) }
            } else {
                best = (key, false, index)
            }
        }
        guard let best else { return nil }
        if best.input { return .input(queued.remove(at: best.index)) }
        return .scheduled(scheduled.remove(at: best.index))
    }

    func inputKey(_ input: QueuedInput) -> EventKey {
        switch input.event {
        case .activateHype(let time):
            EventKey(time: time, priority: 0, lane: 0, tie: 0, sequence: input.sequence)
        case .touchDown(let id, let lane, let time):
            EventKey(time: time, priority: 1, lane: lane, tie: id, sequence: input.sequence)
        case .touchUp(let id, let time):
            EventKey(time: time, priority: 3, lane: 0, tie: id, sequence: input.sequence)
        }
    }

    mutating func advanceComponents(to time: Int64) throws {
        let tick = try Self.safeTick(at: time, map: chart.tempoMap)
        let holdTicks = try holds.advance(toTick: tick)
        try scoring.addSustain(ticks: holdTicks, hypeActive: hype.isActive)
        try hype.advance(toTick: tick)
    }

    mutating func takeSequence() throws -> Int {
        let sequence = nextSequence
        let (next, overflow) = sequence.addingReportingOverflow(1)
        guard !overflow else { throw Error.overflow }
        nextSequence = next
        return sequence
    }

    static func safeTick(at time: Int64, map: TempoMap) throws -> Int {
        guard (-timeLimitMicros...timeLimitMicros).contains(time) else { throw Error.timeOutOfRange }
        let segment = map.segments.last(where: { $0.startTime <= time }) ?? map.segments[0]
        let (delta, deltaOverflow) = time.subtractingReportingOverflow(segment.startTime)
        let (rate, rateOverflow) = Int64(segment.mbpm).multipliedReportingOverflow(by: Int64(map.resolution))
        let (product, productOverflow) = delta.multipliedReportingOverflow(by: rate)
        guard !deltaOverflow, !rateOverflow, !productOverflow else { throw Error.overflow }
        let scale: Int64 = 60_000_000_000
        let quotient = product / scale - (product % scale < 0 ? 1 : 0)
        let (_, sumOverflow) = Int64(segment.startTick).addingReportingOverflow(quotient)
        guard !sumOverflow else { throw Error.overflow }
        return map.tick(atTime: time)
    }

    static func safeTime(ofTick tick: Int, map: TempoMap) throws -> Int64 {
        let segment = map.segments.last(where: { $0.startTick <= tick }) ?? map.segments[0]
        let (delta, deltaOverflow) = tick.subtractingReportingOverflow(segment.startTick)
        let (span, spanOverflow) = Int64(delta).multipliedReportingOverflow(by: 60_000_000_000)
        let (rate, rateOverflow) = Int64(segment.mbpm).multipliedReportingOverflow(by: Int64(map.resolution))
        guard !deltaOverflow, !spanOverflow, !rateOverflow, rate > 0 else { throw Error.overflow }
        let quotient = span / rate + (span % rate > 0 ? 1 : 0)
        let (time, sumOverflow) = segment.startTime.addingReportingOverflow(quotient)
        guard !sumOverflow, (-timeLimitMicros...timeLimitMicros).contains(time) else {
            throw Error.timeOutOfRange
        }
        return map.time(ofTick: tick)
    }
}
