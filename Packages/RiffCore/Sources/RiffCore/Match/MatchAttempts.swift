/// Per-match, per-round attempt counts. The caller persists an increment before starting a run.
public struct MatchAttempts: Codable, Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidRound
        case invalidConfiguration
        case limitReached
        case invalidState
    }

    public struct Record: Codable, Equatable, Sendable {
        public let matchID: UInt64
        public let round: UInt32
        public let count: UInt8

        init(matchID: UInt64, round: UInt32, count: UInt8) {
            self.matchID = matchID
            self.round = round
            self.count = count
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .matchID)
            guard let id = FixedID.decode(text) else { throw Error.invalidState }
            matchID = id
            round = try container.decode(UInt32.self, forKey: .round)
            count = try container.decode(UInt8.self, forKey: .count)
            guard round > 0, (1...99).contains(count) else { throw Error.invalidState }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(FixedID.encode(matchID), forKey: .matchID)
            try container.encode(round, forKey: .round)
            try container.encode(count, forKey: .count)
        }

        private enum CodingKeys: String, CodingKey {
            case matchID, round, count
        }
    }

    public private(set) var records: [Record] = []

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decode([Record].self, forKey: .records)
        guard
            zip(records, records.dropFirst()).allSatisfy({
                ($0.matchID, $0.round) < ($1.matchID, $1.round)
            })
        else { throw Error.invalidState }
    }

    public mutating func begin(matchID: UInt64, round: UInt32, config: GameConfig) throws -> UInt8 {
        guard round > 0 else { throw Error.invalidRound }
        guard (1...99).contains(config.match.maxTries) else { throw Error.invalidConfiguration }
        if let index = records.firstIndex(where: { $0.matchID == matchID && $0.round == round }) {
            let previous = records[index].count
            guard Int(previous) < config.match.maxTries else { throw Error.limitReached }
            let next = previous + 1
            records[index] = Record(matchID: matchID, round: round, count: next)
            return next
        }
        records.append(Record(matchID: matchID, round: round, count: 1))
        records.sort { ($0.matchID, $0.round) < ($1.matchID, $1.round) }
        return 1
    }

    private enum CodingKeys: String, CodingKey {
        case records
    }
}
