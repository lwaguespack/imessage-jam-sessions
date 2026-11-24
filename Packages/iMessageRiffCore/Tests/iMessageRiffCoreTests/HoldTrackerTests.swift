import Testing
import iMessageRiffCore

@Suite("Hold tracker")
struct HoldTrackerTests {
    @Test("A head hit early and released before the head accrues no sustain")
    func earlyRelease() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 100, lane: 0, length: 100)])
        var holds = HoldTracker(chart: chart, initialTick: 90)
        #expect(try holds.start(noteIndex: 0, touchID: 1) == .started)
        #expect(try holds.advance(toTick: 99) == 0)
        #expect(try holds.release(touchID: 1) == .released(noteIndex: 0))
        #expect(try holds.advance(toTick: 200) == 0)
        #expect(try holds.complete(noteIndex: 0) == nil)
        #expect(throws: HoldTracker.Error.noteAlreadyStarted(0)) {
            try holds.start(noteIndex: 0, touchID: 2)
        }
    }

    @Test("A late head starts sustain at its hit tick and cannot be re-pressed")
    func lateHead() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 100, lane: 0, length: 100)])
        var holds = HoldTracker(chart: chart, initialTick: 110)
        #expect(try holds.start(noteIndex: 0, touchID: 7) == .started)
        #expect(try holds.advance(toTick: 150) == 40)
        #expect(try holds.release(touchID: 7) == .released(noteIndex: 0))
        #expect(try holds.release(touchID: 7) == nil)
        #expect(try holds.advance(toTick: 200) == 0)
    }

    @Test("Release exactly at the end completes once")
    func releaseAtEnd() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 100, lane: 0, length: 100)])
        var holds = HoldTracker(chart: chart, initialTick: 100)
        #expect(try holds.start(noteIndex: 0, touchID: 1) == .started)
        #expect(try holds.advance(toTick: 200) == 100)
        #expect(try holds.release(touchID: 1) == .completed(noteIndex: 0))
        #expect(try holds.complete(noteIndex: 0) == nil)
    }

    @Test("An end must be processed before advancing beyond it")
    func overdueEnd() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 100, lane: 0, length: 100)])
        var holds = HoldTracker(chart: chart, initialTick: 100)
        #expect(try holds.start(noteIndex: 0, touchID: 1) == .started)
        #expect(throws: HoldTracker.Error.overdueEnd(0)) { try holds.advance(toTick: 201) }
        #expect(try holds.advance(toTick: 200) == 100)
        #expect(try holds.complete(noteIndex: 0) == .completed(noteIndex: 0))
    }

    @Test("Overlapping holds contribute separately to the shared sustain accumulator")
    func overlappingHolds() throws {
        let chart = try EngineTestChart.make(notes: [
            Note(tick: 192, lane: 0, length: 384), Note(tick: 240, lane: 1, length: 192),
        ])
        var holds = HoldTracker(chart: chart, initialTick: 192)
        #expect(try holds.start(noteIndex: 0, touchID: 1) == .started)
        #expect(try holds.advance(toTick: 240) == 48)
        #expect(try holds.start(noteIndex: 1, touchID: 2) == .started)
        #expect(try holds.advance(toTick: 432) == 384)
        #expect(try holds.complete(noteIndex: 1) == .completed(noteIndex: 1))
        #expect(try holds.advance(toTick: 576) == 144)
        #expect(try holds.complete(noteIndex: 0) == .completed(noteIndex: 0))
        #expect(holds.activeCount == 0)
    }

    @Test("Invalid holds, duplicate owners and backwards advancement are rejected")
    func invalidOperations() throws {
        let chart = try EngineTestChart.make(notes: [
            Note(tick: 100, lane: 0, length: 100), Note(tick: 120, lane: 1, length: 100),
            Note(tick: 200, lane: 2),
        ])
        var holds = HoldTracker(chart: chart, initialTick: 100)
        #expect(throws: HoldTracker.Error.notAHold(2)) { try holds.start(noteIndex: 2, touchID: 1) }
        #expect(try holds.start(noteIndex: 0, touchID: 1) == .started)
        #expect(throws: HoldTracker.Error.touchAlreadyOwnsHold(1)) {
            try holds.start(noteIndex: 1, touchID: 1)
        }
        #expect(throws: HoldTracker.Error.timeMovedBackwards) { try holds.advance(toTick: 99) }
        #expect(throws: HoldTracker.Error.prematureEnd(0)) { try holds.complete(noteIndex: 0) }
    }
}
