import RiffCore
import Testing

@Suite("Progression arithmetic")
struct ProgressionRulesTests {
    @Test("Run XP applies three percentage factors with one floor")
    func runXP() throws {
        let config = GameConfig.standard
        #expect(
            try XPRules.runXP(
                stars: 4, fullCombo: false, firstRunOfDay: false, streakDays: 5,
                featured: false, practice: false, config: config) == 252)
        #expect(
            try XPRules.runXP(
                stars: 4, fullCombo: false, firstRunOfDay: true, streakDays: 2,
                featured: true, practice: true, config: config) == 231)
        #expect(
            try XPRules.runXP(
                stars: 0, fullCombo: false, firstRunOfDay: false, streakDays: 1,
                featured: false, practice: false, config: config) == 100)
    }

    @Test("Streak bonuses cap and deferred match awards are flat")
    func streakAndSettlement() throws {
        let config = GameConfig.standard
        let daySix = try XPRules.runXP(
            stars: 3, fullCombo: false, firstRunOfDay: false, streakDays: 6,
            featured: false, practice: false, config: config)
        let dayHundred = try XPRules.runXP(
            stars: 3, fullCombo: false, firstRunOfDay: false, streakDays: 100,
            featured: false, practice: false, config: config)
        #expect(daySix == 240)
        #expect(dayHundred == daySix)
        #expect(try XPRules.settlementBonus(.duelWin, config: config) == 75)
        #expect(try XPRules.settlementBonus(.groupPlace(2), config: config) == 50)
        #expect(try XPRules.settlementBonus(.groupPlace(4), config: config) == 0)
    }

    @Test("Invalid Gold, streak and placement inputs are rejected")
    func invalidXPInputs() {
        let config = GameConfig.standard
        #expect(throws: XPRules.Error.invalidStars) {
            try XPRules.runXP(
                stars: 6, fullCombo: false, firstRunOfDay: false, streakDays: 1,
                featured: false, practice: false, config: config)
        }
        #expect(throws: XPRules.Error.invalidStreak) {
            try XPRules.runXP(
                stars: 1, fullCombo: false, firstRunOfDay: false, streakDays: 0,
                featured: false, practice: false, config: config)
        }
        #expect(throws: XPRules.Error.invalidPlacement) {
            try XPRules.settlementBonus(.groupPlace(0), config: config)
        }
    }

    @Test("Featured rotation uses the fixed UTC epoch across year boundaries")
    func featuredRotation() throws {
        let rotation = try FeaturedRotation(schedule: ["a", "b", "c", "d"], config: .standard)
        #expect(try rotation.song(at: 1_767_571_199) == "d")
        #expect(try rotation.song(at: 1_767_571_200) == "a")
        #expect(try rotation.song(at: 1_798_416_000) == "d")
        #expect(try rotation.song(at: 1_799_020_800) == "a")
        #expect(try rotation.song(at: 1_829_865_600) == "d")
        #expect(try rotation.song(at: 1_830_470_400) == "a")
        #expect(throws: FeaturedRotation.Error.emptySchedule) {
            try FeaturedRotation(schedule: [], config: .standard)
        }
    }
}
