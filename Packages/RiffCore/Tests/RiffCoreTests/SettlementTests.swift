import Foundation
import RiffCore
import Testing

@Suite("Match settlement")
struct SettlementTests {
    private let config = GameConfig.standard

    private func entry(_ id: UInt64, score: UInt32, time: UInt32) throws -> MatchEntry {
        try MatchEntry(
            playerID: id, nickname: "Player", score: score, accuracy: 10_000, longestStreak: 10,
            tries: 1, level: 1, titleID: 0, frameID: 0, fullCombo: .yes, finishedAt: time, config: config)
    }

    private func state(
        mode: MatchMode, entries: [MatchEntry], round: UInt32 = 1, history: MatchHistory? = nil,
        closedAt: UInt32? = nil
    ) throws -> MatchState {
        let chart = try MatchChart(songID: "song", part: .lead, difficulty: .expert, chartHash: 1, config: config)
        let descriptor = try MatchDescriptor(
            chart: chart, starter: 1, startTime: 100, rosterSize: mode == .duel ? 2 : 3,
            deadlineHours: mode == .duel ? 0 : 24, mode: mode, config: config)
        return try MatchState(
            matchID: .max, mode: mode, rulesVersion: 3, contentRevision: 1, round: round,
            history: history ?? MatchHistory(),
            proposals: [MatchProposal(descriptor: descriptor, closedAt: closedAt, entries: entries)], config: config)
    }

    @Test("A duel win is credited once even after encoding and reopening the ledger")
    func duelOnce() throws {
        let unlocks = try ProgressionTestData.unlocks()
        var progress = SettlementState(profile: Profile(profileID: .max, unlocks: unlocks))
        let match = try state(mode: .duel, entries: [entry(1, score: 100, time: 100), entry(2, score: 200, time: 101)])
        #expect(
            try progress.settleCurrent(
                match, now: 102, playerID: 2, installationID: .max, contentRevision: 1,
                unlocks: unlocks, config: config) == .settled(75))
        let encoded = try CanonicalJSON.encode(progress)
        var restored = try JSONDecoder().decode(SettlementState.self, from: encoded)
        #expect(
            try restored.settleCurrent(
                match, now: 103, playerID: 2, installationID: .max, contentRevision: 1,
                unlocks: unlocks, config: config) == .alreadySettled)
        #expect(try restored.profile.totalXP() == 75)
    }

    @Test("An already-paid round still reports a changed finalized proposal")
    func conflictAfterSettlement() throws {
        let unlocks = try ProgressionTestData.unlocks()
        var progress = SettlementState(profile: Profile(profileID: 1, unlocks: unlocks))
        let entries = try [entry(1, score: 100, time: 100), entry(2, score: 200, time: 101)]
        let original = try state(mode: .duel, entries: entries)
        let oldWinner = original.winningProposal.descriptor
        #expect(
            try progress.settleCurrent(
                original, now: 102, finalizedWinner: oldWinner, playerID: 2, installationID: 2,
                contentRevision: 1, unlocks: unlocks, config: config) == .settled(75))
        let saved = progress
        let earlier = try MatchDescriptor(
            chart: oldWinner.chart, starter: oldWinner.starter, startTime: 99,
            rosterSize: 2, deadlineHours: 0, mode: .duel, config: config)
        let changed = try MatchState(
            matchID: original.matchID, mode: .duel, rulesVersion: original.rulesVersion,
            contentRevision: original.contentRevision, round: original.round, history: original.history,
            proposals: [MatchProposal(descriptor: earlier, entries: entries)], config: config)
        #expect(
            try progress.settleCurrent(
                changed, now: 103, finalizedWinner: oldWinner, playerID: 2, installationID: 2,
                contentRevision: 1, unlocks: unlocks, config: config) == .winnerChanged)
        #expect(throws: MatchFinality.Error.invalidTime) {
            try progress.settleCurrent(
                original, now: -1, finalizedWinner: oldWinner, playerID: 2, installationID: 2,
                contentRevision: 1, unlocks: unlocks, config: config)
        }
        #expect(progress == saved)
    }

    @Test("A late group entry settles for zero, not podium XP")
    func lateEntry() throws {
        let unlocks = try ProgressionTestData.unlocks()
        var progress = SettlementState(profile: Profile(profileID: 1, unlocks: unlocks))
        let match = try state(
            mode: .round, entries: [entry(1, score: 100, time: 100), entry(2, score: 999, time: 151)],
            closedAt: 150)
        #expect(
            try progress.settleCurrent(
                match, now: 151, playerID: 2, installationID: 2, contentRevision: 1,
                unlocks: unlocks, config: config) == .settled(0))
        #expect(try progress.profile.totalXP() == 0)
    }

    @Test("A group podium awards the configured place exactly once")
    func groupPodium() throws {
        let unlocks = try ProgressionTestData.unlocks()
        var progress = SettlementState(profile: Profile(profileID: 1, unlocks: unlocks))
        let match = try state(
            mode: .round,
            entries: [
                entry(1, score: 300, time: 100), entry(2, score: 200, time: 101), entry(3, score: 100, time: 102),
            ])
        #expect(
            try progress.settleCurrent(
                match, now: 102, playerID: 2, installationID: 2, contentRevision: 1,
                unlocks: unlocks, config: config) == .settled(50))
        #expect(
            try progress.settleCurrent(
                match, now: 103, playerID: 2, installationID: 2, contentRevision: 1,
                unlocks: unlocks, config: config) == .alreadySettled)
        #expect(try progress.profile.totalXP() == 50)
    }

    @Test("A previous-round summary and its original bubble share the same ledger key")
    func previousRoundOnce() throws {
        let unlocks = try ProgressionTestData.unlocks()
        var progress = SettlementState(profile: Profile(profileID: 1, unlocks: unlocks))
        let first = try entry(1, score: 100, time: 100)
        let second = try entry(2, score: 200, time: 101)
        let original = try state(mode: .duel, entries: [first, second])
        let chart = original.winningProposal.descriptor.chart
        let history = try MatchHistory(
            previousChart: chart, previous: [MatchShortEntry(first), MatchShortEntry(second)])
        let rematch = try state(mode: .duel, entries: [first], round: 2, history: history)
        #expect(
            try progress.settlePrevious(
                rematch, playerID: 2, installationID: 2, contentRevision: 1,
                unlocks: unlocks, config: config) == .settled(75))
        #expect(
            try progress.settleCurrent(
                original, now: 102, playerID: 2, installationID: 2, contentRevision: 1,
                unlocks: unlocks, config: config) == .alreadySettled)
        #expect(try progress.profile.totalXP() == 75)
    }

    @Test("A failed XP update does not write a settlement record")
    func atomicFailure() throws {
        let unlocks = try ProgressionTestData.unlocks()
        var profile = Profile(profileID: 1, unlocks: unlocks)
        try profile.addXP(.max, installationID: 2, unlocks: unlocks, config: config)
        var progress = SettlementState(profile: profile)
        let match = try state(mode: .duel, entries: [entry(1, score: 100, time: 100), entry(2, score: 200, time: 101)])
        #expect(throws: Profile.Error.overflow) {
            try progress.settleCurrent(
                match, now: 102, playerID: 2, installationID: 2, contentRevision: 1,
                unlocks: unlocks, config: config)
        }
        #expect(progress.records.isEmpty)
        #expect(try progress.profile.totalXP() == .max)
    }
}
