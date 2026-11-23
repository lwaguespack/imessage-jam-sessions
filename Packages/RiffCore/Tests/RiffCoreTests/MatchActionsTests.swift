import RiffCore
import Testing

@Suite("Match actions")
struct MatchActionsTests {
    private let config = GameConfig.standard

    private func entry(_ id: UInt64, score: UInt32, time: UInt32) throws -> MatchEntry {
        try MatchEntry(
            playerID: id, nickname: "Player", score: score, accuracy: 10_000, longestStreak: 10,
            tries: 1, level: 1, titleID: 0, frameID: 0, fullCombo: .yes, finishedAt: time, config: config)
    }

    private func descriptor(mode: MatchMode, starter: UInt64 = 1, start: UInt32 = 100) throws -> MatchDescriptor {
        let chart = try MatchChart(songID: "song", part: .lead, difficulty: .expert, chartHash: 1, config: config)
        return try MatchDescriptor(
            chart: chart, starter: starter, startTime: start, rosterSize: mode == .duel ? 2 : 3,
            deadlineHours: mode == .duel ? 0 : 24, mode: mode, config: config)
    }

    private func state(mode: MatchMode, entries: [MatchEntry]) throws -> MatchState {
        try MatchState(
            matchID: 7, mode: mode, rulesVersion: 3, contentRevision: 1, round: 1,
            history: MatchHistory(),
            proposals: [MatchProposal(descriptor: descriptor(mode: mode), entries: entries)], config: config)
    }

    @Test("Submitting preserves the earlier entry and all other players")
    func submit() throws {
        let match = try state(mode: .round, entries: [entry(1, score: 100, time: 110)])
        let added = try MatchActions.submit(
            entry(2, score: 200, time: 120), to: match.winningProposal.descriptor, in: match, config: config)
        let later = try MatchActions.submit(
            entry(1, score: 999, time: 130), to: match.winningProposal.descriptor, in: added, config: config)
        #expect(later.winningEntries.map(\.score) == [100, 200])
    }

    @Test("Only the starter closes a group round and the earliest close is kept")
    func close() throws {
        let match = try state(mode: .round, entries: [entry(1, score: 100, time: 110)])
        #expect(throws: MatchActions.Error.notStarter) {
            try MatchActions.close(match, by: 2, at: 150, config: config)
        }
        let closed = try MatchActions.close(match, by: 1, at: 150, config: config)
        let earlier = try MatchActions.close(closed, by: 1, at: 140, config: config)
        #expect(earlier.winningProposal.closedAt == 140)
    }

    @Test("A final duel rematch carries the prior result and increments its winner")
    func rematch() throws {
        let match = try state(
            mode: .duel,
            entries: [
                entry(1, score: 100, time: 110), entry(2, score: 200, time: 120),
            ])
        let next = try MatchActions.nextRound(
            from: match, descriptor: descriptor(mode: .duel, starter: 2, start: 130),
            starterEntry: entry(2, score: 150, time: 140), now: 130, config: config)
        #expect(next.round == 2)
        #expect(next.history.previous.map(\.playerID) == [1, 2])
        #expect(next.history.previousChart == match.winningProposal.descriptor.chart)
        #expect(next.history.series == [.init(playerID: 2, wins: 1)])
        #expect(next.winningEntries.map(\.playerID) == [2])
    }

    @Test("An open round cannot start a rematch")
    func openRound() throws {
        let match = try state(mode: .duel, entries: [entry(1, score: 100, time: 110)])
        #expect(throws: MatchActions.Error.notFinal) {
            try MatchActions.nextRound(
                from: match, descriptor: descriptor(mode: .duel, start: 130),
                starterEntry: entry(1, score: 150, time: 140), now: 130, config: config)
        }
    }
}
