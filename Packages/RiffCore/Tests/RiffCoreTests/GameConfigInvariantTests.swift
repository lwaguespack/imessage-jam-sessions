import RiffCore
import Testing

@Suite("GameConfig invariants")
struct GameConfigInvariantTests {
    let config = GameConfig.standard

    @Test("Judgement windows widen strictly from Perfect to Good")
    func windowsStrictlyIncrease() {
        let judging = config.judging
        #expect(judging.perfect.windowMicros > 0)
        #expect(judging.perfect.windowMicros < judging.great.windowMicros)
        #expect(judging.great.windowMicros < judging.good.windowMicros)
    }

    @Test("Window scaling never narrows a window and always lands on a whole microsecond", arguments: Difficulty.allCases)
    func windowScaleIsExact(difficulty: Difficulty) {
        let judging = config.judging
        let scale = Int64(judging.windowScalePercent[difficulty])
        #expect(scale >= 100)
        for rule in [judging.perfect, judging.great, judging.good] {
            #expect((rule.windowMicros * scale).isMultiple(of: 100))
        }
    }

    @Test("Only Easy widens the windows, by 20 percent")
    func onlyEasyWidensWindows() {
        #expect(config.judging.windowScalePercent == PerDifficulty(easy: 120, medium: 100, hard: 100, expert: 100))
    }

    @Test("Points and accuracy weights never rise from Perfect to Good, and a ghost tap never pays")
    func pointsNeverRise() {
        let judging = config.judging
        #expect(judging.perfect.points >= judging.great.points)
        #expect(judging.great.points >= judging.good.points)
        #expect(judging.good.points > 0)
        #expect(judging.perfect.accuracyBasisPoints == 10_000)
        #expect(judging.perfect.accuracyBasisPoints >= judging.great.accuracyBasisPoints)
        #expect(judging.great.accuracyBasisPoints >= judging.good.accuracyBasisPoints)
        #expect(judging.good.accuracyBasisPoints > 0)
        #expect(judging.ghostTapPenaltyPoints >= 0)
    }

    @Test("The multiplier tops out at 4, and at 8 with Hype")
    func multiplierCeiling() {
        #expect(config.scoring.streakPerMultiplierStep > 0)
        #expect(config.scoring.sustainPointsPerBeat > 0)
        #expect(config.scoring.maxStreakMultiplier == 4)
        #expect(config.scoring.maxStreakMultiplier * config.hype.multiplier == 8)
    }

    @Test("The Hype meter fills in whole phrases and every chart can activate it")
    func hypeMeterIsConsistent() {
        let hype = config.hype
        #expect(hype.phraseGain > 0)
        #expect(hype.drainPerBeat > 0)
        #expect(hype.meterCapacity.isMultiple(of: hype.phraseGain))
        #expect(hype.meterCapacity.isMultiple(of: hype.drainPerBeat))
        #expect(hype.activationMinimum > 0)
        #expect(hype.activationMinimum <= hype.meterCapacity)
        #expect(hype.minPhrasesPerSong <= hype.maxPhrasesPerSong)
        #expect(hype.minPhrasesPerSong * hype.phraseGain >= hype.activationMinimum)
    }

    @Test("Star thresholds ascend and Gold sits one above the top star")
    func starThresholdsAscend() {
        let stars = config.stars
        #expect(stars.thresholdsPercent.count == 5)
        #expect(stars.thresholdsPercent.allSatisfy { (1...100).contains($0) })
        #expect(zip(stars.thresholdsPercent, stars.thresholdsPercent.dropFirst()).allSatisfy { $0 < $1 })
        #expect(stars.goldMinimumStars == stars.thresholdsPercent.count)
        #expect(stars.goldStarValue == stars.thresholdsPercent.count + 1)
    }

