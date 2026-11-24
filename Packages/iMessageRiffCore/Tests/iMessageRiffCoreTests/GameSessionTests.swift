import Foundation
import Testing
import iMessageRiffCore

@Suite("Game session")
struct GameSessionTests {
    private func session(
        _ notes: [Note], hype: [HypePhrase] = [], config: GameConfig = .standard
    ) throws -> GameSession {
        let compiled = try EngineTestChart.make(notes: notes, hype: hype, config: config)
        var session = try GameSession(chart: compiled, config: config, chartHash: "deadbeef")
        try session.start()
        return session
    }

    @Test("An input at the exact Good deadline precedes its miss")
    func deadlineTie() throws {
        var game = try session([Note(tick: 384, lane: 0)])
        try game.apply(.touchDown(id: 1, lane: 0, time: 1_130_000))
        try game.advance(to: 1_130_000)
        #expect(game.state == .finished)
        #expect(try game.scoring.totalScore() == 50)
        #expect(
            game.drainOutput().contains(
                .hit(time: 1_130_000, noteIndex: 0, judgement: .good, offsetMicros: 130_000, points: 50)))
    }

    @Test("Tied input is ordered by lane rather than arrival order")
    func tiedInputs() throws {
        var config = GameConfig.standard
        config.scoring.streakPerMultiplierStep.expert = 1
        let notes = [Note(tick: 384, lane: 0), Note(tick: 411, lane: 1)]
        var game = try session(notes, config: config)
        try game.apply(.touchDown(id: 2, lane: 1, time: 1_000_000))
        try game.apply(.touchDown(id: 1, lane: 0, time: 1_000_000))
        try game.advance(to: 1_000_000)
        #expect(try game.scoring.totalScore() == 260)
        let hits = game.drainOutput().compactMap { event -> Int? in
            if case .hit(_, let index, _, _, _) = event { return index }
            return nil
        }
        #expect(hits == [0, 1])
    }

    @Test("A late touch is clamped after the watermark and the log replays it exactly")
    func lateInputAndReplay() throws {
        let notes = [Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)]
        let compiled = try EngineTestChart.make(notes: notes)
        var game = try GameSession(chart: compiled, config: .standard, chartHash: "deadbeef")
        try game.start()
        try game.advance(to: 1_130_000)
        try game.apply(.touchDown(id: 1, lane: 3, time: 1_130_000))
        #expect(game.lateInputCount == 1)
        #expect(game.runLog.inputs.last?.event.time == 1_130_001)
        try game.advance(to: 1_130_001)
        try game.apply(.touchUp(id: 1, time: 1_140_000))
        try game.apply(.touchDown(id: 2, lane: 1, time: 2_000_000))
        try game.advance(to: 2_000_000)
        #expect(game.state == .finished)
        #expect(game.scoring.missCount == 1)
        #expect(game.scoring.ghostTapCount == 1)
        let output = game.drainOutput()

        let data = try JSONEncoder().encode(game.runLog)
        let decoded = try JSONDecoder().decode(RunLog.self, from: data)
        #expect(decoded == game.runLog)
        var replay = try GameSession.replay(
            decoded, chart: compiled, config: .standard, chartHash: "deadbeef")
        #expect(replay.state == .finished)
        #expect(replay.lateInputCount == 1)
        #expect(try replay.scoring.totalScore() == game.scoring.totalScore())
        #expect(replay.drainOutput() == output)
    }

    @Test("Pause releases holds at the pause tick and freezes the engine")
    func pauseReleasesHolds() throws {
        let compiled = try EngineTestChart.make(
            notes: [Note(tick: 192, lane: 0, length: 384), Note(tick: 1_000, lane: 1)])
        var game = try GameSession(chart: compiled, config: .standard, chartHash: "deadbeef")
        try game.start()
        try game.apply(.touchDown(id: 1, lane: 0, time: 500_000))
        try game.advance(to: 500_000)
        try game.pause(at: 750_000)
        #expect(game.state == .paused)
        #expect(game.activeHoldCount == 0)
        #expect(try game.scoring.totalScore() == 112)
        let beforeResume = game.drainOutput()
        #expect(beforeResume.contains(.holdReleased(time: 750_000, noteIndex: 0)))
        #expect(throws: GameSession.Error.invalidState) { try game.advance(to: 800_000) }
        #expect(game.runLog.inputs.contains { $0.synthetic && $0.event == .touchUp(id: 1, time: 750_000) })
        try game.resume()
        #expect(game.state == .playing)
        try game.apply(.touchDown(id: 2, lane: 1, time: compiled.notes[1].time))
        try game.advance(to: compiled.notes[1].time)
        let expected = beforeResume + game.drainOutput()
        var replay = try GameSession.replay(
            game.runLog, chart: compiled, config: .standard, chartHash: "deadbeef")
        #expect(replay.drainOutput() == expected)
        #expect(try replay.scoring.totalScore() == 212)
    }

    @Test("Pausing exactly at the end completes a hold once")
    func pauseAtHoldEnd() throws {
        var game = try session([Note(tick: 192, lane: 0, length: 384), Note(tick: 1_000, lane: 1)])
        try game.apply(.touchDown(id: 1, lane: 0, time: 500_000))
        try game.advance(to: 500_000)
        try game.pause(at: 1_500_000)
        let events = game.drainOutput()
        #expect(events.filter { $0 == .holdCompleted(time: 1_500_000, noteIndex: 0) }.count == 1)
        #expect(!events.contains(.holdReleased(time: 1_500_000, noteIndex: 0)))
        #expect(try game.scoring.totalScore() == 150)
    }

    @Test("A note exactly at Hype expiry scores doubled before expiry")
    func touchAtHypeExpiry() throws {
        var config = GameConfig.standard
        config.hype.activationMinimum = 8
        config.hype.drainPerBeat = 32
        let notes = [
            Note(tick: 192, lane: 0), Note(tick: 216, lane: 1), Note(tick: 240, lane: 2),
            Note(tick: 264, lane: 3), Note(tick: 316, lane: 1), Note(tick: 384, lane: 0),
        ]
        let compiled = try EngineTestChart.make(
            notes: notes, hype: [HypePhrase(start: 192, end: 265)], config: config)
        var game = try GameSession(chart: compiled, config: config, chartHash: "deadbeef")
        try game.start()
        for (index, note) in compiled.notes.enumerated() {
            try game.apply(.touchDown(id: index, lane: note.lane, time: note.time))
            try game.apply(.touchUp(id: index, time: note.time + 1))
        }
        let activationTime = compiled.tempoMap.time(ofTick: 268)
        let expiryTime = compiled.tempoMap.time(ofTick: 316)
        try game.apply(.activateHype(time: activationTime))
        try game.advance(to: expiryTime)
        let first = game.drainOutput()
        let hitIndex = try #require(
            first.firstIndex {
                if case .hit(_, 4, _, _, _) = $0 { return true }
                return false
            })
        let expiryIndex = try #require(first.firstIndex(of: .hypeExpired(time: expiryTime)))
        #expect(hitIndex < expiryIndex)
        #expect(
            first.contains(
                .hit(time: expiryTime, noteIndex: 4, judgement: .perfect, offsetMicros: 0, points: 200)))
        try game.advance(to: 1_000_000)
        #expect(try game.scoring.totalScore() == 700)
    }

    @Test("Slow songs still get a full three-beat countdown")
    func slowLeadIn() throws {
        var raw = ExampleChart.make()
        raw.notes = [Note(tick: 0, lane: 0)]
        raw.hype = []
        raw.tempo = [TempoSegment(tick: 0, mbpm: 40_000)]
        let compiled = try CompiledChart(chart: raw, config: .standard)
        let game = try GameSession(chart: compiled, config: .standard, chartHash: "deadbeef")
        #expect(game.startTime == -4_500_000)
    }

    @Test("An interrupted run log cannot be replayed as a completed result")
    func incompleteLog() throws {
        let compiled = try EngineTestChart.make(notes: [Note(tick: 384, lane: 0)])
        var game = try GameSession(chart: compiled, config: .standard, chartHash: "deadbeef")
        try game.start()
        try game.advance(to: 500_000)
        #expect(throws: GameSession.Error.incompleteReplay) {
            try GameSession.replay(game.runLog, chart: compiled, config: .standard, chartHash: "deadbeef")
        }
    }
}
