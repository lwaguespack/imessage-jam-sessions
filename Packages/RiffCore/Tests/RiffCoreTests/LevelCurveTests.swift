import RiffCore
import Testing

@Suite("Level curve")
struct LevelCurveTests {
    let curve = LevelCurve(config: .standard)

    @Test("Level 2 takes 500 XP")
    func levelTwoTakes500() {
        #expect(curve.xpToAdvance(from: 1) == 500)
        #expect(curve.totalXP(toReach: 2) == 500)
    }

    @Test("Level 10 takes 8,100 XP in total")
    func levelTenTakes8100() {
        #expect(curve.totalXP(toReach: 10) == 8_100)
    }

    @Test("Level 50 takes 142,100 XP in total")
    func levelFiftyTakes142100() {
        #expect(curve.totalXP(toReach: 50) == 142_100)
    }

    @Test("Each level costs 400 + 100L, and nothing is left to earn at the cap")
    func costOfEachLevel() {
        for level in 1..<50 {
            #expect(curve.xpToAdvance(from: level) == 400 + 100 * level)
        }
        #expect(curve.xpToAdvance(from: 50) == nil)
        #expect(curve.xpToAdvance(from: 51) == nil)
        #expect(curve.xpToAdvance(from: 0) == nil)
        #expect(curve.xpToAdvance(from: -3) == nil)
    }

    @Test("The total to reach a level is the sum of the costs below it")
    func totalIsSumOfCosts() {
        var runningTotal = 0
        for level in 1...50 {
            #expect(curve.totalXP(toReach: level) == runningTotal)
            runningTotal += curve.xpToAdvance(from: level) ?? 0
        }
    }

    @Test("level(forTotalXP:) is the inverse of totalXP(toReach:) for every level")
    func levelIsInverseOfTotal() {
        for level in 1...50 {
            let threshold = curve.totalXP(toReach: level)
            #expect(curve.level(forTotalXP: threshold) == level)
            #expect(curve.level(forTotalXP: threshold + 1) == level)
            if level > 1 {
                #expect(curve.level(forTotalXP: threshold - 1) == level - 1)
            }
        }
    }

    @Test("Levels clamp at 1 and at 50")
    func levelsClamp() {
        #expect(curve.maxLevel == 50)
        #expect(curve.level(forTotalXP: 0) == 1)
        #expect(curve.level(forTotalXP: -500) == 1)
        #expect(curve.level(forTotalXP: 142_100) == 50)
        #expect(curve.level(forTotalXP: 1_000_000) == 50)
        #expect(curve.level(forTotalXP: .max) == 50)
        #expect(curve.totalXP(toReach: 0) == 0)
        #expect(curve.totalXP(toReach: -7) == 0)
        #expect(curve.totalXP(toReach: 51) == 142_100)
        #expect(curve.totalXP(toReach: .max) == 142_100)
    }

    @Test("The curve follows whatever config it is given")
    func curveIsConfigDriven() {
        var config = GameConfig.standard
        config.levels.xpToAdvanceBase = 10
        config.levels.xpToAdvancePerLevel = 5
        config.levels.maxLevel = 4
        let small = LevelCurve(config: config)

        #expect(small.xpToAdvance(from: 1) == 15)
        #expect(small.xpToAdvance(from: 3) == 25)
        #expect(small.xpToAdvance(from: 4) == nil)
        #expect(small.totalXP(toReach: 4) == 60)
        #expect(small.level(forTotalXP: 59) == 3)
        #expect(small.level(forTotalXP: 60) == 4)
        #expect(small != curve)
    }

    @Test("A config with no levels above the first still gives a one-level curve")
    func degenerateConfigDoesNotTrap() {
        var config = GameConfig.standard
        config.levels.maxLevel = 0
        let flat = LevelCurve(config: config)

        #expect(flat.maxLevel == 1)
        #expect(flat.xpToAdvance(from: 1) == nil)
        #expect(flat.totalXP(toReach: 10) == 0)
        #expect(flat.level(forTotalXP: 1_000_000) == 1)
    }
}
