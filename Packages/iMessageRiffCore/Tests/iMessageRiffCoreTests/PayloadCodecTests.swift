import Foundation
import Testing

@testable import iMessageRiffCore

@Suite("Match payload codec")
struct PayloadCodecTests {
    private let config = GameConfig.standard

    private func vector(_ version: Int) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/payload-v\(version).txt")
        return try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func expectedState() throws -> MatchState {
        let player: UInt64 = 0x0102_0304_0506_0708
        let chart = try MatchChart(
            songID: "song", part: .lead, difficulty: .expert, chartHash: 0x1234_5678, config: config)
        let descriptor = try MatchDescriptor(
            chart: chart, starter: player, startTime: 100_000, rosterSize: 3, deadlineHours: 24,
            mode: .round, config: config)
        let entry = try MatchEntry(
            playerID: player, nickname: "Sam", score: 12_345, accuracy: 10_000, longestStreak: 42,
            tries: 1, level: 2, titleID: 0, frameID: 0, fullCombo: .yes, finishedAt: 99_990, config: config)
        return try MatchState(
            matchID: player, mode: .round, rulesVersion: 3, contentRevision: 1, round: 1,
            history: MatchHistory(), proposals: [MatchProposal(descriptor: descriptor, entries: [entry])],
            config: config)
    }

    @Test("Version 2 matches an independently generated golden vector")
    func currentGolden() throws {
        let state = try expectedState()
        let bytes = try PayloadCodec.encode(state, config: config)
        #expect(try Base64URL.encode(bytes) == vector(2))
        let decoded = try PayloadCodec.decode(bytes, config: config)
        #expect(decoded.wireVersion == 2)
        #expect(decoded.state == state)
        #expect(decoded.warnings.isEmpty)
    }

