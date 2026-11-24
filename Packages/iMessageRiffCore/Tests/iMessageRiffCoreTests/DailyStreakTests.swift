import Testing
import iMessageRiffCore

@Suite("Daily streak")
struct DailyStreakTests {
    @Test("A local day is credited once and consecutive days advance the streak")
    func consecutiveDays() throws {
        var streak = DailyStreak()
        let first = try streak.record(utcSeconds: 0, offsetSeconds: 0, config: .standard)
        #expect(first.firstRunOfDay && first.days == 1)
        let second = try streak.record(utcSeconds: 86_400, offsetSeconds: 0, config: .standard)
        #expect(second.firstRunOfDay && second.days == 2)
        let repeatRun = try streak.record(utcSeconds: 86_500, offsetSeconds: 0, config: .standard)
        #expect(!repeatRun.firstRunOfDay && repeatRun.days == 2)
    }

    @Test("Eastward travel can skip a local day without breaking the streak")
    func travelGrace() throws {
        var streak = DailyStreak()
        let start: Int64 = 10 * 86_400 + 23 * 3_600
        _ = try streak.record(utcSeconds: start, offsetSeconds: 0, config: .standard)
        let next = try streak.record(utcSeconds: start + 25 * 3_600, offsetSeconds: 9 * 3_600, config: .standard)
        #expect(next.firstRunOfDay && next.days == 2 && next.usedTravelGrace)
    }

    @Test("A gap at the exact travel-grace limit resets the streak")
    func exactGraceLimit() throws {
        var streak = DailyStreak()
        _ = try streak.record(utcSeconds: 10 * 86_400, offsetSeconds: 0, config: .standard)
        let result = try streak.record(utcSeconds: 12 * 86_400, offsetSeconds: 0, config: .standard)
        #expect(result.firstRunOfDay && result.days == 1 && !result.usedTravelGrace)
    }

    @Test("Westward travel cannot award an already credited day twice")
    func westwardTravel() throws {
        var streak = DailyStreak()
        let start: Int64 = 10 * 86_400 + 3_600
        _ = try streak.record(utcSeconds: start, offsetSeconds: 14 * 3_600, config: .standard)
        let previousDay = try streak.record(
            utcSeconds: start + 3_600, offsetSeconds: -12 * 3_600, config: .standard)
        #expect(!previousDay.firstRunOfDay)
        let sameDay = try streak.record(
            utcSeconds: start + 7_200, offsetSeconds: 14 * 3_600, config: .standard)
        #expect(!sameDay.firstRunOfDay)
        let newDay = try streak.record(
            utcSeconds: start + 11 * 3_600, offsetSeconds: 14 * 3_600, config: .standard)
        #expect(newDay.firstRunOfDay && newDay.days == 2)
    }

    @Test("A backward UTC clock cannot gain credit even when the offset advances the local day")
    func clockBackwards() throws {
        var streak = DailyStreak()
        let start: Int64 = 10 * 86_400 + 3_600
        _ = try streak.record(utcSeconds: start, offsetSeconds: -12 * 3_600, config: .standard)
        let result = try streak.record(utcSeconds: start - 1, offsetSeconds: 14 * 3_600, config: .standard)
        #expect(result.clockWentBack && !result.firstRunOfDay && result.days == 1)
    }

    @Test("Local days before the Unix epoch round down")
    func negativeDay() throws {
        var streak = DailyStreak()
        _ = try streak.record(utcSeconds: -1, offsetSeconds: 0, config: .standard)
        let result = try streak.record(utcSeconds: 0, offsetSeconds: 0, config: .standard)
        #expect(result.firstRunOfDay && result.days == 2)
    }
}
