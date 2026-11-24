import Testing
import iMessageRiffCore

/// A small literal model of draft 1, used to challenge its merge rules before implementing the protocol.
@Suite("Draft match merge challenge")
struct MatchMergeChallengeTests {
    private struct State: Equatable {
        var chart: Int
        var start: Int
        var starter: Int
        var entries: [Int]
        var history: String
    }

    private struct DuelEntry: Equatable {
        let player: Int
        let time: Int
        let score: Int
    }

    private func merge(_ left: State, _ right: State) -> State {
        let earlier = (left.start, left.starter) <= (right.start, right.starter) ? left : right
        guard left.chart == right.chart else { return earlier }
        let history = encoded(left).lexicographicallyPrecedes(encoded(right)) ? left.history : right.history
        return State(
            chart: earlier.chart, start: earlier.start, starter: earlier.starter,
            entries: Array(Set(left.entries + right.entries)).sorted(), history: history)
    }

    private func encoded(_ state: State) -> [UInt8] {
        [UInt8(state.entries.count)] + state.entries.map(UInt8.init) + Array(state.history.utf8)
    }

    @Test("Draft merge loses associativity across conflicting charts")
    func conflictingChartAssociativity() {
        let a = State(chart: 0, start: 10, starter: 1, entries: [1], history: "H")
        let b = State(chart: 1, start: 15, starter: 2, entries: [2], history: "H")
        let c = State(chart: 0, start: 20, starter: 3, entries: [3], history: "H")
        #expect(merge(merge(a, b), c) != merge(a, merge(b, c)))
    }

    @Test("Draft whole-state history tie-break loses associativity")
    func historyAssociativity() {
        let a = State(chart: 0, start: 10, starter: 1, entries: [1], history: "Z")
        let b = State(chart: 0, start: 10, starter: 1, entries: [2], history: "A")
        let c = State(chart: 0, start: 10, starter: 1, entries: [1, 2], history: "B")
        #expect(merge(merge(a, b), c) != merge(a, merge(b, c)))
    }

    @Test("Draft equal-time, equal-starter chart conflict is not commutative")
    func equalDescriptorTie() {
        let a = State(chart: 0, start: 10, starter: 1, entries: [1], history: "H")
        let b = State(chart: 1, start: 10, starter: 1, entries: [1], history: "H")
        #expect(merge(a, b) != merge(b, a))
    }

    @Test("Draft re-posting cannot recover an entry discarded by a conflict")
    func conversationDoesNotLoseEntry() {
        var a = State(chart: 0, start: 10, starter: 1, entries: [1], history: "H")
        var b = State(chart: 1, start: 15, starter: 2, entries: [2], history: "H")
        var c = State(chart: 0, start: 20, starter: 3, entries: [3], history: "H")
        c = merge(c, b)
        a = merge(a, c)
        b = merge(b, a)
        c = merge(c, b)
        #expect(!a.entries.contains(3))
        #expect(!b.entries.contains(3))
        #expect(!c.entries.contains(3))
    }

    @Test("The same score and longest streak can have different Full Combo results")
    func fullComboIsNotDerivable() throws {
        let chart = try EngineTestChart.make(notes: [Note(tick: 384, lane: 0), Note(tick: 768, lane: 1)])
        func result(ghost: Bool) throws -> RunSummary {
            var game = try GameSession(chart: chart, config: .standard, chartHash: "deadbeef")
            try game.start()
            if ghost {
                try game.apply(.touchDown(id: 9, lane: 3, time: 870_000))
                try game.apply(.touchUp(id: 9, time: 870_001))
            }
            try game.apply(.touchDown(id: 1, lane: 0, time: 1_000_000))
            try game.apply(.touchUp(id: 1, time: 1_000_001))
            try game.apply(.touchDown(id: 2, lane: 1, time: 2_000_000))
            try game.advance(to: 2_000_000)
            return try RunSummary(session: game, baseScore: 200)
        }
        let clean = try result(ghost: false)
        let penalized = try result(ghost: true)
        #expect(clean.score == penalized.score)
        #expect(clean.longestStreak == penalized.longestStreak)
        #expect(clean.fullCombo && !penalized.fullCombo)
    }

    @Test("First-observed final standings can disagree before all entries arrive")
    func irreversibleSettlementCanDisagree() {
        let starter = DuelEntry(player: 1, time: 10, score: 80)
        let laterRun = DuelEntry(player: 2, time: 20, score: 70)
        let earlierRun = DuelEntry(player: 2, time: 15, score: 100)
        let firstDevice = [starter, laterRun]
        let secondDevice = [starter, earlierRun]
        func winner(_ entries: [DuelEntry]) -> Int {
            entries.max { $0.score < $1.score }!.player
        }
        func mergeEntries(_ left: [DuelEntry], _ right: [DuelEntry]) -> [DuelEntry] {
            var result = left
            for entry in right {
                if let index = result.firstIndex(where: { $0.player == entry.player }) {
                    if entry.time < result[index].time { result[index] = entry }
                } else {
                    result.append(entry)
                }
            }
            return result
        }
        #expect(winner(firstDevice) == 1)
        #expect(winner(secondDevice) == 2)
        #expect(winner(mergeEntries(firstDevice, secondDevice)) == 2)
    }
}

