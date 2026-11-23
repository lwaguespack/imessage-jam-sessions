import RiffCore
import Testing

@Suite("Match proposal merge")
struct MatchMergeTests {
    private let config = GameConfig.standard

    private func entry(
        _ player: UInt64, time: UInt32, score: UInt32 = 100, nickname: String = "Player"
    ) throws -> MatchEntry {
        try MatchEntry(
            playerID: player, nickname: nickname, score: score, accuracy: 10_000, longestStreak: 10,
            tries: 1, level: 1, titleID: 0, frameID: 0, fullCombo: .yes, finishedAt: time, config: config)
    }

    private func proposal(
        song: String, start: UInt32, starter: UInt64, entries: [MatchEntry], mode: MatchMode = .round
    ) throws -> MatchProposal {
        let chart = try MatchChart(
            songID: song, part: .lead, difficulty: .expert, chartHash: 42, config: config)
        let descriptor = try MatchDescriptor(
            chart: chart, starter: starter, startTime: start, rosterSize: mode == .duel ? 2 : 3,
            deadlineHours: mode == .duel ? 0 : 24, mode: mode, config: config)
        return try MatchProposal(descriptor: descriptor, entries: entries)
    }

    private func state(
        _ proposals: [MatchProposal], mode: MatchMode = .round, history: MatchHistory? = nil, round: UInt32 = 1
    ) throws -> MatchState {
        try MatchState(
            matchID: 7, mode: mode, rulesVersion: 3, contentRevision: 1, round: round,
            history: history ?? MatchHistory(), proposals: proposals, config: config)
    }

    @Test("The conflicting-chart counterexample retains both winner-chart entries")
    func preservesCompetingProposals() throws {
        let a = try state([proposal(song: "x", start: 10, starter: 1, entries: [entry(1, time: 11)])])
        let b = try state([proposal(song: "y", start: 15, starter: 2, entries: [entry(2, time: 16)])])
        let c = try state([proposal(song: "x", start: 20, starter: 3, entries: [entry(3, time: 21)])])
        let left = try MatchMerge.merge(MatchMerge.merge(a, b, config: config), c, config: config)
        let right = try MatchMerge.merge(a, MatchMerge.merge(b, c, config: config), config: config)
        #expect(left == right)
        #expect(left.proposals.count == 3)
        #expect(left.winningEntries.map(\.playerID) == [1, 3])
        #expect(left.proposals.contains { $0.descriptor.chart.songID == "y" && $0.entries[0].playerID == 2 })
    }

    @Test("Duplicate player entries use earliest time, then canonical bytes")
    func duplicateEntries() throws {
        let first = try state([proposal(song: "x", start: 10, starter: 1, entries: [entry(1, time: 12, nickname: "B")])]
        )
        let earlier = try state([
            proposal(song: "x", start: 10, starter: 1, entries: [entry(1, time: 11, nickname: "Z")])
        ])
        let tied = try state([proposal(song: "x", start: 10, starter: 1, entries: [entry(1, time: 11, nickname: "A")])])
        let joined = try MatchMerge.merge(MatchMerge.merge(first, earlier, config: config), tied, config: config)
        #expect(joined.winningEntries[0].finishedAt == 11)
        #expect(joined.winningEntries[0].nickname == "A")
    }

    @Test("Same-chart proposals deduplicate a player while allowing clock skew")
    func sameChartAcrossProposals() throws {
        let a = try state([proposal(song: "x", start: 100, starter: 1, entries: [entry(1, time: 95)])])
        let b = try state([proposal(song: "x", start: 110, starter: 2, entries: [entry(1, time: 90)])])
        let joined = try MatchMerge.merge(a, b, config: config)
        #expect(joined.winningEntries.count == 1)
        #expect(joined.winningEntries[0].finishedAt == 90)
        #expect(joined.proposals.count == 2)
    }

    @Test("History is compared by its own canonical bytes, including LEB128 byte order")
    func historyTieBreak() throws {
        let p = try proposal(song: "x", start: 10, starter: 1, entries: [], mode: .duel)
        let first = try MatchHistory(series: [.init(playerID: 1, wins: 255)])
        let second = try MatchHistory(series: [.init(playerID: 1, wins: 256)])
        let a = try state([p], mode: .duel, history: first, round: 2)
        let b = try state([p], mode: .duel, history: second, round: 2)
        #expect(try MatchMerge.merge(a, b, config: config).history.series[0].wins == 256)
        #expect(try MatchMerge.merge(a, b, config: config) == MatchMerge.merge(b, a, config: config))
    }

