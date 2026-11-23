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

    @Test(
        "Window scaling never narrows a window and always lands on a whole microsecond", arguments: Difficulty.allCases)
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

    @Test("Scaled windows are 54, 108 and 156 ms on Easy and the base values elsewhere")
    func scaledWindows() {
        let judging = config.judging
        let rules = [judging.perfect, judging.great, judging.good]
        #expect(rules.map { judging.windowMicros(of: $0, on: .easy) } == [54_000, 108_000, 156_000])
        for difficulty in [Difficulty.medium, .hard, .expert] {
            #expect(rules.map { judging.windowMicros(of: $0, on: difficulty) } == [45_000, 90_000, 130_000])
        }
    }

    @Test("Points and accuracy weights never rise from Perfect to Good")
    func pointsNeverRise() {
        let judging = config.judging
        #expect(judging.perfect.points >= judging.great.points)
        #expect(judging.great.points >= judging.good.points)
        #expect(judging.good.points > 0)
        #expect(judging.perfect.accuracyBasisPoints == 10_000)
        #expect(judging.perfect.accuracyBasisPoints >= judging.great.accuracyBasisPoints)
        #expect(judging.great.accuracyBasisPoints >= judging.good.accuracyBasisPoints)
        #expect(judging.good.accuracyBasisPoints > 0)
    }

    @Test("A ghost tap resets the streak on every difficulty, and the bounce grace is a positive time")
    func ghostTapDefaults() {
        let judging = config.judging
        #expect(Difficulty.allCases.allSatisfy { judging.ghostTapPenalty[$0] == .resetStreak })
        #expect(judging.bounceGraceMicros > 0)
    }

    @Test("The multiplier tops out at 4, and at 8 with Hype")
    func multiplierCeiling() {
        #expect(config.scoring.sustainPointsPerBeat > 0)
        #expect(config.scoring.maxStreakMultiplier == 4)
        #expect(config.scoring.maxStreakMultiplier * config.hype.multiplier == 8)
    }

    @Test("The streak needed per multiplier step grows with difficulty")
    func streakStepsGrowWithDifficulty() {
        let steps = Difficulty.allCases.map { config.scoring.streakPerMultiplierStep[$0] }
        #expect(steps.allSatisfy { $0 > 0 })
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("The Hype meter fills in whole phrases and every chart can activate it")
    func hypeMeterIsConsistent() {
        let hype = config.hype
        let charts = config.charts
        #expect(hype.phraseGain > 0)
        #expect(hype.drainPerBeat > 0)
        #expect(hype.meterCapacity.isMultiple(of: hype.phraseGain))
        #expect(hype.meterCapacity.isMultiple(of: hype.drainPerBeat))
        #expect(hype.activationMinimum > 0)
        #expect(hype.activationMinimum <= hype.meterCapacity)
        #expect(charts.minPhrasesPerSong <= charts.maxPhrasesPerSong)
        #expect(charts.minPhrasesPerSong * hype.phraseGain >= hype.activationMinimum)
    }

    @Test("Star shares ascend on every difficulty and Gold sits one above the top star", arguments: Difficulty.allCases)
    func starSharesAscend(difficulty: Difficulty) {
        let stars = config.stars
        let shares = stars.sharesPercent[difficulty]
        #expect(shares.count == 5)
        #expect(shares.allSatisfy { (1...100).contains($0) })
        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 < $1 })
        #expect(stars.goldMinimumStars == shares.count)
        #expect(stars.goldStarValue == shares.count + 1)
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
        #expect(
            (highway.minScrollTimeMicros...highway.maxScrollTimeMicros).contains(highway.scrollTimeMicros[difficulty]))
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
        #expect(rule.minCrossLaneGapMicros > 0)
        #expect(rule.minCrossLaneGapMicros <= rule.minSameLaneGapMicros)
        #expect((0...100).contains(rule.maxChordNoteSharePercent))
        #expect((1...config.highway.laneCount).contains(rule.maxSimultaneousContacts))
        // A chord needs two fingers down at once.
        #expect(rule.maxChordNoteSharePercent == 0 || rule.maxSimultaneousContacts >= 2)
        #expect(rule.shortestHold.numerator > 0)
        #expect(rule.shortestHold.denominator > 0)
    }

    // Otherwise a skipped note captures the tap meant for the next one (D-054).
    @Test("The same-lane gap exceeds the Good window plus the Perfect window", arguments: Difficulty.allCases)
    func sameLaneGapExceedsTheHitWindows(difficulty: Difficulty) {
        let judging = config.judging
        let scale = Int64(judging.windowScalePercent[difficulty])
        let good = judging.good.windowMicros * scale / 100
        let perfect = judging.perfect.windowMicros * scale / 100
        #expect(config.charts.rules[difficulty].minSameLaneGapMicros > good + perfect)
    }

    @Test("Chart rules get denser, tighter and shorter-held as difficulty rises")
    func chartRulesScaleWithDifficulty() {
        let rules = Difficulty.allCases.map { config.charts.rules[$0] }
        for (easier, harder) in zip(rules, rules.dropFirst()) {
            #expect(easier.maxAverageMilliNotesPerSecond == harder.minAverageMilliNotesPerSecond)
            #expect(easier.maxPeakMilliNotesPerSecond < harder.maxPeakMilliNotesPerSecond)
            // Hard and Expert share the smallest gap the hit windows allow.
            #expect(easier.minSameLaneGapMicros >= harder.minSameLaneGapMicros)
            #expect(easier.minCrossLaneGapMicros > harder.minCrossLaneGapMicros)
            #expect(easier.maxChordNoteSharePercent < harder.maxChordNoteSharePercent)
            #expect(easier.maxSimultaneousContacts <= harder.maxSimultaneousContacts)
            #expect(
                easier.shortestHold.numerator * harder.shortestHold.denominator
                    >= harder.shortestHold.numerator * easier.shortestHold.denominator
            )
        }
        #expect(config.charts.rules.easy.maxChordNoteSharePercent == 0)
        #expect(config.charts.defaultTicksPerBeat > 0)
        #expect(config.charts.minHoldMicros > 0)
    }

    @Test("The shortest hold of every difficulty is a whole number of ticks at the default resolution")
    func shortestHoldsFitTheTickGrid() {
        for difficulty in Difficulty.allCases {
            let hold = config.charts.rules[difficulty].shortestHold
            #expect((config.charts.defaultTicksPerBeat * hold.numerator).isMultiple(of: hold.denominator))
        }
    }

    @Test("Chart-wide limits make sense together")
    func chartWideLimitsAreSane() {
        let charts = config.charts
        #expect(charts.maxTicksPerBeat >= charts.defaultTicksPerBeat)
        #expect(charts.minTempoMilliBPM > 0)
        #expect(charts.minTempoMilliBPM < charts.maxTempoMilliBPM)
        // A tick must last at least a microsecond, or two ticks could share a time (D-086).
        #expect(Int64(charts.maxTempoMilliBPM) * Int64(charts.maxTicksPerBeat) <= 60_000_000_000)
        #expect(charts.peakWindowMicros > 0)
        #expect(charts.minNotesPerPhrase > 0)
        #expect(charts.minBeatsAfterLastPhrase > 0)
        #expect((1...100).contains(charts.maxHypeCapacitySharePercent))
        #expect(Difficulty.allCases.map { charts.rules[$0].minBeatsBetweenChords } == [0, 1, 0, 0])
        #expect(config.songs.durationToleranceMicros >= 0)
        #expect(config.songs.durationToleranceMicros < config.songs.minDurationMicros)
    }

    @Test("Payload limits are positive and agree with each other")
    func payloadLimitsAreConsistent() {
        let payload = config.payload
        let limits = [
            payload.schemaVersion, payload.maxURLCharacters, payload.maxDuelEncodedBytes, payload.maxEntries,
            payload.maxDuelProposals, payload.maxRoundProposals, payload.maxDuelEntries,
            payload.maxNicknameCharacters, payload.maxNicknameBytes, payload.matchIDBytes, payload.playerIDBytes,
            payload.chartHashBytes, payload.maxSongIDBytes, payload.tagBytes,
        ]
        #expect(limits.allSatisfy { $0 > 0 })
        // Apple's documented limit for MSMessage.url is 5,000 characters.
        #expect(payload.maxURLCharacters <= 5_000)
        // Base64url turns every 3 bytes into 4 characters.
        #expect((payload.maxDuelEncodedBytes * 4 + 2) / 3 <= payload.maxURLCharacters)
        #expect((3...32).contains(payload.maxEntries))
        #expect((1...4).contains(payload.maxDuelProposals))
        #expect((1...8).contains(payload.maxRoundProposals))
        #expect((2...8).contains(payload.maxDuelEntries))
        #expect(payload.maxNicknameBytes >= payload.maxNicknameCharacters)
        #expect(payload.chartHashBytes <= SHA256.digestLength)
        #expect(payload.tagBytes <= SHA256.digestLength)
    }

    @Test("The integrity key is the SHA-256 of its documented label")
    func integrityKeyComesFromItsLabel() {
        let key = config.payload.integrityKeyV1
        #expect(key.count == SHA256.digestLength)
        #expect(key == SHA256.hash(Array("riff-match-integrity-key-v1".utf8)))
    }

    @Test("Match limits fit the one-byte fields that carry them")
    func matchLimitsFitTheWire() {
        #expect((1...255).contains(config.match.groupDeadlineHours))
        #expect((1...255).contains(config.match.maxTries))
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
        #expect(playback.inputGuardMicros > 0)
        #expect(playback.missDuckMinMicros > 0)
        #expect(playback.missDuckMinMicros < playback.missDuckMaxMicros)
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
            // UInt8 is the integrity key's bytes.
            let isWholeNumber = leaf.value is Int || leaf.value is Int64 || leaf.value is UInt8
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
