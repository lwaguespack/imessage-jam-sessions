/// Pure updates for adding an entry, closing a group round and starting a rematch.
public enum MatchActions {
    public enum Error: Swift.Error, Equatable, Sendable {
        case unknownProposal
        case notGroupRound
        case notStarter
        case notFinal
        case winnerChanged
        case starterMismatch
        case roundOverflow
        case seriesCapacity
        case winsOverflow
    }

    public static func submit(
        _ entry: MatchEntry, to descriptor: MatchDescriptor, in state: MatchState, config: GameConfig
    ) throws -> MatchState {
        guard let index = state.proposals.firstIndex(where: { $0.descriptor == descriptor }) else {
            throw Error.unknownProposal
        }
        var proposals = state.proposals
        var entries = proposals[index].entries
        MatchMerge.add(entry, to: &entries)
        proposals[index] = try MatchProposal(
            descriptor: descriptor, closedAt: proposals[index].closedAt, entries: entries)
        return try replacingProposals(proposals, in: state, config: config)
    }

    public static func close(
        _ state: MatchState, by playerID: UInt64, at time: UInt32, config: GameConfig
    ) throws -> MatchState {
        guard state.mode == .round else { throw Error.notGroupRound }
        guard state.winningProposal.descriptor.starter == playerID else { throw Error.notStarter }
        guard time > 0 else { throw MatchModelError.invalidTimestamp }
        var proposals = state.proposals
        let winner = proposals[0]
        let closedAt = winner.closedAt.map { min($0, time) } ?? time
        proposals[0] = try MatchProposal(descriptor: winner.descriptor, closedAt: closedAt, entries: winner.entries)
        return try replacingProposals(proposals, in: state, config: config)
    }

    public static func nextRound(
        from state: MatchState, descriptor: MatchDescriptor, starterEntry: MatchEntry,
        now: Int64, finalizedWinner: MatchDescriptor? = nil, config: GameConfig
    ) throws -> MatchState {
        guard descriptor.starter == starterEntry.playerID else { throw Error.starterMismatch }
        let result = try MatchFinality.evaluate(state, now: now, finalizedWinner: finalizedWinner)
        switch result.status {
        case .open: throw Error.notFinal
        case .winnerChanged: throw Error.winnerChanged
        case .final: break
        }
        let (round, overflow) = state.round.addingReportingOverflow(1)
        guard !overflow else { throw Error.roundOverflow }
        var series = state.history.series
        if state.mode == .duel {
            guard let winner = result.ranked.first else { throw Error.notFinal }
            if let index = series.firstIndex(where: { $0.playerID == winner.playerID }) {
                let (wins, winsOverflow) = series[index].wins.addingReportingOverflow(1)
                guard !winsOverflow else { throw Error.winsOverflow }
                series[index] = MatchHistory.SeriesWin(playerID: winner.playerID, wins: wins)
            } else {
                guard series.count < 2 else { throw Error.seriesCapacity }
                series.append(MatchHistory.SeriesWin(playerID: winner.playerID, wins: 1))
            }
        }
        let previous = result.ranked.prefix(state.mode == .duel ? 2 : 3).map(MatchShortEntry.init)
        let history = try MatchHistory(
            series: series, previousChart: previous.isEmpty ? nil : state.winningProposal.descriptor.chart,
            previous: previous)
        let proposal = try MatchProposal(descriptor: descriptor, entries: [starterEntry])
        return try MatchState(
            matchID: state.matchID, mode: state.mode, rulesVersion: state.rulesVersion,
            contentRevision: state.contentRevision, round: round, history: history,
            proposals: [proposal], config: config)
    }

    private static func replacingProposals(
        _ proposals: [MatchProposal], in state: MatchState, config: GameConfig
    ) throws -> MatchState {
        try MatchState(
            matchID: state.matchID, mode: state.mode, rulesVersion: state.rulesVersion,
            contentRevision: state.contentRevision, round: state.round, history: state.history,
            proposals: proposals, config: config)
    }
}