    @Test("Capacity overflow is reported instead of truncating proposals")
    func capacity() throws {
        let eight = try (1...8).map { index in
            try proposal(song: "x", start: UInt32(index), starter: UInt64(index), entries: [])
        }
        let left = try state(eight)
        let right = try state([proposal(song: "x", start: 9, starter: 9, entries: [])])
        #expect(throws: MatchModelError.capacityExceeded(proposals: 9, entries: 0)) {
            try MatchMerge.merge(left, right, config: config)
        }
        #expect(left.proposals.count == 8)
        #expect(right.proposals.count == 1)
        var store = MatchStore()
        #expect(try store.receive(left, config: config) == .merged(left))
        #expect(
            try store.receive(right, config: config)
                == .capacityExceeded(proposals: 9, entries: 0))
        #expect(store.fragments(matchID: 7, round: 1).count == 2)
        #expect(store.allFragments.count == 2)

        var reverse = MatchStore()
        _ = try reverse.receive(right, config: config)
        _ = try reverse.receive(left, config: config)
        #expect(store.fragments(matchID: 7, round: 1) == reverse.fragments(matchID: 7, round: 1))

        let entries = try (1...32).map { try entry(UInt64($0), time: 11) }
        let full = try state([proposal(song: "x", start: 10, starter: 1, entries: entries)])
        let extra = try state([proposal(song: "x", start: 10, starter: 1, entries: [entry(33, time: 11)])])
        #expect(throws: MatchModelError.capacityExceeded(proposals: 1, entries: 33)) {
            try MatchMerge.merge(full, extra, config: config)
        }
    }

    @Test("Actual merge laws hold for 1,000 deterministic seeds")
    func mergeLaws() throws {
        func randomState(_ random: inout SplitMix64) throws -> MatchState {
            let song = "song-\(random.next() % 3)"
            let start = UInt32(random.next() % 5 + 1)
            let starter = random.next() % 3
            let player = random.next() % 4
            let time = UInt32(random.next() % 20 + 1)
            let score = UInt32(random.next() % 1_000)
            let historyEntry = try MatchShortEntry(entry(player, time: time, score: UInt32(random.next() % 1_000)))
            let p = try proposal(
                song: song, start: start, starter: starter, entries: [entry(player, time: time, score: score)])
            let history = try MatchHistory(previousChart: p.descriptor.chart, previous: [historyEntry])
            return try state([p], history: history, round: 2)
        }
        for seed in UInt64(0)..<1_000 {
            var random = SplitMix64(seed: seed)
            let a = try randomState(&random)
            let b = try randomState(&random)
            let c = try randomState(&random)
            #expect(try MatchMerge.merge(a, b, config: config) == MatchMerge.merge(b, a, config: config))
            #expect(
                try MatchMerge.merge(MatchMerge.merge(a, b, config: config), c, config: config)
                    == MatchMerge.merge(a, MatchMerge.merge(b, c, config: config), config: config),
                "seed \(seed)")
            #expect(try MatchMerge.merge(a, a, config: config) == a)
        }
    }

    @Test("Different match IDs and incompatible metadata are not merged")
    func incompatible() throws {
        let p = try proposal(song: "x", start: 10, starter: 1, entries: [])
        let a = try state([p])
        let otherID = try MatchState(
            matchID: 8, mode: .round, rulesVersion: 3, contentRevision: 1, round: 1,
            history: MatchHistory(), proposals: [p], config: config)
        let otherRevision = try MatchState(
            matchID: 7, mode: .round, rulesVersion: 3, contentRevision: 2, round: 1,
            history: MatchHistory(), proposals: [p], config: config)
        #expect(throws: MatchModelError.differentMatch) { try MatchMerge.merge(a, otherID, config: config) }
        #expect(throws: MatchModelError.incompatibleMetadata) {
            try MatchMerge.merge(a, otherRevision, config: config)
        }
        var store = MatchStore()
        _ = try store.receive(a, config: config)
        #expect(try store.receive(otherRevision, config: config) == .incompatibleMetadata)
        #expect(store.fragments(matchID: 7, round: 1).count == 2)

        let nextRound = try state([p], round: 2)
        _ = try store.receive(nextRound, config: config)
        #expect(store.latestRound(matchID: 7) == 2)
        #expect(store.fragments(matchID: 7, round: 1).count == 2)
    }

    @Test("Actual stores converge after dropped, duplicated and reordered messages for 1,000 seeds")
    func conversationSimulator() throws {
        let originals = try [
            state([proposal(song: "x", start: 10, starter: 1, entries: [entry(1, time: 11)])]),
            state([proposal(song: "y", start: 15, starter: 2, entries: [entry(2, time: 16)])]),
            state([proposal(song: "x", start: 20, starter: 3, entries: [entry(3, time: 21)])]),
        ]
        for seed in UInt64(0)..<1_000 {
            var random = SplitMix64(seed: seed)
            var stores = [MatchStore(), MatchStore(), MatchStore()]
            for index in 0..<3 { _ = try stores[index].receive(originals[index], config: config) }
            for _ in 0..<20 {
                let sender = Int(random.next() % 3)
                let recipient = Int(random.next() % 3)
                if random.next() % 3 != 0 {
                    let fragment = stores[sender].fragments(matchID: 7, round: 1)[0]
                    _ = try stores[recipient].receive(fragment, config: config)
                }
            }
            for _ in 0..<2 {
                for sender in 0..<3 {
                    for recipient in 0..<3 {
                        let fragment = stores[sender].fragments(matchID: 7, round: 1)[0]
                        _ = try stores[recipient].receive(fragment, config: config)
                    }
                }
            }
            let joined = stores[0].fragments(matchID: 7, round: 1)
            #expect(joined == stores[1].fragments(matchID: 7, round: 1), "seed \(seed)")
            #expect(joined == stores[2].fragments(matchID: 7, round: 1), "seed \(seed)")
            #expect(joined[0].winningEntries.map(\.playerID) == [1, 3], "seed \(seed)")
            #expect(joined[0].proposals.count == 3)
        }
    }
}
