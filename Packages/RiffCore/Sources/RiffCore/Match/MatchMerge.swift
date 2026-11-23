/// Joins compatible proposal sets without discarding losing-chart entries.
public enum MatchMerge {
    public static func merge(_ left: MatchState, _ right: MatchState, config: GameConfig) throws -> MatchState {
        try validate(left, config: config)
        try validate(right, config: config)
        guard left.matchID == right.matchID else { throw MatchModelError.differentMatch }
        guard left.mode == right.mode, left.rulesVersion == right.rulesVersion,
            left.contentRevision == right.contentRevision
        else { throw MatchModelError.incompatibleMetadata }
        if left.round != right.round { return left.round > right.round ? left : right }

        var proposals = left.proposals
        for incoming in right.proposals {
            if let index = proposals.firstIndex(where: { $0.descriptor == incoming.descriptor }) {
                var entries = proposals[index].entries
                for entry in incoming.entries { add(entry, to: &entries) }
                let closedAt = [proposals[index].closedAt, incoming.closedAt].compactMap { $0 }.min()
                proposals[index] = try MatchProposal(
                    descriptor: incoming.descriptor, closedAt: closedAt, entries: entries)
            } else {
                proposals.append(incoming)
            }
        }
        let history =
            left.history.canonicalBytes.lexicographicallyPrecedes(right.history.canonicalBytes)
            ? left.history : right.history
        return try MatchState(
            matchID: left.matchID, mode: left.mode, rulesVersion: left.rulesVersion,
            contentRevision: left.contentRevision, round: left.round, history: history,
            proposals: proposals, config: config)
    }

    private static func validate(_ state: MatchState, config: GameConfig) throws {
        _ = try MatchState(
            matchID: state.matchID, mode: state.mode, rulesVersion: state.rulesVersion,
            contentRevision: state.contentRevision, round: state.round, history: state.history,
            proposals: state.proposals, config: config)
    }

    static func add(_ entry: MatchEntry, to entries: inout [MatchEntry]) {
        guard let index = entries.firstIndex(where: { $0.playerID == entry.playerID }) else {
            entries.append(entry)
            return
        }
        let old = entries[index]
        if entry.finishedAt < old.finishedAt
            || (entry.finishedAt == old.finishedAt
                && entry.canonicalBytes.lexicographicallyPrecedes(old.canonicalBytes))
        {
            entries[index] = entry
        }
    }
}
