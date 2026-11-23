import Foundation
import RiffCore
import Testing

@Suite("Unlocks and profile")
struct UnlocksAndProfileTests {
    private func catalogueText() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        return try String(
            contentsOf: root.appendingPathComponent("RiffMessages/Resources/progression.json"), encoding: .utf8)
    }

    private func catalogue() throws -> Unlocks {
        try Unlocks(data: Data(catalogueText().utf8), config: .standard)
    }

    @Test("The catalogue defines every level and the configured rewards")
    func completeCatalogue() throws {
        let unlocks = try catalogue()
        #expect(unlocks.defaults.count == 5)
        #expect(unlocks.featuredSchedule.isEmpty)
        #expect(try unlocks.rewards(at: 1).isEmpty)
        for level in 2...10 { #expect(try !unlocks.rewards(at: level).isEmpty) }
        for level in 1...50 { _ = try unlocks.rewards(at: level) }
        let all = try unlocks.earned(through: 50)
        #expect(all.count == 45)
        #expect(Set(all).count == 45)
    }

    @Test("Missing levels, duplicated rewards and missing guaranteed rewards are rejected")
    func rejectsBrokenCatalogue() throws {
        let text = try catalogueText()
        let duplicateLevel = text.replacingOccurrences(of: "\"level\": 50", with: "\"level\": 49")
        #expect(throws: Unlocks.Error.invalidLevels) {
            try Unlocks(data: Data(duplicateLevel.utf8), config: .standard)
        }
        let duplicateReward = text.replacingOccurrences(of: "\"frame.01\"", with: "\"title.01\"")
        #expect(throws: Unlocks.Error.duplicateReward("title.01")) {
            try Unlocks(data: Data(duplicateReward.utf8), config: .standard)
        }
        let emptyEarlyLevel = text.replacingOccurrences(of: "\"rewards\": [\"title.01\"]", with: "\"rewards\": []")
        #expect(throws: Unlocks.Error.missingGuaranteedReward(2)) {
            try Unlocks(data: Data(emptyEarlyLevel.utf8), config: .standard)
        }
    }

    @Test("Counter maxima merge idempotently and grant rewards at the merged level")
    func profileMerge() throws {
        let unlocks = try catalogue()
        var a = Profile(profileID: 1, unlocks: unlocks)
        var b = Profile(profileID: 1, unlocks: unlocks)
        try a.addXP(700, installationID: 10, unlocks: unlocks, config: .standard)
        try b.addXP(700, installationID: 20, unlocks: unlocks, config: .standard)
        let ab = try a.merging(b, unlocks: unlocks, config: .standard)
        let ba = try b.merging(a, unlocks: unlocks, config: .standard)
        #expect(ab == ba)
        #expect(try ab.merging(ab, unlocks: unlocks, config: .standard) == ab)
        #expect(try ab.totalXP() == 1_400)
        #expect(try ab.level(config: .standard) == 3)
        #expect(ab.unlocked.contains("title.01"))
        #expect(ab.unlocked.contains("frame.01"))
        #expect(ab.counters.map(\.installationID) == [10, 20])
        var c = Profile(profileID: 1, unlocks: unlocks)
        try c.addXP(800, installationID: 30, unlocks: unlocks, config: .standard)
        #expect(
            try ab.merging(c, unlocks: unlocks, config: .standard)
                == a.merging(b.merging(c, unlocks: unlocks, config: .standard), unlocks: unlocks, config: .standard))
    }

    @Test("A stale counter cannot double-credit XP and different profile IDs do not merge")
    func staleCounterAndIdentity() throws {
        let unlocks = try catalogue()
        var current = Profile(profileID: 1, unlocks: unlocks)
        try current.addXP(300, installationID: 10, unlocks: unlocks, config: .standard)
        let stale = current
        try current.addXP(250, installationID: 10, unlocks: unlocks, config: .standard)
        let merged = try current.merging(stale, unlocks: unlocks, config: .standard)
        #expect(try merged.totalXP() == 550)
        let other = Profile(profileID: 2, unlocks: unlocks)
        #expect(throws: Profile.Error.differentProfile) {
            try current.merging(other, unlocks: unlocks, config: .standard)
        }
        #expect(throws: Profile.Error.invalidXP) {
            try current.addXP(-1, installationID: 10, unlocks: unlocks, config: .standard)
        }
        var maximum = Profile(profileID: 3, unlocks: unlocks)
        try maximum.addXP(.max, installationID: 10, unlocks: unlocks, config: .standard)
        #expect(throws: Profile.Error.overflow) {
            try maximum.addXP(1, installationID: 10, unlocks: unlocks, config: .standard)
        }
        #expect(try maximum.totalXP() == .max)
    }

    @Test("Profiles encode and decode in deterministic counter and unlock order")
    func profileRoundTrip() throws {
        let unlocks = try catalogue()
        var profile = Profile(profileID: .max, unlocks: unlocks)
        try profile.addXP(200, installationID: 20, unlocks: unlocks, config: .standard)
        try profile.addXP(400, installationID: .max, unlocks: unlocks, config: .standard)
        let data = try CanonicalJSON.encode(profile)
        #expect(try JSONDecoder().decode(Profile.self, from: data) == profile)
        #expect(profile.counters.map(\.installationID) == [20, .max])
        #expect(profile.unlocked == profile.unlocked.sorted())
        let uppercase = try #require(String(data: data, encoding: .utf8))
            .replacingOccurrences(of: "ffffffffffffffff", with: "FFFFFFFFFFFFFFFF")
        #expect(throws: Profile.Error.invalidState) {
            try JSONDecoder().decode(Profile.self, from: Data(uppercase.utf8))
        }
    }
}
