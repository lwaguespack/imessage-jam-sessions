/// An in-memory join store. The caller persists its fragments before presenting or sending a result.
public struct MatchStore: Sendable {
    public enum Outcome: Equatable, Sendable {
        case merged(MatchState)
        case capacityExceeded(proposals: Int, entries: Int)
        case incompatibleMetadata
    }

    private var stored: [MatchState] = []
    public var allFragments: [MatchState] { stored }

    public init() {}

    /// Keeps every fragment if a complete join cannot be represented.
    public mutating func receive(_ state: MatchState, config: GameConfig) throws -> Outcome {
        _ = try MatchMerge.merge(state, state, config: config)
        var group = stored.filter { $0.matchID == state.matchID && $0.round == state.round }
        if !group.contains(state) { group.append(state) }
        group.sort { $0.canonicalBody.lexicographicallyPrecedes($1.canonicalBody) }

        let outcome: Outcome
        if group.contains(where: {
            $0.mode != state.mode || $0.rulesVersion != state.rulesVersion
                || $0.contentRevision != state.contentRevision
        }) {
            outcome = .incompatibleMetadata
        } else {
            var joined = group[0]
            do {
                for fragment in group.dropFirst() {
                    joined = try MatchMerge.merge(joined, fragment, config: config)
                }
                outcome = .merged(joined)
            } catch MatchModelError.capacityExceeded(let proposals, let entries) {
                outcome = .capacityExceeded(proposals: proposals, entries: entries)
            }
        }

        stored.removeAll { $0.matchID == state.matchID && $0.round == state.round }
        switch outcome {
        case .merged(let joined): stored.append(joined)
        case .capacityExceeded, .incompatibleMetadata: stored.append(contentsOf: group)
        }
        stored.sort { $0.canonicalBody.lexicographicallyPrecedes($1.canonicalBody) }
        return outcome
    }

    public func fragments(matchID: UInt64, round: UInt32) -> [MatchState] {
        stored.filter { $0.matchID == matchID && $0.round == round }
    }

    public func latestRound(matchID: UInt64) -> UInt32? {
        stored.filter { $0.matchID == matchID }.map(\.round).max()
    }
}