    @Test("Scroll times shorten with difficulty")
    func scrollTimesAreOrdered() {
        let times = Difficulty.allCases.map { config.highway.scrollTimeMicros[$0] }
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 > $1 })
    }

    @Test("Every difficulty has a scroll time inside the adjustable range", arguments: Difficulty.allCases)
    func scrollTimeIsInRange(difficulty: Difficulty) {
        let highway = config.highway
        #expect(highway.minScrollTimeMicros > 0)
        #expect(highway.minScrollTimeMicros < highway.maxScrollTimeMicros)
        #expect((highway.minScrollTimeMicros...highway.maxScrollTimeMicros).contains(highway.scrollTimeMicros[difficulty]))
    }

    @Test("Highway geometry fits the screen and the lanes split evenly between two thumbs")
    func highwayGeometryIsSane() {
        let highway = config.highway
        #expect(highway.laneCount == 4)
        #expect(highway.laneCount.isMultiple(of: 2))
        #expect((2...highway.laneCount).contains(highway.maxNotesPerChord))
        #expect((1..<100).contains(highway.touchZoneHeightPercent))
        #expect((1..<highway.touchZoneHeightPercent).contains(highway.strikeLinePercentFromBottom))
    }

    @Test("Every difficulty has a chart rule whose limits make sense", arguments: Difficulty.allCases)
    func chartRuleIsSane(difficulty: Difficulty) {
        let rule = config.charts.rules[difficulty]
        #expect(rule.minAverageMilliNotesPerSecond > 0)
        #expect(rule.minAverageMilliNotesPerSecond < rule.maxAverageMilliNotesPerSecond)
        #expect(rule.maxAverageMilliNotesPerSecond < rule.maxPeakMilliNotesPerSecond)
        #expect(rule.minSameLaneGapMicros > 0)
        #expect(rule.shortestHold.numerator > 0)
        #expect(rule.shortestHold.denominator > 0)
        // The gap rule must leave room for a note to be judged before the next one on its lane arrives.
        #expect(rule.minSameLaneGapMicros >= config.judging.perfect.windowMicros * 2)
    }

    @Test("Chart rules get denser, tighter and shorter-held as difficulty rises")
    func chartRulesScaleWithDifficulty() {
        let rules = Difficulty.allCases.map { config.charts.rules[$0] }
        for (easier, harder) in zip(rules, rules.dropFirst()) {
            #expect(easier.maxAverageMilliNotesPerSecond == harder.minAverageMilliNotesPerSecond)
            #expect(easier.maxPeakMilliNotesPerSecond < harder.maxPeakMilliNotesPerSecond)
            #expect(easier.minSameLaneGapMicros > harder.minSameLaneGapMicros)
            #expect(
                easier.shortestHold.numerator * harder.shortestHold.denominator
                    >= harder.shortestHold.numerator * easier.shortestHold.denominator
            )
        }
        #expect(config.charts.rules.easy.chords == .forbidden)
        #expect(config.charts.rules.expert.chords == .allowed)
        #expect(config.charts.defaultTicksPerBeat > 0)
    }

    @Test("The shortest hold of every difficulty is a whole number of ticks at the default resolution")
    func shortestHoldsFitTheTickGrid() {
        for difficulty in Difficulty.allCases {
            let hold = config.charts.rules[difficulty].shortestHold
            #expect((config.charts.defaultTicksPerBeat * hold.numerator).isMultiple(of: hold.denominator))
        }
    }

    @Test("Payload caps are positive and agree with each other")
    func payloadCapsAreConsistent() {
        let payload = config.payload
        let caps = [
            payload.schemaVersion, payload.maxEncodedBytes, payload.maxDuelEncodedBytes, payload.maxEntries,
            payload.maxNicknameCharacters, payload.matchIDCharacters, payload.playerIDHexCharacters,
            payload.chartHashHexCharacters, payload.signatureBytes,
        ]
        #expect(caps.allSatisfy { $0 > 0 })
        #expect(payload.maxDuelEncodedBytes <= payload.maxEncodedBytes)
        // A duel needs two entries, a UUID has 32 hex digits and SHA-256 gives 32 bytes to truncate.
        #expect(payload.maxEntries >= 2)
        #expect(payload.playerIDHexCharacters <= 32)
        #expect(payload.signatureBytes <= 32)
        #expect(payload.chartHashHexCharacters.isMultiple(of: 2))
    }

    @Test("Schema versions in the config are the package's schema versions")
    func schemaVersionsHaveOneSource() {
        #expect(config.payload.schemaVersion == RiffCoreInfo.payloadSchemaVersion)
        #expect(config.charts.schemaVersion == RiffCoreInfo.chartSchemaVersion)
    }

    @Test("The lead-in covers the longest scroll time a player can choose")
    func leadInCoversScrollTime() {
        let playback = config.playback
        #expect(playback.minLeadInMicros >= config.highway.maxScrollTimeMicros)
        #expect(playback.startCountdownBeats > 0)
        #expect(playback.resumeCountdownBeats > 0)
        #expect(playback.missDuckMicros > 0)
        #expect(playback.driftCorrectionThresholdMicros > 0)
        #expect(playback.driftCorrectionThresholdMicros < playback.driftCheckIntervalMicros)
    }

    @Test("XP awards are positive, the podium descends and the multipliers point the right way")
    func xpAwardsAreSane() {
        let xp = config.xp
        #expect([xp.finishRun, xp.perStar, xp.fullCombo, xp.duelWin, xp.firstRunOfDay].allSatisfy { $0 > 0 })
        #expect(xp.groupPodium.count == 3)
        #expect(zip(xp.groupPodium, xp.groupPodium.dropFirst()).allSatisfy { $0 > $1 })
        #expect(xp.groupPodium.first == xp.duelWin)
        #expect(xp.groupPodium.allSatisfy { $0 > 0 })
        #expect(xp.streakBonusPercentPerDay > 0)
        #expect(xp.maxStreakBonusPercent.isMultiple(of: xp.streakBonusPercentPerDay))
        #expect(xp.featuredSongPercent > 100)
        #expect((1..<100).contains(xp.practicePercent))
    }

    @Test("There are enough unlocks for the early levels and never more than one per level-up")
    func unlockCountsFitTheLevelCurve() {
        let unlocks = config.unlocks
        let counts = [
            unlocks.titles, unlocks.scoreCardFrames, unlocks.noteSkins, unlocks.highwayThemes,
            unlocks.strikeLineEffects,
        ]
        #expect(counts.allSatisfy { $0 > 0 })
        let total = counts.reduce(0, +)
        #expect(total == 40)
        #expect(total <= config.levels.maxLevel - LevelCurve.firstLevel)
        #expect(unlocks.guaranteedFromLevel > LevelCurve.firstLevel)
        #expect(unlocks.guaranteedFromLevel <= unlocks.guaranteedThroughLevel)
        #expect(unlocks.guaranteedThroughLevel <= config.levels.maxLevel)
        #expect(total >= unlocks.guaranteedThroughLevel - unlocks.guaranteedFromLevel + 1)
    }

    @Test("Song limits and performance budgets are positive and ordered")
    func songLimitsAndBudgetsAreSane() {
        let songs = config.songs
        #expect(songs.minDurationMicros > 0)
        #expect(songs.minDurationMicros < songs.maxDurationMicros)
        #expect(songs.sourceSampleRatesHz == songs.sourceSampleRatesHz.sorted())
        #expect(songs.sourceSampleRatesHz.allSatisfy { $0 > 0 })
        #expect(!songs.sourceSampleRatesHz.isEmpty)
        #expect(songs.targetLoudnessLUFS < 0)
        #expect(songs.artworkPixels > 0)

        let budgets = config.budgets
        #expect(budgets.targetFramesPerSecond > 0)
        #expect(budgets.proMotionFramesPerSecond >= budgets.targetFramesPerSecond)
        #expect((1..<10_000).contains(budgets.maxDroppedFramesBasisPoints))
        #expect(budgets.maxOpenToHomeMicros > 0)
        #expect(budgets.maxSongLoadMicros > 0)
        #expect(budgets.maxScoreCardBytes == 307_200)
        #expect(budgets.maxAppDownloadBytes == 62_914_560)
    }

    @Test("No value anywhere in the config is floating point")
    func configHoldsNoFloatingPoint() {
        let leaves = Self.leaves(of: config, path: "config")
        // Guards the check itself: if reflection ever stopped descending, an empty list would pass vacuously.
        #expect(leaves.count > 100)
        for leaf in leaves {
            let isWholeNumber = leaf.value is Int || leaf.value is Int64
            let isEnum = Mirror(reflecting: leaf.value).displayStyle == .enum
            #expect(isWholeNumber || isEnum, "\(leaf.path) is \(type(of: leaf.value))")
        }
    }

    private static func leaves(of value: Any, path: String) -> [(path: String, value: Any)] {
        let children = Mirror(reflecting: value).children
        if children.isEmpty {
            return [(path, value)]
        }
        return children.enumerated().flatMap { index, child in
            leaves(of: child.value, path: path + "." + (child.label ?? String(index)))
        }
    }
}
