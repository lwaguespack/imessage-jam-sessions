/// Level arithmetic for the XP curve in `GameConfig.Levels` (plan 6.2).
///
/// Pure integer functions of the config, so a level shown on one device can be recomputed on any other.
public struct LevelCurve: Equatable, Sendable {
    /// The level every player starts at. The curve's formula counts levels from here, so it is not a tunable.
    public static let firstLevel = 1

    public let levels: GameConfig.Levels

    public init(config: GameConfig) {
        levels = config.levels
    }

    /// The highest level, never below the first so that a bad config cannot produce an empty level range.
    public var maxLevel: Int {
        max(levels.maxLevel, Self.firstLevel)
    }

    /// XP needed to go from `level` to the next one, or nil when there is no next level to earn: at the level
    /// cap, or for a number that is not a level.
    public func xpToAdvance(from level: Int) -> Int? {
        guard level >= Self.firstLevel, level < maxLevel else { return nil }
        return levels.xpToAdvanceBase + levels.xpToAdvancePerLevel * level
    }

    /// Total XP a player has earned on arriving at `level`. Levels outside the valid range are clamped into it.
    public func totalXP(toReach level: Int) -> Int {
        let target = min(max(level, Self.firstLevel), maxLevel)
        // Sum of (base + perLevel * L) for L from the first level up to target - 1, in closed form.
        let steps = target - Self.firstLevel
        let levelSum = steps * (Self.firstLevel + target - 1) / 2
        return levels.xpToAdvanceBase * steps + levels.xpToAdvancePerLevel * levelSum
    }

    /// The level of a player who has earned `totalXP` in all, from the first level up to the cap.
    public func level(forTotalXP totalXP: Int) -> Int {
        var level = Self.firstLevel
        var remaining = totalXP
        while let cost = xpToAdvance(from: level), remaining >= cost {
            remaining -= cost
            level += 1
        }
        return level
    }
}
