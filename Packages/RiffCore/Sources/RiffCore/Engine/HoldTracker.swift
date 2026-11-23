/// Tracks hold ownership and sums live tick intervals; the caller applies the current multiplier.
public struct HoldTracker: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidNoteIndex(Int)
        case notAHold(Int)
        case invalidHold(Int)
        case noteAlreadyStarted(Int)
        case touchAlreadyOwnsHold(Int)
        case timeMovedBackwards
        case overdueEnd(Int)
        case prematureEnd(Int)
        case overflow
    }

    public enum StartResult: Equatable, Sendable {
        case started
        case completed
    }

    public enum EndResult: Equatable, Sendable {
        case released(noteIndex: Int)
        case completed(noteIndex: Int)
    }

    private struct Hold: Sendable {
        let noteIndex: Int
        let touchID: Int
        let startTick: Int
        let endTick: Int
    }

    private let notes: [CompiledNote]
    private var started: [Bool]
    private var holds: [Hold] = []
    public private(set) var currentTick: Int
    public var activeCount: Int { holds.count }

    public init(chart: CompiledChart, initialTick: Int) {
        notes = chart.notes
        started = [Bool](repeating: false, count: chart.notes.count)
        currentTick = initialTick
    }

    /// Starts a hold at the current event tick, or completes it immediately if its end has passed.
    public mutating func start(noteIndex: Int, touchID: Int) throws -> StartResult {
        let note = try holdNote(at: noteIndex)
        guard let end = note.endTick, end > note.tick else { throw Error.invalidHold(noteIndex) }
        guard !started[noteIndex] else { throw Error.noteAlreadyStarted(noteIndex) }
        guard !holds.contains(where: { $0.touchID == touchID }) else {
            throw Error.touchAlreadyOwnsHold(touchID)
        }
        started[noteIndex] = true
        if currentTick >= end { return .completed }
        holds.append(
            Hold(noteIndex: noteIndex, touchID: touchID, startTick: max(note.tick, currentTick), endTick: end))
        return .started
    }

    /// Advances to an event tick and returns the sum of hold ticks accrued over the interval.
    public mutating func advance(toTick tick: Int) throws -> Int64 {
        guard tick >= currentTick else { throw Error.timeMovedBackwards }
        if let overdue = holds.first(where: { $0.endTick < tick }) {
            throw Error.overdueEnd(overdue.noteIndex)
        }
        var total: Int64 = 0
        for hold in holds {
            let lower = max(currentTick, hold.startTick)
            let upper = min(tick, hold.endTick)
            if upper > lower {
                let (span, spanOverflow) = upper.subtractingReportingOverflow(lower)
                let (sum, sumOverflow) = total.addingReportingOverflow(Int64(span))
                guard !spanOverflow, !sumOverflow else { throw Error.overflow }
                total = sum
            }
        }
        currentTick = tick
        return total
    }

    /// A release for a touch that owns no hold is an ordinary tap release and returns nil.
    public mutating func release(touchID: Int) throws -> EndResult? {
        guard let index = holds.firstIndex(where: { $0.touchID == touchID }) else { return nil }
        let hold = holds.remove(at: index)
        return currentTick >= hold.endTick
            ? .completed(noteIndex: hold.noteIndex) : .released(noteIndex: hold.noteIndex)
    }

    /// A scheduled end after an earlier release is stale and returns nil.
    public mutating func complete(noteIndex: Int) throws -> EndResult? {
        let note = try holdNote(at: noteIndex)
        guard let end = note.endTick, end > note.tick else { throw Error.invalidHold(noteIndex) }
        guard currentTick >= end else { throw Error.prematureEnd(noteIndex) }
        guard let index = holds.firstIndex(where: { $0.noteIndex == noteIndex }) else { return nil }
        holds.remove(at: index)
        return .completed(noteIndex: noteIndex)
    }

    private func holdNote(at index: Int) throws -> CompiledNote {
        guard notes.indices.contains(index) else { throw Error.invalidNoteIndex(index) }
        let note = notes[index]
        guard note.endTick != nil else { throw Error.notAHold(index) }
        return note
    }
}
