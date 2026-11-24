/// Integer run XP and flat deferred match bonuses.
public enum XPRules {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case invalidStars
        case invalidStreak
        case invalidPlacement
        case overflow
    }

    public enum MatchBonus: Equatable, Sendable {
        case none
        case duelWin
        case groupPlace(Int)
    }

    public static func runXP(
        stars: Int, fullCombo: Bool, firstRunOfDay: Bool, streakDays: Int,
        featured: Bool, practice: Bool, config: GameConfig
    ) throws -> Int64 {
        let xp = config.xp
        guard
            xp.finishRun >= 0, xp.perStar >= 0, xp.fullCombo >= 0, xp.firstRunOfDay >= 0,
            xp.streakBonusPercentPerDay >= 0, xp.maxStreakBonusPercent >= 0,
            xp.featuredSongPercent >= 0, xp.practicePercent >= 0, config.stars.goldStarValue > 5
        else { throw Error.invalidConfiguration }
        guard (0...5).contains(stars) || (stars == config.stars.goldStarValue && fullCombo) else {
            throw Error.invalidStars
        }
        guard streakDays >= 1 else { throw Error.invalidStreak }

        var events = try add(Int64(xp.finishRun), multiply(Int64(xp.perStar), Int64(stars)))
        if fullCombo { events = try add(events, Int64(xp.fullCombo)) }
        if firstRunOfDay { events = try add(events, Int64(xp.firstRunOfDay)) }

        let extraDays = streakDays - 1
        let bonus: Int
        if xp.streakBonusPercentPerDay == 0 {
            bonus = 0
        } else if extraDays > xp.maxStreakBonusPercent / xp.streakBonusPercentPerDay {
            bonus = xp.maxStreakBonusPercent
        } else {
            bonus = min(xp.maxStreakBonusPercent, extraDays * xp.streakBonusPercentPerDay)
        }
        let streakPercent = try add(100, Int64(bonus))
        let featuredPercent = Int64(featured ? xp.featuredSongPercent : 100)
        let practicePercent = Int64(practice ? xp.practicePercent : 100)
        let numerator = try multiply(
            try multiply(try multiply(events, streakPercent), featuredPercent), practicePercent)
        return numerator / 1_000_000
    }

    public static func settlementBonus(_ bonus: MatchBonus, config: GameConfig) throws -> Int64 {
        guard config.xp.duelWin >= 0, config.xp.groupPodium.allSatisfy({ $0 >= 0 }) else {
            throw Error.invalidConfiguration
        }
        switch bonus {
        case .none: return 0
        case .duelWin: return Int64(config.xp.duelWin)
        case .groupPlace(let place):
            guard place > 0 else { throw Error.invalidPlacement }
            return place <= config.xp.groupPodium.count ? Int64(config.xp.groupPodium[place - 1]) : 0
        }
    }

    private static func add(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw Error.overflow }
        return result
    }

    private static func multiply(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.multipliedReportingOverflow(by: right)
        guard !overflow else { throw Error.overflow }
        return result
    }
}
