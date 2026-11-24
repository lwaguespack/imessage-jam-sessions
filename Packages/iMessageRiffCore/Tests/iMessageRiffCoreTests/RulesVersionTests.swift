import Foundation
import Testing
import iMessageRiffCore

@Suite("Rules version")
struct RulesVersionTests {
    /// The values that can change a score or a star count, in the form the digest is taken over.
    private struct ScoringRules: Encodable {
        var rulesVersion: Int
        var inputGuardMicros: Int64
        var judging: GameConfig.Judging
        var scoring: GameConfig.Scoring
        var hype: GameConfig.Hype
        var stars: GameConfig.Stars

        init(_ config: GameConfig) {
            rulesVersion = config.rulesVersion
            inputGuardMicros = config.playback.inputGuardMicros
            judging = config.judging
            scoring = config.scoring
            hype = config.hype
            stars = config.stars
        }
    }

    private static let pinnedVersion = 3
    private static let pinnedDigest = "df5600ddbcee27e07fa5633e6278d388e3dc73085479bcecff4eec719a839c57"

    /// SHA-256, in hex, of the canonical JSON of the scoring values.
    private func digest(of config: GameConfig) throws -> String {
        Hex.encode(SHA256.hash(Array(try CanonicalJSON.encode(ScoringRules(config)))))
    }

    @Test("The scoring values are the ones pinned to the current rules version")
    func scoringValuesMatchThePin() throws {
        #expect(GameConfig.standard.rulesVersion == Self.pinnedVersion)
        #expect(
            try digest(of: .standard) == Self.pinnedDigest,
            "A scoring value changed: bump GameConfig.rulesVersion, then pin the new version and digest here."
        )
    }

    @Test("The digest changes with the version and with each kind of scoring value")
    func digestCoversScoringValues() throws {
        let edits: [(inout GameConfig) -> Void] = [
            { $0.rulesVersion += 1 },
            { $0.playback.inputGuardMicros += 1 },
            { $0.judging.great.windowMicros += 1 },
            { $0.judging.windowScalePercent.easy += 1 },
            { $0.judging.ghostTapPenalty.easy = .none },
            { $0.judging.bounceGraceMicros += 1 },
            { $0.scoring.streakPerMultiplierStep.hard += 1 },
            { $0.scoring.sustainPointsPerBeat += 1 },
            { $0.hype.phraseGain += 1 },
            { $0.stars.sharesPercent.expert[4] += 1 },
        ]
        let standard = try digest(of: .standard)
        for edit in edits {
            var config = GameConfig.standard
            edit(&config)
            #expect(try digest(of: config) != standard)
        }
    }

    @Test("Values outside the scoring groups and input guard do not move the digest")
    func digestLeavesOutOtherGroups() throws {
        var config = GameConfig.standard
        config.highway.scrollTimeMicros.easy += 1
        config.playback.missDuckMinMicros += 1
        config.payload.maxEntries += 1
        config.match.maxTries -= 1
        config.xp.finishRun += 1
        config.charts.rules.easy.minSameLaneGapMicros += 1
        config.songs.maxDurationMicros += 1
        #expect(try digest(of: config) == Self.pinnedDigest)
    }
}