    @Test("The version-1 group fixture decodes with unknown Full Combo")
    func previousVersion() throws {
        let legacy = try vector(1)
        let decoded = try PayloadCodec.decode(Base64URL.decode(legacy), config: config)
        #expect(decoded.wireVersion == 1)
        #expect(decoded.state.rulesVersion == 2)
        #expect(decoded.state.winningProposal.descriptor.startTime == 100_000)
        #expect(decoded.state.winningEntries[0].finishedAt == 100_010)
        #expect(decoded.state.winningEntries[0].fullCombo == .unknown)

        var unsupported = Array(try Base64URL.decode(legacy).dropLast(8))
        unsupported[9] = 0
        let tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v1".utf8) + unsupported, key: config.payload.integrityKeyV1)
        #expect(throws: PayloadCodec.Failure.unsupportedLegacy) {
            try PayloadCodec.decode(unsupported + tag.prefix(8), config: config)
        }
    }

    @Test("An unknown newer version is recognized before tag parsing")
    func newerVersion() {
        #expect(throws: PayloadCodec.Failure.newerVersion(3)) {
            try PayloadCodec.decode([3], config: config)
        }
    }

    @Test("Every byte mutation and every truncation is rejected")
    func tampering() throws {
        let bytes = try PayloadCodec.encode(expectedState(), config: config)
        for index in bytes.indices {
            var changed = bytes
            changed[index] ^= 1
            #expect(throws: PayloadCodec.Failure.self) { try PayloadCodec.decode(changed, config: config) }
        }
        for count in 0..<bytes.count {
            #expect(throws: PayloadCodec.Failure.self) {
                try PayloadCodec.decode(Array(bytes.prefix(count)), config: config)
            }
        }
    }

    @Test("An authenticated non-canonical varint is rejected")
    func nonCanonicalVarint() throws {
        let bytes = try PayloadCodec.encode(expectedState(), config: config)
        var body = Array(bytes.dropLast(8))
        body.replaceSubrange(10...10, with: [0x83, 0x00])
        let tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v2".utf8) + body, key: config.payload.integrityKeyV2)
        #expect(throws: PayloadCodec.Failure.nonCanonicalVarint) {
            try PayloadCodec.decode(body + tag.prefix(8), config: config)
        }
    }

    @Test("An invalid received nickname is replaced and reported")
    func nicknameRepair() throws {
        let bytes = try PayloadCodec.encode(expectedState(), config: config)
        var body = Array(bytes.dropLast(8))
        let index = try #require(
            body.indices.first { index in
                index + 3 <= body.count && Array(body[index..<(index + 3)]) == Array("Sam".utf8)
            })
        body.replaceSubrange(index..<(index + 3), with: [65, 10, 66])
        let tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v2".utf8) + body, key: config.payload.integrityKeyV2)
        let decoded = try PayloadCodec.decode(body + tag.prefix(8), config: config)
        #expect(decoded.state.winningEntries[0].nickname == "Player")
        #expect(
            decoded.warnings == [
                .nicknameReplaced(proposalIndex: 0, playerID: 0x0102_0304_0506_0708, reason: .forbiddenScalar(10))
            ])

        body.replaceSubrange(index..<(index + 3), with: [0xFF, 0xFF, 0xFF])
        let invalidUTF8Tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v2".utf8) + body, key: config.payload.integrityKeyV2)
        let invalidUTF8 = try PayloadCodec.decode(body + invalidUTF8Tag.prefix(8), config: config)
        #expect(invalidUTF8.state.winningEntries[0].nickname == "Player")
        #expect(
            invalidUTF8.warnings == [
                .nicknameReplaced(proposalIndex: 0, playerID: 0x0102_0304_0506_0708, reason: .invalidUTF8)
            ])
    }

    @Test("A structurally valid entry with invalid accuracy is dropped, not the match")
    func invalidEntryIsDropped() throws {
        let bytes = try PayloadCodec.encode(expectedState(), config: config)
        var body = Array(bytes.dropLast(8))
        let index = try #require(
            body.indices.first { index in
                index + 3 <= body.count && Array(body[index..<(index + 3)]) == Array("Sam".utf8)
            })
        body[index + 5] = 0x91
        let tag = HMACSHA256.authenticationCode(
            for: Array("riff-match-v2".utf8) + body, key: config.payload.integrityKeyV2)
        let decoded = try PayloadCodec.decode(body + tag.prefix(8), config: config)
        #expect(decoded.state.winningEntries.isEmpty)
        #expect(
            decoded.warnings == [
                .entryDropped(proposalIndex: 0, playerID: 0x0102_0304_0506_0708, reason: .invalidAccuracy)
            ])
    }

    @Test("Maximum-size states stay within the documented binary and URL bounds")
    func maximumSizes() throws {
        func maximumState(mode: MatchMode) throws -> MatchState {
            let song = String(repeating: "s", count: 24)
            let chart = try MatchChart(songID: song, part: .lead, difficulty: .expert, chartHash: .max, config: config)
            let count = mode == .duel ? 4 : 8
            let perProposal = mode == .duel ? 2 : 4
            var proposals: [MatchProposal] = []
            var allEntries: [MatchEntry] = []
            for index in 0..<count {
                let descriptor = try MatchDescriptor(
                    chart: chart, starter: UInt64.max - UInt64(index), startTime: UInt32.max - UInt32(index),
                    rosterSize: mode == .duel ? 2 : 32, deadlineHours: mode == .duel ? 0 : 255,
                    mode: mode, config: config)
                var entries: [MatchEntry] = []
                for offset in 0..<perProposal {
                    let entry = try MatchEntry(
                        playerID: UInt64.max - UInt64(index * perProposal + offset),
                        nickname: String(repeating: "é", count: 16), score: .max, accuracy: 10_000,
                        longestStreak: .max, tries: 99, level: 50, titleID: 15, frameID: 6,
                        fullCombo: .yes, finishedAt: .max, config: config)
                    entries.append(entry)
                    allEntries.append(entry)
                }
                proposals.append(
                    try MatchProposal(descriptor: descriptor, closedAt: mode == .duel ? nil : .max, entries: entries))
            }
            let series: [MatchHistory.SeriesWin] =
                mode == .duel
                ? [.init(playerID: .max, wins: .max), .init(playerID: UInt64.max - 1, wins: .max)] : []
            let previous = allEntries.prefix(mode == .duel ? 2 : 3).map(MatchShortEntry.init)
            let history = try MatchHistory(series: series, previousChart: chart, previous: previous)
            return try MatchState(
                matchID: .max, mode: mode, rulesVersion: .max, contentRevision: .max, round: .max,
                history: history, proposals: proposals, config: config)
        }

        for mode in [MatchMode.duel, .round] {
            let state = try maximumState(mode: mode)
            let bytes = try PayloadCodec.encode(state, config: config)
            #expect(bytes.count <= (mode == .duel ? 887 : 2_607))
            let url = "https://riff.invalid/m?p=" + Base64URL.encode(bytes)
            #expect(url.utf8.count <= config.payload.maxURLCharacters)
            #expect(try PayloadCodec.decode(bytes, config: config).state == state)
        }
    }
}
