/// Merge-safe XP counters and unlocked cosmetics. IDs are supplied by the caller.
public struct Profile: Codable, Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case differentProfile
        case invalidXP
        case invalidState
        case invalidConfiguration
        case overflow
    }

    public struct Counter: Codable, Equatable, Sendable {
        public let installationID: UInt64
        public let xp: Int64

        init(installationID: UInt64, xp: Int64) {
            self.installationID = installationID
            self.xp = xp
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            installationID = try Profile.parseID(container.decode(String.self, forKey: .installationID))
            let value = try container.decode(Int64.self, forKey: .xp)
            guard value >= 0 else { throw Error.invalidState }
            xp = value
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Profile.hexID(installationID), forKey: .installationID)
            try container.encode(xp, forKey: .xp)
        }

        private enum CodingKeys: String, CodingKey {
            case installationID, xp
        }
    }

    public let profileID: UInt64
    public private(set) var counters: [Counter]
    public private(set) var unlocked: [String]

    public init(profileID: UInt64, unlocks: Unlocks) {
        self.profileID = profileID
        counters = []
        unlocked = unlocks.defaults.sorted(by: Self.precedes)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileID = try Self.parseID(container.decode(String.self, forKey: .profileID))
        counters = try container.decode([Counter].self, forKey: .counters)
        unlocked = try container.decode([String].self, forKey: .unlocked)
        guard counters.allSatisfy({ $0.xp >= 0 }),
            zip(counters, counters.dropFirst()).allSatisfy({ $0.installationID < $1.installationID }),
            unlocked.allSatisfy({ Unlocks.kind(of: $0) != nil }),
            zip(unlocked, unlocked.dropFirst()).allSatisfy({ Self.precedes($0, $1) })
        else { throw Error.invalidState }
        _ = try totalXP()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.hexID(profileID), forKey: .profileID)
        try container.encode(counters, forKey: .counters)
        try container.encode(unlocked, forKey: .unlocked)
    }

    public func totalXP() throws -> Int64 {
        var total: Int64 = 0
        for counter in counters {
            let (next, overflow) = total.addingReportingOverflow(counter.xp)
            guard !overflow else { throw Error.overflow }
            total = next
        }
        return total
    }

    public func level(config: GameConfig) throws -> Int {
        let levels = config.levels
        guard levels.maxLevel >= 1, levels.xpToAdvanceBase >= 0, levels.xpToAdvancePerLevel >= 0 else {
            throw Error.invalidConfiguration
        }
        let (firstCost, firstOverflow) = levels.xpToAdvanceBase.addingReportingOverflow(levels.xpToAdvancePerLevel)
        guard !firstOverflow, levels.maxLevel == 1 || firstCost > 0 else { throw Error.invalidConfiguration }
        let (lastTerm, overflow) = levels.xpToAdvancePerLevel.multipliedReportingOverflow(
            by: levels.maxLevel - 1)
        let (_, sumOverflow) = levels.xpToAdvanceBase.addingReportingOverflow(lastTerm)
        guard !overflow, !sumOverflow, let total = Int(exactly: try totalXP()) else { throw Error.overflow }
        return LevelCurve(config: config).level(forTotalXP: total)
    }

    /// Credits one installation and grants all rewards through the newly derived level.
    public mutating func addXP(
        _ amount: Int64, installationID: UInt64, unlocks: Unlocks, config: GameConfig
    ) throws {
        guard amount >= 0 else { throw Error.invalidXP }
        var updated = self
        if amount > 0 {
            if let index = updated.counters.firstIndex(where: { $0.installationID == installationID }) {
                let (xp, overflow) = updated.counters[index].xp.addingReportingOverflow(amount)
                guard !overflow else { throw Error.overflow }
                updated.counters[index] = Counter(installationID: installationID, xp: xp)
            } else {
                updated.counters.append(Counter(installationID: installationID, xp: amount))
                updated.counters.sort { $0.installationID < $1.installationID }
            }
        }
        try updated.grantEarned(unlocks: unlocks, config: config)
        self = updated
    }

    public func merging(_ other: Profile, unlocks: Unlocks, config: GameConfig) throws -> Profile {
        guard profileID == other.profileID else { throw Error.differentProfile }
        var merged = self
        for counter in other.counters {
            if let index = merged.counters.firstIndex(where: { $0.installationID == counter.installationID }) {
                merged.counters[index] = Counter(
                    installationID: counter.installationID, xp: max(merged.counters[index].xp, counter.xp))
            } else {
                merged.counters.append(counter)
            }
        }
        merged.counters.sort { $0.installationID < $1.installationID }
        merged.unlocked = Array(Set(unlocked + other.unlocked)).sorted(by: Self.precedes)
        try merged.grantEarned(unlocks: unlocks, config: config)
        return merged
    }

    private mutating func grantEarned(unlocks: Unlocks, config: GameConfig) throws {
        guard unlocks.maxLevel == config.levels.maxLevel else { throw Error.invalidConfiguration }
        let earned = try unlocks.earned(through: level(config: config))
        unlocked = Array(Set(unlocked + earned)).sorted(by: Self.precedes)
    }

    private static func precedes(_ left: String, _ right: String) -> Bool {
        left.utf8.lexicographicallyPrecedes(right.utf8)
    }

    private static func hexID(_ value: UInt64) -> String {
        let text = String(value, radix: 16)
        return String(repeating: "0", count: 16 - text.count) + text
    }

    private static func parseID(_ text: String) throws -> UInt64 {
        guard text.utf8.count == 16,
            text.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
            let value = UInt64(text, radix: 16)
        else { throw Error.invalidState }
        return value
    }

    private enum CodingKeys: String, CodingKey {
        case profileID, counters, unlocked
    }
}
