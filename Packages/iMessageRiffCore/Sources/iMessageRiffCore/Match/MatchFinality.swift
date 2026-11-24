/// Evaluates a round from transmitted facts and a caller-supplied UTC time.
public enum MatchFinality {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidTime
    }

    public enum Status: Equatable, Sendable {
        case open
        case `final`
        case winnerChanged
    }

    public struct Result: Equatable, Sendable {
        public let status: Status
        public let ranked: [MatchEntry]
        public let late: [MatchEntry]
        public let ignored: [MatchEntry]
        public let endTime: Int64?
    }

    public static func evaluate(
        _ state: MatchState, now: Int64, finalizedWinner: MatchDescriptor? = nil
    ) throws -> Result {
        guard now >= 0 else { throw Error.invalidTime }
        let winner = state.winningProposal
        let entries = state.winningEntries
        let changed = finalizedWinner.map { $0 != winner.descriptor } ?? false

        switch state.mode {
        case .duel:
            let starter = entries.first { $0.playerID == winner.descriptor.starter }
            let opponents = entries.filter { $0.playerID != winner.descriptor.starter }.sorted {
                ($0.finishedAt, $0.playerID) < ($1.finishedAt, $1.playerID)
            }
            let participants = [starter, opponents.first].compactMap { $0 }
            let complete = starter != nil && !opponents.isEmpty
            let status: Status = changed ? .winnerChanged : finalizedWinner != nil || complete ? .final : .open
            return Result(
                status: status, ranked: try MatchRanking.ranked(participants), late: [],
                ignored: try MatchRanking.ranked(Array(opponents.dropFirst())), endTime: nil)

        case .round:
            let start = Int64(winner.descriptor.startTime)
            let deadline = start + Int64(winner.descriptor.deadlineHours) * 3_600
            let end = winner.closedAt.map { min(deadline, max(start, Int64($0))) } ?? deadline
            let eligible = entries.filter { Int64($0.finishedAt) <= end }
            let late = entries.filter { Int64($0.finishedAt) > end }
            let complete =
                winner.closedAt != nil || eligible.count >= Int(winner.descriptor.rosterSize) || now >= deadline
            let status: Status = changed ? .winnerChanged : finalizedWinner != nil || complete ? .final : .open
            return Result(
                status: status, ranked: try MatchRanking.ranked(eligible), late: try MatchRanking.ranked(late),
                ignored: [], endTime: end)
        }
    }
}
