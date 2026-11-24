import Testing
import iMessageRiffCore

@Suite("Match ranking and finality")
struct MatchFinalityTests {
    private let config = GameConfig.standard

    private func entry(
        _ id: UInt64, score: UInt32 = 100, accuracy: UInt16 = 10_000, streak: UInt32 = 10,
        tries: UInt8 = 1, time: UInt32
    ) throws -> MatchEntry {
        try MatchEntry(
            playerID: id, nickname: "Player", score: score, accuracy: accuracy, longestStreak: streak,
            tries: tries, level: 1, titleID: 0, frameID: 0, fullCombo: .no, finishedAt: time, config: config)
    }

    private func state(
        mode: MatchMode, entries: [MatchEntry], start: UInt32 = 100, closedAt: UInt32? = nil
    ) throws -> MatchState {
        let chart = try MatchChart(songID: "song", part: .lead, difficulty: .expert, chartHash: 1, config: config)
        let descriptor = try MatchDescriptor(
            chart: chart, starter: 1, startTime: start, rosterSize: mode == .duel ? 2 : 3,
            deadlineHours: mode == .duel ? 0 : 24, mode: mode, config: config)
        return try MatchState(
            matchID: 1, mode: mode, rulesVersion: 3, contentRevision: 1, round: 1,
            history: MatchHistory(),
            proposals: [MatchProposal(descriptor: descriptor, closedAt: closedAt, entries: entries)],
            config: config)
    }

    @Test("Ranking uses every tie-break in order")
    func ranking() throws {
        let entries = try [
            entry(7, score: 99, time: 10),
            entry(6, accuracy: 9_999, time: 10),
            entry(5, streak: 9, time: 10),
            entry(4, tries: 2, time: 10),
            entry(3, time: 11),
            entry(2, time: 10),
            entry(1, time: 10),
        ]
        #expect(try MatchRanking.ranked(entries).map(\.playerID) == [1, 2, 3, 4, 5, 6, 7])
        #expect(throws: MatchModelError.duplicatePlayer(1)) {
            try MatchRanking.ranked([entries[6], entries[6]])
        }
    }

    @Test("Group standings exclude entries after the earlier close")
    func groupClose() throws {
        let match = try state(
            mode: .round, entries: [entry(1, time: 90), entry(2, time: 150), entry(3, time: 151)],
            closedAt: 150)
        let result = try MatchFinality.evaluate(match, now: 110)
        #expect(result.status == .final)
        #expect(result.endTime == 150)
        #expect(result.ranked.map(\.playerID) == [1, 2])
        #expect(result.late.map(\.playerID) == [3])
    }

    @Test("Late entries do not satisfy group quorum and a skewed close is clamped to the start")
    func groupQuorumAndSkew() throws {
        let open = try state(
            mode: .round, entries: [entry(1, time: 100), entry(2, time: 101), entry(3, time: 86_501)])
        let openResult = try MatchFinality.evaluate(open, now: 102)
        #expect(openResult.status == .open)
        #expect(openResult.late.map(\.playerID) == [3])

        let closed = try state(mode: .round, entries: [entry(1, time: 95), entry(2, time: 101)], closedAt: 90)
        let closedResult = try MatchFinality.evaluate(closed, now: 102)
        #expect(closedResult.endTime == 100)
        #expect(closedResult.ranked.map(\.playerID) == [1])
        #expect(closedResult.late.map(\.playerID) == [2])
    }

    @Test("Duel finality requires the starter and chooses the earliest other player")
    func duel() throws {
        let match = try state(
            mode: .duel,
            entries: [
                entry(1, score: 90, time: 100), entry(2, score: 110, time: 105), entry(3, score: 200, time: 110),
            ])
        let result = try MatchFinality.evaluate(match, now: 111)
        #expect(result.status == .final)
        #expect(result.ranked.map(\.playerID) == [2, 1])
        #expect(result.ignored.map(\.playerID) == [3])

        let missingStarter = try state(mode: .duel, entries: [entry(2, time: 105), entry(3, time: 110)])
        #expect(try MatchFinality.evaluate(missingStarter, now: 111).status == .open)
        #expect(throws: MatchModelError.invalidClosure) {
            try state(mode: .duel, entries: [entry(1, time: 100)], closedAt: 101)
        }
    }

    @Test("A locally final proposal does not silently reopen when an earlier winner arrives")
    func changedFinalWinner() throws {
        let earlier = try state(mode: .round, entries: [entry(1, time: 90)], start: 100)
        let previouslyFinal = try state(mode: .round, entries: [entry(1, time: 190)], start: 200)
        let result = try MatchFinality.evaluate(
            earlier, now: 101, finalizedWinner: previouslyFinal.winningProposal.descriptor)
        #expect(result.status == .winnerChanged)
    }
}
