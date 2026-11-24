import Testing
import iMessageRiffCore

@Suite("Conversation simulator")
struct ConversationSimulatorTests {
    @Test("Re-posts converge and each local ledger settles once across 1,000 seeded conversations")
    func conversations() throws {
        let config = GameConfig.standard
        let unlocks = try ProgressionTestData.unlocks()

        func state(
            song: String, start: UInt32, starter: UInt64, player: UInt64, score: UInt32
        ) throws -> MatchState {
            let chart = try MatchChart(
                songID: song, part: .lead, difficulty: .expert, chartHash: 1, config: config)
            let descriptor = try MatchDescriptor(
                chart: chart, starter: starter, startTime: start, rosterSize: 3, deadlineHours: 24,
                mode: .round, config: config)
            let entry = try MatchEntry(
                playerID: player, nickname: "Player", score: score, accuracy: 10_000, longestStreak: 10,
                tries: 1, level: 1, titleID: 0, frameID: 0, fullCombo: .yes,
                finishedAt: start + 1, config: config)
            return try MatchState(
                matchID: 7, mode: .round, rulesVersion: 3, contentRevision: 1, round: 1,
                history: MatchHistory(), proposals: [MatchProposal(descriptor: descriptor, entries: [entry])],
                config: config)
        }

        let originals = try [
            state(song: "x", start: 10, starter: 1, player: 1, score: 300),
            state(song: "y", start: 15, starter: 2, player: 2, score: 400),
            state(song: "x", start: 20, starter: 3, player: 3, score: 200),
            state(song: "x", start: 25, starter: 4, player: 4, score: 100),
        ]
        let reinstalled = try state(song: "x", start: 10, starter: 1, player: 5, score: 50)
        let playerIDs: [UInt64] = [1, 5, 3, 4]
        let expectedAwards: [Int64] = [75, 0, 50, 25]

        for seed in UInt64(0)..<1_000 {
            var random = SplitMix64(seed: seed)
            var stores = [MatchStore(), MatchStore(), MatchStore(), MatchStore()]
            for index in 0..<4 { _ = try stores[index].receive(originals[index], config: config) }
            _ = try stores[0].receive(originals[1], config: config)
            stores[1] = MatchStore()
            _ = try stores[1].receive(reinstalled, config: config)

            for _ in 0..<20 {
                let sender = Int(random.next() % 4)
                let recipient = Int(random.next() % 4)
                guard random.next() % 3 != 0 else { continue }
                let message = stores[sender].fragments(matchID: 7, round: 1)[0]
                _ = try stores[recipient].receive(message, config: config)
                if random.next() % 4 == 0 { _ = try stores[recipient].receive(message, config: config) }
            }
            for _ in 0..<2 {
                for sender in 0..<4 {
                    for recipient in 0..<4 {
                        let message = stores[sender].fragments(matchID: 7, round: 1)[0]
                        _ = try stores[recipient].receive(message, config: config)
                    }
                }
            }

            let joined = try #require(stores[0].fragments(matchID: 7, round: 1).first)
            #expect(joined.winningEntries.map(\.playerID) == [1, 3, 4, 5], "seed \(seed)")
            #expect(joined.proposals.contains { $0.entries.contains { $0.playerID == 2 } })
            for index in 0..<4 {
                #expect(stores[index].fragments(matchID: 7, round: 1) == [joined], "seed \(seed)")
                var progress = SettlementState(profile: Profile(profileID: playerIDs[index], unlocks: unlocks))
                #expect(
                    try progress.settleCurrent(
                        joined, now: 100_000, playerID: playerIDs[index], installationID: playerIDs[index],
                        contentRevision: 1, unlocks: unlocks, config: config) == .settled(expectedAwards[index]))
                for _ in 0..<3 {
                    #expect(
                        try progress.settleCurrent(
                            joined, now: 100_001, playerID: playerIDs[index], installationID: playerIDs[index],
                            contentRevision: 1, unlocks: unlocks, config: config) == .alreadySettled)
                }
                #expect(progress.records.count == 1)
                #expect(try progress.profile.totalXP() == expectedAwards[index])
            }
        }
    }
}