@Suite("Proposal-set merge challenge")
struct ProposalMergeChallengeTests {
    private struct Entry: Equatable {
        let player: Int
        let time: Int
        let value: Int
    }

    private struct Proposal: Equatable {
        let start: Int
        let starter: Int
        let chart: Int
        var entries: [Entry]
        var closedAt: Int?

        var key: (Int, Int, Int) { (start, starter, chart) }
    }

    private struct State: Equatable {
        var proposals: [Proposal]
        var history: String
    }

    private func join(_ left: State, _ right: State) -> State {
        var proposals = left.proposals
        for incoming in right.proposals {
            if let index = proposals.firstIndex(where: { $0.key == incoming.key }) {
                for entry in incoming.entries {
                    if let existing = proposals[index].entries.firstIndex(where: { $0.player == entry.player }) {
                        let old = proposals[index].entries[existing]
                        if (entry.time, entry.value) < (old.time, old.value) {
                            proposals[index].entries[existing] = entry
                        }
                    } else {
                        proposals[index].entries.append(entry)
                    }
                }
                proposals[index].entries.sort { $0.player < $1.player }
                proposals[index].closedAt = [proposals[index].closedAt, incoming.closedAt]
                    .compactMap { $0 }.min()
            } else {
                proposals.append(incoming)
            }
        }
        proposals.sort { $0.key < $1.key }
        return State(proposals: proposals, history: min(left.history, right.history))
    }

    private func state(_ random: inout SplitMix64) -> State {
        let player = Int(random.next() % 5)
        let proposal = Proposal(
            start: Int(random.next() % 4), starter: Int(random.next() % 3), chart: Int(random.next() % 3),
            entries: [Entry(player: player, time: Int(random.next() % 10), value: Int(random.next() % 10))],
            closedAt: random.next() % 2 == 0 ? nil : Int(random.next() % 10) + 1)
        return State(proposals: [proposal], history: String(random.next() % 3))
    }

    private func winnerEntries(_ state: State) -> [Int] {
        guard let winningChart = state.proposals.first?.chart else { return [] }
        return Array(Set(state.proposals.filter { $0.chart == winningChart }.flatMap { $0.entries.map(\.player) }))
            .sorted()
    }

    @Test("A bounded proposal set satisfies the three merge laws for 1,000 seeds")
    func mergeLaws() {
        for seed in UInt64(0)..<1_000 {
            var random = SplitMix64(seed: seed)
            let a = state(&random)
            let b = state(&random)
            let c = state(&random)
            #expect(join(a, b) == join(b, a), "commutative seed \(seed)")
            #expect(join(join(a, b), c) == join(a, join(b, c)), "associative seed \(seed)")
            #expect(join(a, a) == a, "idempotent seed \(seed)")
        }
    }

    @Test("Re-posting converges after drops and duplicates without losing winner-chart entries")
    func conversationSimulator() {
        let initial = [
            State(
                proposals: [
                    Proposal(
                        start: 10, starter: 1, chart: 0, entries: [Entry(player: 1, time: 11, value: 1)], closedAt: nil)
                ],
                history: "H"),
            State(
                proposals: [
                    Proposal(
                        start: 15, starter: 2, chart: 1, entries: [Entry(player: 2, time: 16, value: 2)], closedAt: nil)
                ],
                history: "H"),
            State(
                proposals: [
                    Proposal(
                        start: 20, starter: 3, chart: 0, entries: [Entry(player: 3, time: 21, value: 3)], closedAt: nil)
                ],
                history: "H"),
        ]
        for seed in UInt64(0)..<1_000 {
            var random = SplitMix64(seed: seed)
            var devices = initial
            for _ in 0..<20 {
                let sender = Int(random.next() % 3)
                let recipient = Int(random.next() % 3)
                if random.next() % 3 != 0 {
                    devices[recipient] = join(devices[recipient], devices[sender])
                }
            }
            for sender in 0..<3 {
                for recipient in 0..<3 {
                    devices[recipient] = join(devices[recipient], devices[sender])
                }
            }
            for sender in 0..<3 {
                for recipient in 0..<3 {
                    devices[recipient] = join(devices[recipient], devices[sender])
                }
            }
            #expect(devices[0] == devices[1] && devices[1] == devices[2], "seed \(seed)")
            #expect(winnerEntries(devices[0]) == [1, 3], "seed \(seed)")
            #expect(devices[0].proposals.contains { $0.chart == 1 && $0.entries.contains { $0.player == 2 } })
        }
    }
}
