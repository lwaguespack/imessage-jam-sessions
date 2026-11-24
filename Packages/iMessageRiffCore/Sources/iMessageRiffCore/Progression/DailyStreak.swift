/// Local-day streak state; all time and UTC-offset inputs are supplied by the caller.
public struct DailyStreak: Codable, Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case invalidOffset
        case invalidState
        case overflow
    }

    public struct Update: Equatable, Sendable {
        public let days: Int
        public let firstRunOfDay: Bool
        public let usedTravelGrace: Bool
        public let clockWentBack: Bool
    }

    public private(set) var days = 0
    public private(set) var lastRunUTC: Int64?
    public private(set) var lastLocalDay: Int64?
    public private(set) var highWaterDay: Int64?

    public init() {}

    public mutating func record(utcSeconds: Int64, offsetSeconds: Int, config: GameConfig) throws -> Update {
        guard config.xp.dailyTravelGraceSeconds > 0 else { throw Error.invalidConfiguration }
        guard (-86_400...86_400).contains(offsetSeconds) else { throw Error.invalidOffset }
        let (localSeconds, overflow) = utcSeconds.addingReportingOverflow(Int64(offsetSeconds))
        guard !overflow else { throw Error.overflow }
        let day = IntegerMath.floorDivide(localSeconds, by: 86_400)

        guard let lastRunUTC else {
            guard days == 0, lastLocalDay == nil, highWaterDay == nil else { throw Error.invalidState }
            days = 1
            self.lastRunUTC = utcSeconds
            lastLocalDay = day
            highWaterDay = day
            return Update(days: days, firstRunOfDay: true, usedTravelGrace: false, clockWentBack: false)
        }
        guard days > 0, let lastLocalDay, let highWaterDay, lastLocalDay <= highWaterDay else {
            throw Error.invalidState
        }
        if utcSeconds < lastRunUTC {
            return Update(days: days, firstRunOfDay: false, usedTravelGrace: false, clockWentBack: true)
        }
        if day <= highWaterDay {
            self.lastRunUTC = utcSeconds
            self.lastLocalDay = day
            return Update(days: days, firstRunOfDay: false, usedTravelGrace: false, clockWentBack: false)
        }

        let (gap, gapOverflow) = day.subtractingReportingOverflow(highWaterDay)
        let (elapsed, timeOverflow) = utcSeconds.subtractingReportingOverflow(lastRunUTC)
        guard !gapOverflow, !timeOverflow else { throw Error.overflow }
        let grace = gap > 1 && elapsed < config.xp.dailyTravelGraceSeconds
        if gap == 1 || grace {
            let (next, countOverflow) = days.addingReportingOverflow(1)
            guard !countOverflow else { throw Error.overflow }
            days = next
        } else {
            days = 1
        }
        self.lastRunUTC = utcSeconds
        self.lastLocalDay = day
        self.highWaterDay = day
        return Update(days: days, firstRunOfDay: true, usedTravelGrace: grace, clockWentBack: false)
    }
}
