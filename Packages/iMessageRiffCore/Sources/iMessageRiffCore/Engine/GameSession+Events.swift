extension GameSession {
    mutating func process(_ next: NextEvent) throws {
        switch next {
        case .input(let input):
            try processInput(input.event)
        case .scheduled(let event):
            try processScheduled(event)
        }
    }

    private mutating func processInput(_ event: InputEvent) throws {
        switch event {
        case .touchDown(let id, let lane, let time):
            guard !activeTouches.contains(where: { $0.id == id }) else {
                output.append(.inputRejected(time: time, touchID: id, reason: .touchAlreadyDown))
                return
            }
            let result = try judge.touchDown(lane: lane, at: time)
            activeTouches.append(ActiveTouch(id: id, lane: lane))
            switch result {
            case .hit(let index, let judgement, let offset):
                let oldStreak = scoring.streak
                let oldMultiplier = try multiplier()
                let oldPoints = scoring.notePoints
                try scoring.hit(judgement, hypeActive: hype.isActive)
                output.append(
                    .hit(
                        time: time, noteIndex: index, judgement: judgement, offsetMicros: offset,
                        points: scoring.notePoints - oldPoints))
                try emitChanges(at: time, oldStreak: oldStreak, oldMultiplier: oldMultiplier)
                if chart.notes[index].endTick != nil {
                    let start = try holds.start(noteIndex: index, touchID: id)
                    output.append(.holdStarted(time: time, noteIndex: index, touchID: id))
                    if start == .completed {
                        output.append(.holdCompleted(time: time, noteIndex: index))
                    } else {
                        guard let endTime = chart.notes[index].endTime else { throw Error.invalidChart }
                        try schedule(
                            time: endTime, priority: 4, lane: lane, tie: index,
                            kind: .holdEnd(noteIndex: index))
                    }
                }
                if try hype.noteJudged(noteIndex: index, judgement: judgement) {
                    output.append(.hypeCharged(time: time, meter: hype.meter))
                    if hype.isActive { try scheduleHypeExpiry() }
                }
            case .ghost(let penalty):
                let oldStreak = scoring.streak
                let oldMultiplier = try multiplier()
                try scoring.ghost()
                output.append(.ghostTap(time: time, lane: lane, penalty: penalty))
                try emitChanges(at: time, oldStreak: oldStreak, oldMultiplier: oldMultiplier)
            case .ignored:
                break
            }

        case .touchUp(let id, let time):
            guard let index = activeTouches.firstIndex(where: { $0.id == id }) else {
                output.append(.inputRejected(time: time, touchID: id, reason: .unknownTouch))
                return
            }
            activeTouches.remove(at: index)
            if let result = try holds.release(touchID: id) { emitHoldEnd(result, at: time) }

        case .activateHype(let time):
            let oldMultiplier = try multiplier()
            if try hype.activate() {
                let (count, overflow) = hypeActivations.addingReportingOverflow(1)
                guard !overflow, let expiry = hype.expiryTick else { throw Error.overflow }
                hypeActivations = count
                output.append(.hypeActivated(time: time, expiryTick: expiry))
                try emitChanges(at: time, oldStreak: scoring.streak, oldMultiplier: oldMultiplier)
                try scheduleHypeExpiry()
            }
        }
    }

    private mutating func processScheduled(_ event: Scheduled) throws {
        switch event.kind {
        case .miss(let index):
            if try judge.miss(noteIndex: index, at: event.time) {
                let oldStreak = scoring.streak
                let oldMultiplier = try multiplier()
                try scoring.miss()
                output.append(.miss(time: event.time, noteIndex: index))
                try emitChanges(at: event.time, oldStreak: oldStreak, oldMultiplier: oldMultiplier)
                _ = try hype.noteJudged(noteIndex: index, judgement: .miss)
            }

        case .holdEnd(let index):
            if let result = try holds.complete(noteIndex: index) {
                emitHoldEnd(result, at: event.time)
            }

        case .hypeExpiry(let tick):
            let oldMultiplier = try multiplier()
            if try hype.expire(expectedTick: tick) {
                output.append(.hypeExpired(time: event.time))
                try emitChanges(at: event.time, oldStreak: scoring.streak, oldMultiplier: oldMultiplier)
            }

        case .pauseBegin:
            for touch in activeTouches.sorted(by: { $0.id < $1.id }) {
                let hasRelease = queued.contains { input in
                    if case .touchUp(let id, let time) = input.event {
                        return id == touch.id && time == event.time
                    }
                    return false
                }
                if !hasRelease {
                    let release = InputEvent.touchUp(id: touch.id, time: event.time)
                    try enqueue(
                        RunLog.RecordedInput(
                            event: release, originalTime: event.time, wasLate: false, synthetic: true))
                }
            }

        case .pauseEnd:
            state = .paused
        }
    }

    private mutating func scheduleHypeExpiry() throws {
        guard let tick = hype.expiryTick else { throw Error.invalidChart }
        let time = try Self.safeTime(ofTick: tick, map: chart.tempoMap)
        try schedule(time: time, priority: 6, lane: 0, tie: tick, kind: .hypeExpiry(tick: tick))
    }

    private func multiplier() throws -> Int64 {
        let hypeMultiplier = hype.isActive ? Int64(config.hype.multiplier) : 1
        let (value, overflow) = Int64(scoring.streakMultiplier).multipliedReportingOverflow(by: hypeMultiplier)
        guard !overflow else { throw Error.overflow }
        return value
    }

    private mutating func emitChanges(at time: Int64, oldStreak: Int, oldMultiplier: Int64) throws {
        if scoring.streak != oldStreak {
            output.append(.streakChanged(time: time, streak: scoring.streak))
        }
        let newMultiplier = try multiplier()
        if newMultiplier != oldMultiplier {
            output.append(.multiplierChanged(time: time, multiplier: newMultiplier))
        }
    }

    private mutating func emitHoldEnd(_ result: HoldTracker.EndResult, at time: Int64) {
        switch result {
        case .released(let index): output.append(.holdReleased(time: time, noteIndex: index))
        case .completed(let index): output.append(.holdCompleted(time: time, noteIndex: index))
        }
    }
}
