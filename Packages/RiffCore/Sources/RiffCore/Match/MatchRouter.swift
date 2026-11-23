/// Routes the selected bubble and locally joined state without depending on Messages APIs.
public struct MatchRouter: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidSelectionKey
        case storeMismatch
    }

    public enum Screen: Equatable, Sendable {
        case home
        case updateNeeded
        case askSenderToUpdate
        case unsupportedLegacy
        case unreadable
        case conflict
        case yourTurn
        case sendScore
        case waiting
        case results
    }

    public struct Selection: Sendable {
        public let key: String
        public let isPending: Bool
        public let decoded: MatchDecode.Outcome

        public init(key: String, isPending: Bool, decoded: MatchDecode.Outcome) {
            self.key = key
            self.isPending = isPending
            self.decoded = decoded
        }
    }

    public struct Decision: Equatable, Sendable {
        public let screen: Screen
        public let offerRepost: Bool
    }

    public private(set) var lastHandledKey: String?
    public private(set) var userLeftMatch = false

    public init() {}

    public mutating func leaveMatch() {
        userLeftMatch = true
    }

    /// `hasSavedRun` refers to the joined state's winning chart and round.
    public mutating func route(
        selection: Selection?, store: MatchStore.Outcome?, playerID: UInt64, hasSavedRun: Bool,
        now: Int64, finalizedWinner: MatchDescriptor? = nil, config: GameConfig = .standard
    ) throws -> Decision {
        guard let selection else { return Decision(screen: .home, offerRepost: false) }
        guard !selection.key.isEmpty else { throw Error.invalidSelectionKey }
        if selection.key != lastHandledKey {
            lastHandledKey = selection.key
            userLeftMatch = false
        }
        guard !userLeftMatch else { return Decision(screen: .home, offerRepost: false) }

        let selected: MatchState
        switch selection.decoded {
        case .updateNeeded: return Decision(screen: .updateNeeded, offerRepost: false)
        case .askSenderToUpdate: return Decision(screen: .askSenderToUpdate, offerRepost: false)
        case .unsupportedLegacy: return Decision(screen: .unsupportedLegacy, offerRepost: false)
        case .unreadable: return Decision(screen: .unreadable, offerRepost: false)
        case .valid(let state, _): selected = state
        }
        let joined: MatchState
        switch store {
        case .capacityExceeded, .incompatibleMetadata:
            return Decision(screen: .conflict, offerRepost: false)
        case .merged(let stored):
            guard stored.matchID == selected.matchID, stored.round == selected.round else { throw Error.storeMismatch }
            do {
                joined = try MatchMerge.merge(selected, stored, config: config)
            } catch MatchModelError.capacityExceeded {
                return Decision(screen: .conflict, offerRepost: false)
            } catch MatchModelError.incompatibleMetadata {
                return Decision(screen: .conflict, offerRepost: false)
            }
        case nil:
            joined = selected
        }
        let repost = joined != selected
        let finality = try MatchFinality.evaluate(joined, now: now, finalizedWinner: finalizedWinner)
        if finality.status == .winnerChanged { return Decision(screen: .conflict, offerRepost: repost) }
        if selection.isPending { return Decision(screen: .sendScore, offerRepost: repost) }
        switch finality.status {
        case .winnerChanged: return Decision(screen: .conflict, offerRepost: repost)
        case .final: return Decision(screen: .results, offerRepost: repost)
        case .open: break
        }
        let sameChart = selected.winningProposal.descriptor.chart == joined.winningProposal.descriptor.chart
        let inBubble = sameChart && selected.winningEntries.contains { $0.playerID == playerID }
        let inStore = joined.winningEntries.contains { $0.playerID == playerID }
        if !inBubble && (hasSavedRun || inStore) {
            return Decision(screen: .sendScore, offerRepost: repost)
        }
        return Decision(screen: inStore ? .waiting : .yourTurn, offerRepost: repost)
    }
}
