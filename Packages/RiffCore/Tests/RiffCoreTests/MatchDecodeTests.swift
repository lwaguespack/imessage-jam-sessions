import RiffCore
import Testing

@Suite("Match decode pipeline")
struct MatchDecodeTests {
    private struct Row: Sendable {
        let song: String
        let part: Part
        let difficulty: Difficulty
        let bounds: MatchChartBounds
    }

    private struct Catalogue: MatchChartLookup {
        let rows: [Row]

        func bounds(songID: String, part: Part, difficulty: Difficulty) -> MatchChartBounds? {
            rows.first { $0.song == songID && $0.part == part && $0.difficulty == difficulty }?.bounds
        }
    }

    private let config = GameConfig.standard

    private func chart(_ song: String = "song", hash: UInt32 = 42) throws -> MatchChart {
        try MatchChart(songID: song, part: .lead, difficulty: .expert, chartHash: hash, config: config)
    }

    private func entry(
        _ id: UInt64, score: UInt32 = 900, streak: UInt32 = 100, combo: FullComboStatus = .yes
    ) throws -> MatchEntry {
        try MatchEntry(
            playerID: id, nickname: "Player", score: score, accuracy: 10_000, longestStreak: streak,
            tries: 1, level: 1, titleID: 0, frameID: 0, fullCombo: combo, finishedAt: 90, config: config)
    }

    private func state(
        entries: [MatchEntry], rules: UInt32 = 3, revision: UInt32 = 1,
        history: MatchHistory? = nil, round: UInt32 = 1
    ) throws -> MatchState {
        let descriptor = try MatchDescriptor(
            chart: chart(), starter: 1, startTime: 100, rosterSize: 3, deadlineHours: 24,
            mode: .round, config: config)
        return try MatchState(
            matchID: 1, mode: .round, rulesVersion: rules, contentRevision: revision, round: round,
            history: history ?? MatchHistory(), proposals: [MatchProposal(descriptor: descriptor, entries: entries)],
            config: config)
    }

    private func url(_ state: MatchState) throws -> String {
        try MatchURL.make(payload: PayloadCodec.encode(state, config: config), form: .data, config: config)
    }

    private func catalogue(hash: UInt32 = 42) throws -> Catalogue {
        Catalogue(rows: [
            Row(
                song: "song", part: .lead, difficulty: .expert,
                bounds: try MatchChartBounds(chartHash: hash, noteCount: 100, scoreCeiling: 1_000))
        ])
    }

    @Test("Valid payloads survive all stages")
    func valid() throws {
        let match = try state(entries: [entry(1)])
        let result = try MatchDecode.decode(url(match), config: config, contentRevision: 1, catalogue: catalogue())
        #expect(result == .valid(match, warnings: []))
    }

