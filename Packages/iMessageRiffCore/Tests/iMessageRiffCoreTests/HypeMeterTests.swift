import Testing
import iMessageRiffCore

@Suite("Hype meter")
struct HypeMeterTests {
    private func chart(config: GameConfig = .standard) throws -> CompiledChart {
        let ticks = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 23]
        return try EngineTestChart.make(
            notes: ticks.map { Note(tick: $0, lane: 0) },
            hype: [
                HypePhrase(start: 0, end: 4), HypePhrase(start: 4, end: 8),
                HypePhrase(start: 8, end: 24),
            ],
            resolution: 1, config: config)
    }

    @Test("A phrase cannot charge while an earlier member remains unjudged")
    func allMembersRequired() throws {
        var hype = try HypeMeter(chart: chart(), config: .standard, initialTick: 0)
        #expect(try !hype.noteJudged(noteIndex: 0, judgement: .perfect))
        #expect(try !hype.noteJudged(noteIndex: 1, judgement: .great))
        #expect(try !hype.noteJudged(noteIndex: 3, judgement: .perfect))
        #expect(hype.meter == 0)
        #expect(try !hype.noteJudged(noteIndex: 2, judgement: .miss))
        #expect(hype.meter == 0)
    }

    @Test("A phrase completing exactly at expiry extends Hype and invalidates the old expiry")
    func extendAtExpiry() throws {
        var hype = try HypeMeter(chart: chart(), config: .standard, initialTick: 0)
        for index in 0..<8 {
            try hype.advance(toTick: index)
            let charged = try hype.noteJudged(noteIndex: index, judgement: .perfect)
            #expect(charged == (index == 3 || index == 7))
        }
        #expect(hype.meter == 16)
        #expect(try hype.activate())
        #expect(hype.expiryTick == 23)
        for index in 8...10 {
            try hype.advance(toTick: index)
            #expect(try !hype.noteJudged(noteIndex: index, judgement: .perfect))
        }
        try hype.advance(toTick: 23)
        #expect(hype.isActive)
        #expect(hype.meter == 0)
        #expect(try hype.noteJudged(noteIndex: 11, judgement: .perfect))
        #expect(hype.meter == 8)
        #expect(hype.expiryTick == 31)
        #expect(try !hype.expire(expectedTick: 23))
        try hype.advance(toTick: 31)
        #expect(try hype.expire(expectedTick: 31))
        #expect(!hype.isActive)
    }

    @Test("The configured drain rate changes the expiry without floating point")
    func configuredDrain() throws {
        var config = GameConfig.standard
        config.hype.drainPerBeat = 2
        var hype = try HypeMeter(chart: chart(config: config), config: config, initialTick: 0)
        for index in 0..<8 {
            try hype.advance(toTick: index)
            _ = try hype.noteJudged(noteIndex: index, judgement: .perfect)
        }
        #expect(try hype.activate())
        #expect(hype.expiryTick == 15)
        try hype.advance(toTick: 11)
        #expect(hype.meter == 8)
        #expect(throws: HypeMeter.Error.overdueExpiry) { try hype.advance(toTick: 16) }
    }

    @Test("Phrase gains clamp to capacity and activation works at the threshold")
    func chargeCapacity() throws {
        var config = GameConfig.standard
        config.hype.meterCapacity = 10
        config.hype.activationMinimum = 10
        var hype = try HypeMeter(chart: chart(config: config), config: config, initialTick: 0)
        for index in 0..<4 {
            _ = try hype.noteJudged(noteIndex: index, judgement: .perfect)
        }
        #expect(hype.meter == 8)
        #expect(try !hype.activate())
        for index in 4..<8 {
            _ = try hype.noteJudged(noteIndex: index, judgement: .perfect)
        }
        #expect(hype.meter == 10)
        #expect(try hype.activate())
        #expect(hype.expiryTick == 10)
    }

    @Test("Activation below the threshold is ignored and duplicate judgements are rejected")
    func activationAndDuplicates() throws {
        var hype = try HypeMeter(chart: chart(), config: .standard, initialTick: 0)
        #expect(try !hype.activate())
        #expect(try !hype.noteJudged(noteIndex: 0, judgement: .good))
        #expect(throws: HypeMeter.Error.noteAlreadyJudged(0)) {
            try hype.noteJudged(noteIndex: 0, judgement: .perfect)
        }
        #expect(throws: HypeMeter.Error.timeMovedBackwards) { try hype.advance(toTick: -1) }
    }
}
