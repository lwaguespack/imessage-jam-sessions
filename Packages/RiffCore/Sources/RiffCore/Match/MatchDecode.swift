/// The local catalogue's authoritative bounds for one chart.
public struct MatchChartBounds: Equatable, Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidBounds
    }

    public let chartHash: UInt32
    public let noteCount: UInt32
    public let scoreCeiling: UInt32

    public init(chartHash: UInt32, noteCount: UInt32, scoreCeiling: UInt32) throws {
        guard noteCount > 0, scoreCeiling > 0 else { throw Error.invalidBounds }
        self.chartHash = chartHash
        self.noteCount = noteCount
        self.scoreCeiling = scoreCeiling
    }
}

public protocol MatchChartLookup: Sendable {
    func bounds(songID: String, part: Part, difficulty: Difficulty) -> MatchChartBounds?
}

/// Ordered URL, version, integrity, catalogue and entry validation.
public enum MatchDecode {
    public enum Failure: Equatable, Sendable {
        case url(MatchURL.Error)
        case payload(PayloadCodec.Failure)
        case invalidConfiguration
        case unknownChart(MatchChart)
        case chartHashMismatch(MatchChart)
        case invalidModel(MatchModelError)
        case missingChartBounds
    }

    public enum Location: Equatable, Sendable {
        case proposal(Int)
        case previous
    }

    public enum EntryProblem: Equatable, Sendable {
        case scoreAboveCeiling
        case streakAboveNoteCount
        case inconsistentFullCombo
    }

    public enum Warning: Equatable, Sendable {
        case codec(PayloadCodec.Warning)
        case entryDropped(location: Location, playerID: UInt64, reason: EntryProblem)
    }

    public enum Outcome: Equatable, Sendable {
        case valid(MatchState, warnings: [Warning])
        case updateNeeded
        case askSenderToUpdate
        case unsupportedLegacy
        case unreadable(Failure)
    }

    public static func decode(
        _ url: String, host: String? = nil, config: GameConfig, contentRevision: UInt32,
        catalogue: any MatchChartLookup
    ) throws -> Outcome {
        let bytes: [UInt8]
        do {
            bytes = try MatchURL.extract(url, host: host, config: config)
        } catch let error as MatchURL.Error {
            return .unreadable(.url(error))
        }

        let decoded: PayloadCodec.Decoded
        do {
            decoded = try PayloadCodec.decode(bytes, config: config)
        } catch PayloadCodec.Failure.newerVersion {
            return .updateNeeded
        } catch PayloadCodec.Failure.unsupportedLegacy {
            return .unsupportedLegacy
        } catch let error as PayloadCodec.Failure {
            return .unreadable(.payload(error))
        }

        guard let localRules = UInt32(exactly: config.rulesVersion), localRules > 0, contentRevision > 0 else {
            return .unreadable(.invalidConfiguration)
        }
        let state = decoded.state
        if state.rulesVersion > localRules || state.contentRevision > contentRevision { return .updateNeeded }
        if state.rulesVersion < localRules || state.contentRevision < contentRevision { return .askSenderToUpdate }

        var known: [(MatchChart, MatchChartBounds)] = []
        for chart in decoded.referencedCharts {
            if known.contains(where: { $0.0 == chart }) { continue }
            guard let bounds = catalogue.bounds(songID: chart.songID, part: chart.part, difficulty: chart.difficulty)
            else { return .unreadable(.unknownChart(chart)) }
            guard bounds.chartHash == chart.chartHash else { return .unreadable(.chartHashMismatch(chart)) }
            known.append((chart, bounds))
        }
        var warnings = decoded.warnings.map(Warning.codec)
        var proposals: [MatchProposal] = []
        do {
            for (index, proposal) in state.proposals.enumerated() {
                guard let bounds = known.first(where: { $0.0 == proposal.descriptor.chart })?.1 else {
                    return .unreadable(.missingChartBounds)
                }
                var entries: [MatchEntry] = []
                for entry in proposal.entries {
                    if let problem = problem(
                        score: entry.score, streak: entry.longestStreak, fullCombo: entry.fullCombo, bounds: bounds)
                    {
                        warnings.append(
                            .entryDropped(location: .proposal(index), playerID: entry.playerID, reason: problem))
                    } else {
                        entries.append(entry)
                    }
                }
                proposals.append(
                    try MatchProposal(descriptor: proposal.descriptor, closedAt: proposal.closedAt, entries: entries))
            }
            var previous: [MatchShortEntry] = []
            if let chart = state.history.previousChart {
                guard let bounds = known.first(where: { $0.0 == chart })?.1 else {
                    return .unreadable(.missingChartBounds)
                }
                for entry in state.history.previous {
                    if let problem = problem(
                        score: entry.score, streak: entry.longestStreak, fullCombo: entry.fullCombo, bounds: bounds)
                    {
                        warnings.append(.entryDropped(location: .previous, playerID: entry.playerID, reason: problem))
                    } else {
                        previous.append(entry)
                    }
                }
            }
            let history = try MatchHistory(
                series: state.history.series, previousChart: previous.isEmpty ? nil : state.history.previousChart,
                previous: previous)
            let filtered = try MatchState(
                matchID: state.matchID, mode: state.mode, rulesVersion: state.rulesVersion,
                contentRevision: state.contentRevision, round: state.round, history: history,
                proposals: proposals, config: config)
            return .valid(filtered, warnings: warnings)
        } catch let error as MatchModelError {
            return .unreadable(.invalidModel(error))
        }
    }

    private static func problem(
        score: UInt32, streak: UInt32, fullCombo: FullComboStatus, bounds: MatchChartBounds
    ) -> EntryProblem? {
        if score > bounds.scoreCeiling { return .scoreAboveCeiling }
        if streak > bounds.noteCount { return .streakAboveNoteCount }
        if fullCombo == .yes && streak != bounds.noteCount { return .inconsistentFullCombo }
        return nil
    }
}