    @Test("Version outcomes precede catalogue lookup")
    func versionOrdering() throws {
        let empty = Catalogue(rows: [])
        let newer = try state(entries: [], rules: 4)
        let older = try state(entries: [], rules: 2)
        #expect(
            try MatchDecode.decode(url(newer), config: config, contentRevision: 1, catalogue: empty)
                == .updateNeeded)
        #expect(
            try MatchDecode.decode(url(older), config: config, contentRevision: 1, catalogue: empty)
                == .askSenderToUpdate)
        let future = try MatchURL.make(payload: [3], form: .data, config: config)
        #expect(
            try MatchDecode.decode(future, config: config, contentRevision: 1, catalogue: empty)
                == .updateNeeded)
    }

    @Test("Unknown charts, hash mismatches and corrupt tags have distinct outcomes")
    func failures() throws {
        let match = try state(entries: [entry(1)])
        let input = try url(match)
        let expectedChart = try chart()
        #expect(
            try MatchDecode.decode(input, config: config, contentRevision: 1, catalogue: Catalogue(rows: []))
                == .unreadable(.unknownChart(expectedChart)))
        #expect(
            try MatchDecode.decode(input, config: config, contentRevision: 1, catalogue: catalogue(hash: 43))
                == .unreadable(.chartHashMismatch(expectedChart)))
        var bytes = try PayloadCodec.encode(match, config: config)
        bytes[bytes.count - 1] ^= 1
        let damaged = try MatchURL.make(payload: bytes, form: .data, config: config)
        #expect(
            try MatchDecode.decode(damaged, config: config, contentRevision: 1, catalogue: catalogue())
                == .unreadable(.payload(.invalidTag)))
    }

    @Test("Invalid scores, streaks and Full Combo claims drop only those entries")
    func dropsBadEntries() throws {
        let match = try state(entries: [
            entry(4, streak: 99), entry(2, score: 1_001), entry(1), entry(3, streak: 101, combo: .no),
        ])
        let result = try MatchDecode.decode(url(match), config: config, contentRevision: 1, catalogue: catalogue())
        guard case .valid(let filtered, let warnings) = result else {
            Issue.record("Expected a valid match with dropped entries")
            return
        }
        #expect(filtered.winningEntries.map(\.playerID) == [1])
        #expect(
            warnings == [
                .entryDropped(location: .proposal(0), playerID: 2, reason: .scoreAboveCeiling),
                .entryDropped(location: .proposal(0), playerID: 3, reason: .streakAboveNoteCount),
                .entryDropped(location: .proposal(0), playerID: 4, reason: .inconsistentFullCombo),
            ])
    }

    @Test("Previous-round entries use the previous chart's bounds")
    func previousChart() throws {
        let oldChart = try chart("old-song", hash: 77)
        let old = try MatchShortEntry(entry(2, score: 900, streak: 100))
        let history = try MatchHistory(previousChart: oldChart, previous: [old])
        let match = try state(entries: [entry(1)], history: history, round: 2)
        #expect(
            try MatchDecode.decode(url(match), config: config, contentRevision: 1, catalogue: catalogue())
                == .unreadable(.unknownChart(oldChart)))

        let rows =
            try catalogue().rows + [
                Row(
                    song: "old-song", part: .lead, difficulty: .expert,
                    bounds: MatchChartBounds(chartHash: 77, noteCount: 100, scoreCeiling: 500))
            ]
        let result = try MatchDecode.decode(
            url(match), config: config, contentRevision: 1, catalogue: Catalogue(rows: rows))
        guard case .valid(let filtered, let warnings) = result else {
            Issue.record("Expected a valid match with a dropped previous entry")
            return
        }
        #expect(filtered.history.previous.isEmpty)
        #expect(filtered.history.previousChart == nil)
        #expect(warnings == [.entryDropped(location: .previous, playerID: 2, reason: .scoreAboveCeiling)])
    }

    @Test("An unknown previous chart is checked even when its entry was structurally dropped")
    func droppedPreviousStillChecksChart() throws {
        let oldChart = try chart("old-song", hash: 77)
        let old = try MatchShortEntry(entry(2, score: 900, streak: 100))
        let history = try MatchHistory(previousChart: oldChart, previous: [old])
        let match = try state(entries: [entry(1)], history: history, round: 2)
        var body = Array(try PayloadCodec.encode(match, config: config).dropLast(8))
        let name = Array("old-song".utf8)
        let index = try #require(
            body.indices.first { index in
                index + name.count <= body.count && Array(body[index..<(index + name.count)]) == name
            })
        let accuracyByte = index + name.count + 6 + 1 + 8 + 2
        #expect(body[accuracyByte] == 0x90)
        body[accuracyByte] = 0x91
        let tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v2".utf8) + body, key: config.payload.integrityKeyV2)
        let input = try MatchURL.make(payload: body + tag.prefix(8), form: .data, config: config)
        #expect(
            try MatchDecode.decode(input, config: config, contentRevision: 1, catalogue: catalogue())
                == .unreadable(.unknownChart(oldChart)))
    }
}
