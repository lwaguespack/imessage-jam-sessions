import Foundation
import Testing
import iMessageRiffCore

@Suite("Match routing and submission")
struct MatchRoutingTests {
    private let config = GameConfig.standard

    private func state(entries: [UInt64], closedAt: UInt32? = nil) throws -> MatchState {
        let chart = try MatchChart(songID: "song", part: .lead, difficulty: .expert, chartHash: 1, config: config)
        let descriptor = try MatchDescriptor(
            chart: chart, starter: 1, startTime: 100, rosterSize: 3, deadlineHours: 24,
            mode: .round, config: config)
        let values = try entries.map { id in
            try MatchEntry(
                playerID: id, nickname: "Player", score: 100, accuracy: 10_000, longestStreak: 10,
                tries: 1, level: 1, titleID: 0, frameID: 0, fullCombo: .yes, finishedAt: 101, config: config)
        }
        return try MatchState(
            matchID: 1, mode: .round, rulesVersion: 3, contentRevision: 1, round: 1,
            history: MatchHistory(),
            proposals: [MatchProposal(descriptor: descriptor, closedAt: closedAt, entries: values)],
            config: config)
    }

    private func selection(_ state: MatchState, key: String = "one", pending: Bool = false) -> MatchRouter.Selection {
        MatchRouter.Selection(key: key, isPending: pending, decoded: .valid(state, warnings: []))
    }

    @Test("Open, pending, saved and final states route without confusing a draft for a sent score")
    func routes() throws {
        let empty = try state(entries: [])
        let mine = try state(entries: [1])
        let final = try state(entries: [1, 2, 3])
        var router = MatchRouter()
        #expect(try router.route(selection: nil, store: nil, playerID: 1, hasSavedRun: false, now: 101).screen == .home)
        #expect(
            try router.route(
                selection: selection(empty), store: nil, playerID: 1, hasSavedRun: false, now: 101
            ).screen == .yourTurn)
        #expect(
            try router.route(
                selection: selection(mine, pending: true), store: nil, playerID: 1, hasSavedRun: true, now: 101
            ).screen == .sendScore)
        #expect(
            try router.route(
                selection: selection(empty), store: nil, playerID: 1, hasSavedRun: true, now: 101
            ).screen == .sendScore)
        #expect(
            try router.route(
                selection: selection(mine), store: nil, playerID: 1, hasSavedRun: false, now: 101
            ).screen == .waiting)
        #expect(
            try router.route(
                selection: selection(final), store: nil, playerID: 1, hasSavedRun: false, now: 103
            ).screen == .results)
    }

    @Test("Stored entries missing from the bubble offer re-post without hiding results")
    func repost() throws {
        let bubble = try state(entries: [1])
        let merged = try state(entries: [1, 2, 3])
        var router = MatchRouter()
        let decision = try router.route(
            selection: selection(bubble), store: .merged(merged), playerID: 1, hasSavedRun: false, now: 103)
        #expect(decision.screen == .results)
        #expect(decision.offerRepost)
    }

    @Test("Home remains sticky for the same bubble and clears for a different bubble")
    func stickyHome() throws {
        let match = try state(entries: [])
        var router = MatchRouter()
        _ = try router.route(selection: selection(match), store: nil, playerID: 1, hasSavedRun: false, now: 101)
        router.leaveMatch()
        #expect(
            try router.route(selection: selection(match), store: nil, playerID: 1, hasSavedRun: false, now: 101)
                .screen == .home)
        #expect(
            try router.route(
                selection: selection(match, key: "two"), store: nil, playerID: 1, hasSavedRun: false, now: 101
            )
            .screen == .yourTurn)
    }

    @Test("Decode notices and capacity conflicts are explicit")
    func notices() throws {
        let match = try state(entries: [])
        var router = MatchRouter()
        let update = MatchRouter.Selection(key: "update", isPending: false, decoded: .updateNeeded)
        #expect(
            try router.route(selection: update, store: nil, playerID: 1, hasSavedRun: false, now: 101)
                .screen == .updateNeeded)
        #expect(
            try router.route(
                selection: selection(match), store: .capacityExceeded(proposals: 9, entries: 0),
                playerID: 1, hasSavedRun: false, now: 101
            ).screen == .conflict)
    }

    @Test("A changed final winner overrides a pending draft")
    func pendingConflict() throws {
        let match = try state(entries: [1])
        let winner = match.winningProposal.descriptor
        let oldWinner = try MatchDescriptor(
            chart: winner.chart, starter: winner.starter, startTime: 200, rosterSize: winner.rosterSize,
            deadlineHours: winner.deadlineHours, mode: .round, config: config)
        var router = MatchRouter()
        #expect(
            try router.route(
                selection: selection(match, pending: true), store: nil, playerID: 1, hasSavedRun: true,
                now: 101, finalizedWinner: oldWinner
            ).screen == .conflict)
    }

    @Test("A draft is not confirmed until the entry appears in a non-pending message")
    func submission() throws {
        var submission = MatchSubmission()
        try submission.staged()
        try submission.startedSending()
        submission.observe(isPending: true, containsEntry: true)
        #expect(submission.state == .sending)
        submission.observe(isPending: false, containsEntry: true)
        #expect(submission.state == .confirmed)
        submission.cancelled()
        #expect(submission.state == .confirmed)

        var cancelled = MatchSubmission()
        try cancelled.staged()
        cancelled.cancelled()
        #expect(cancelled.state == .played)
        #expect(throws: MatchSubmission.Error.invalidTransition) { try submission.staged() }
    }

    @Test("Attempts persist per match and round, and the configured limit is explicit")
    func attempts() throws {
        var config = GameConfig.standard
        config.match.maxTries = 2
        var attempts = MatchAttempts()
        #expect(try attempts.begin(matchID: .max, round: 1, config: config) == 1)
        #expect(try attempts.begin(matchID: .max, round: 2, config: config) == 1)
        let data = try CanonicalJSON.encode(attempts)
        var restored = try JSONDecoder().decode(MatchAttempts.self, from: data)
        #expect(try restored.begin(matchID: .max, round: 1, config: config) == 2)
        #expect(throws: MatchAttempts.Error.limitReached) {
            try restored.begin(matchID: .max, round: 1, config: config)
        }
        #expect(restored.records.map(\.count) == [2, 1])
    }
}
