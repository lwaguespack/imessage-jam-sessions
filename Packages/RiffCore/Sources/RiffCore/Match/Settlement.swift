/// A profile and its local settlement ledger, intended to be persisted atomically as one value.
public struct SettlementState: Codable, Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidLedger
        case incompatibleRevision
    }

    public enum Outcome: Equatable, Sendable {
        case notFinal
        case winnerChanged
        case noEntry
        case noPrevious
        case alreadySettled
        case settled(Int64)
    }

    public struct Record: Codable, Equatable, Sendable {
        public let matchID: UInt64
        public let round: UInt32
        public let award: Int64

        init(matchID: UInt64, round: UInt32, award: Int64) {
            self.matchID = matchID
            self.round = round
            self.award = award
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .matchID)
            guard let id = FixedID.decode(text) else { throw Error.invalidLedger }
            matchID = id
            round = try container.decode(UInt32.self, forKey: .round)
            award = try container.decode(Int64.self, forKey: .award)
            guard round > 0, award >= 0 else { throw Error.invalidLedger }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(FixedID.encode(matchID), forKey: .matchID)
            try container.encode(round, forKey: .round)
            try container.encode(award, forKey: .award)
        }

        private enum CodingKeys: String, CodingKey {
            case matchID, round, award
        }
    }

    public private(set) var profile: Profile
    public private(set) var records: [Record]

    public init(profile: Profile) {
        self.profile = profile
        records = []
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(Profile.self, forKey: .profile)
        records = try container.decode([Record].self, forKey: .records)
        guard
            zip(records, records.dropFirst()).allSatisfy({
                ($0.matchID, $0.round) < ($1.matchID, $1.round)
            })
        else { throw Error.invalidLedger }
    }

    /// `state` must have passed the chart-aware decode pipeline.
    public mutating func settleCurrent(
        _ state: MatchState, now: Int64, finalizedWinner: MatchDescriptor? = nil,
        playerID: UInt64, installationID: UInt64, contentRevision: UInt32,
        unlocks: Unlocks, config: GameConfig
    ) throws -> Outcome {
        try validateRevision(state, contentRevision: contentRevision, config: config)
        let finality = try MatchFinality.evaluate(state, now: now, finalizedWinner: finalizedWinner)
        if finality.status == .winnerChanged { return .winnerChanged }
        if hasRecord(matchID: state.matchID, round: state.round) { return .alreadySettled }
        guard finality.status == .final else { return .notFinal }
        guard state.winningEntries.contains(where: { $0.playerID == playerID }) else { return .noEntry }
        let place = finality.ranked.firstIndex { $0.playerID == playerID }.map { $0 + 1 }
        let bonus = try bonus(mode: state.mode, place: place, config: config)
        return try record(
            bonus, matchID: state.matchID, round: state.round, installationID: installationID,
            unlocks: unlocks, config: config)
    }

    /// Settles an included previous-round summary with the same key as the original round.
    public mutating func settlePrevious(
        _ state: MatchState, playerID: UInt64, installationID: UInt64, contentRevision: UInt32,
        unlocks: Unlocks, config: GameConfig
    ) throws -> Outcome {
        try validateRevision(state, contentRevision: contentRevision, config: config)
        guard state.round > 1, !state.history.previous.isEmpty else { return .noPrevious }
        let previousRound = state.round - 1
        if hasRecord(matchID: state.matchID, round: previousRound) { return .alreadySettled }
        guard state.mode != .duel || state.history.previous.count == 2 else { return .notFinal }
        guard state.history.previous.contains(where: { $0.playerID == playerID }) else { return .noEntry }
        let ranked = try MatchRanking.ranked(state.history.previous)
        let place = ranked.firstIndex { $0.playerID == playerID }.map { $0 + 1 }
        let bonus = try bonus(mode: state.mode, place: place, config: config)
        return try record(
            bonus, matchID: state.matchID, round: previousRound, installationID: installationID,
            unlocks: unlocks, config: config)
    }

    private func validateRevision(_ state: MatchState, contentRevision: UInt32, config: GameConfig) throws {
        guard let rules = UInt32(exactly: config.rulesVersion), rules == state.rulesVersion,
            contentRevision > 0, state.contentRevision == contentRevision
        else { throw Error.incompatibleRevision }
    }

    private func hasRecord(matchID: UInt64, round: UInt32) -> Bool {
        records.contains { $0.matchID == matchID && $0.round == round }
    }

    private func bonus(mode: MatchMode, place: Int?, config: GameConfig) throws -> Int64 {
        guard let place else { return 0 }
        switch mode {
        case .duel: return try XPRules.settlementBonus(place == 1 ? .duelWin : .none, config: config)
        case .round: return try XPRules.settlementBonus(.groupPlace(place), config: config)
        }
    }

    private mutating func record(
        _ award: Int64, matchID: UInt64, round: UInt32, installationID: UInt64,
        unlocks: Unlocks, config: GameConfig
    ) throws -> Outcome {
        var updated = profile
        try updated.addXP(award, installationID: installationID, unlocks: unlocks, config: config)
        var ledger = records
        ledger.append(Record(matchID: matchID, round: round, award: award))
        ledger.sort { ($0.matchID, $0.round) < ($1.matchID, $1.round) }
        profile = updated
        records = ledger
        return .settled(award)
    }

    private enum CodingKeys: String, CodingKey {
        case profile, records
    }
}
