private protocol Rankable {
    var playerID: UInt64 { get }
    var score: UInt32 { get }
    var accuracy: UInt16 { get }
    var longestStreak: UInt32 { get }
    var tries: UInt8 { get }
    var finishedAt: UInt32 { get }
}

extension MatchEntry: Rankable {}
extension MatchShortEntry: Rankable {}

/// Total ranking for distinct players, using only transmitted integer fields.
public enum MatchRanking {
    public static func ranked(_ entries: [MatchEntry]) throws -> [MatchEntry] {
        try rank(entries)
    }

    public static func ranked(_ entries: [MatchShortEntry]) throws -> [MatchShortEntry] {
        try rank(entries)
    }

    private static func rank<T: Rankable>(_ entries: [T]) throws -> [T] {
        let ids = entries.map(\.playerID).sorted()
        for (left, right) in zip(ids, ids.dropFirst()) where left == right {
            throw MatchModelError.duplicatePlayer(left)
        }
        return entries.sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            if left.accuracy != right.accuracy { return left.accuracy > right.accuracy }
            if left.longestStreak != right.longestStreak { return left.longestStreak > right.longestStreak }
            if left.tries != right.tries { return left.tries < right.tries }
            if left.finishedAt != right.finishedAt { return left.finishedAt < right.finishedAt }
            return left.playerID < right.playerID
        }
    }
}
