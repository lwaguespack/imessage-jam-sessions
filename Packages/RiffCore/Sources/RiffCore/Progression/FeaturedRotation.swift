/// A fixed UTC week index selects from an explicitly ordered song schedule.
public struct FeaturedRotation: Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case emptySchedule
        case invalidSongID
        case overflow
    }

    private let schedule: [String]
    private let epoch: Int64

    public init(schedule: [String], config: GameConfig) throws {
        guard !schedule.isEmpty else { throw Error.emptySchedule }
        guard schedule.allSatisfy({ SongID.isValid($0, maxBytes: config.payload.maxSongIDBytes) }) else {
            throw Error.invalidSongID
        }
        self.schedule = schedule
        epoch = config.xp.featuredEpochUnixSeconds
    }

    public func weekIndex(at utcSeconds: Int64) throws -> Int64 {
        let (difference, overflow) = utcSeconds.subtractingReportingOverflow(epoch)
        guard !overflow else { throw Error.overflow }
        return IntegerMath.floorDivide(difference, by: 604_800)
    }

    public func song(at utcSeconds: Int64) throws -> String {
        let week = try weekIndex(at: utcSeconds)
        let count = Int64(schedule.count)
        let remainder = week % count
        let index = remainder >= 0 ? remainder : remainder + count
        return schedule[Int(index)]
    }
}
