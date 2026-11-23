import Foundation

/// Validated, explicitly ordered progression data supplied by the caller.
public struct Unlocks: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidFormat
        case unsupportedVersion(Int)
        case invalidConfiguration
        case invalidDefaults
        case invalidLevels
        case missingGuaranteedReward(Int)
        case invalidReward(String)
        case duplicateReward(String)
        case incorrectCount(String)
        case invalidLevel(Int)
    }

    private struct File: Decodable {
        struct Level: Decodable {
            let level: Int
            let rewards: [String]
        }

        let format: String
        let version: Int
        let defaults: [String: String]
        let featuredSchedule: [String]
        let levels: [Level]
    }

    public let defaults: [String]
    public let featuredSchedule: [String]
    public let maxLevel: Int
    private let levels: [[String]]

    public init(data: Data, config: GameConfig) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.format == "riff-progression" else { throw Error.invalidFormat }
        guard file.version == 1 else { throw Error.unsupportedVersion(file.version) }
        let kinds = [
            ("title", config.unlocks.titles), ("frame", config.unlocks.scoreCardFrames),
            ("skin", config.unlocks.noteSkins), ("theme", config.unlocks.highwayThemes),
            ("effect", config.unlocks.strikeLineEffects),
        ]
        let maximum = config.levels.maxLevel
        let first = config.unlocks.guaranteedFromLevel
        let last = config.unlocks.guaranteedThroughLevel
        guard maximum >= 1, kinds.allSatisfy({ $0.1 >= 0 }), first >= 1, first <= last, last <= maximum else {
            throw Error.invalidConfiguration
        }
        guard file.defaults.count == kinds.count else { throw Error.invalidDefaults }
        guard file.levels.count == maximum,
            file.levels.enumerated().allSatisfy({ $0.element.level == $0.offset + 1 }),
            file.levels[0].rewards.isEmpty
        else { throw Error.invalidLevels }
        if !file.featuredSchedule.isEmpty {
            _ = try FeaturedRotation(schedule: file.featuredSchedule, config: config)
        }

        var seen = Set<String>()
        var defaults: [String] = []
        for (kind, _) in kinds {
            guard let id = file.defaults[kind], Self.kind(of: id) == kind else {
                throw Error.invalidDefaults
            }
            guard seen.insert(id).inserted else { throw Error.duplicateReward(id) }
            defaults.append(id)
        }

        var counts = [Int](repeating: 0, count: kinds.count)
        for level in file.levels {
            if (first...last).contains(level.level), level.rewards.isEmpty {
                throw Error.missingGuaranteedReward(level.level)
            }
            for id in level.rewards {
                guard let kind = Self.kind(of: id), let index = kinds.firstIndex(where: { $0.0 == kind }) else {
                    throw Error.invalidReward(id)
                }
                guard seen.insert(id).inserted else { throw Error.duplicateReward(id) }
                counts[index] += 1
            }
        }
        for index in kinds.indices where counts[index] != kinds[index].1 {
            throw Error.incorrectCount(kinds[index].0)
        }
        self.defaults = defaults
        featuredSchedule = file.featuredSchedule
        maxLevel = maximum
        levels = file.levels.map(\.rewards)
    }

    public func rewards(at level: Int) throws -> [String] {
        guard (1...maxLevel).contains(level) else { throw Error.invalidLevel(level) }
        return levels[level - 1]
    }

    public func earned(through level: Int) throws -> [String] {
        guard (1...maxLevel).contains(level) else { throw Error.invalidLevel(level) }
        return defaults + levels.prefix(level).flatMap { $0 }
    }

    static func kind(of id: String) -> String? {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty,
            parts[0].utf8.allSatisfy({ (97...122).contains($0) }),
            parts[1].utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 })
        else { return nil }
        return String(parts[0])
    }
}
