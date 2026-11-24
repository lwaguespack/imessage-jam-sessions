/// Seeded bot styles for reproducible score and star-distribution experiments.
public enum BotKind: Equatable, Sendable {
    case perfect
    case skilled
    case good
    case casual
    case beginner
    case clustered
    case masher(periodMicros: Int64)
}

public struct BotSimulator: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidChart
        case invalidConfiguration
        case tooManyInputs
        case overflow
        case incompleteRun
    }

    private let chart: CompiledChart
    private let config: GameConfig
    private let hash: String
    private let baseScore: Int64

    public init(chart: Chart, config: GameConfig) throws {
        guard ChartValidator.issues(in: chart, config: config).isEmpty else { throw Error.invalidChart }
        let simulation = config.simulation
        let skills = [simulation.skilled, simulation.good, simulation.casual, simulation.beginner]
        guard
            skills.allSatisfy({
                $0.timingStdDevMicros >= 0 && (0...10_000).contains($0.missChanceBasisPoints)
            }), (0...10_000).contains(simulation.clusterStartBasisPoints),
            (0...10_000).contains(simulation.clusterContinueBasisPoints),
            simulation.tapDurationMicros > 0, simulation.maxInputEvents >= 2,
            !simulation.masherPeriodsMicros.isEmpty,
            simulation.masherPeriodsMicros.allSatisfy({ $0 > simulation.tapDurationMicros })
        else { throw Error.invalidConfiguration }
        let compiled = try CompiledChart(chart: chart, config: config)
        let hash = ChartHash.hex(of: chart, config: config)
        let values = try PerfectRun.compute(chart: compiled, config: config, chartHash: hash)
        self.chart = compiled
        self.config = config
        self.hash = hash
        baseScore = values.baseScore
    }

    public func run(_ kind: BotKind, seed: UInt64) throws -> RunSummary {
        var random = SplitMix64(seed: seed)
        var events: [InputEvent] = []
        switch kind {
        case .masher(let period):
            try generateMasher(period: period, random: &random, events: &events)
        default:
            try generateSkill(kind, random: &random, events: &events)
        }
        events.sort { $0.time < $1.time }
        var game = try GameSession(chart: chart, config: config, chartHash: hash)
        try game.start()
        var index = 0
        while index < events.count && game.state != .finished {
            let time = events[index].time
            while index < events.count && events[index].time == time {
                try game.apply(events[index])
                index += 1
            }
            try game.advance(to: time)
        }
        if game.state != .finished {
            let lastDeadline = chart.notes.map(\.missDeadline).max() ?? 0
            let lastHold = chart.notes.compactMap(\.endTime).max() ?? 0
            try game.advance(to: max(lastDeadline, lastHold))
        }
        guard game.state == .finished else { throw Error.incompleteRun }
        return try RunSummary(session: game, baseScore: baseScore)
    }

    private func generateSkill(
        _ kind: BotKind, random: inout SplitMix64, events: inout [InputEvent]
    ) throws {
        let skill: GameConfig.BotSkill?
        switch kind {
        case .perfect: skill = nil
        case .skilled: skill = config.simulation.skilled
        case .good: skill = config.simulation.good
        case .casual, .clustered: skill = config.simulation.casual
        case .beginner: skill = config.simulation.beginner
        case .masher: throw Error.invalidConfiguration
        }
        var burst = false
        for (index, note) in chart.notes.enumerated() {
            if let skill {
                let miss: Bool
                if kind == .clustered && burst {
                    miss = true
                    burst = chance(config.simulation.clusterContinueBasisPoints, random: &random)
                } else if kind == .clustered
                    && chance(config.simulation.clusterStartBasisPoints, random: &random)
                {
                    miss = true
                    burst = chance(config.simulation.clusterContinueBasisPoints, random: &random)
                } else {
                    miss = chance(skill.missChanceBasisPoints, random: &random)
                }
                if miss { continue }
            }
            let offset = try skill.map { try timingOffset(stddev: $0.timingStdDevMicros, random: &random) } ?? 0
            let (time, overflow) = note.time.addingReportingOverflow(offset)
            guard !overflow else { throw Error.overflow }
            let (tapEnd, endOverflow) = time.addingReportingOverflow(config.simulation.tapDurationMicros)
            guard !endOverflow else { throw Error.overflow }
            let release = max(tapEnd, note.endTime ?? tapEnd)
            try appendTouch(id: index, lane: note.lane, time: time, release: release, events: &events)
        }
    }

    private func generateMasher(
        period: Int64, random: inout SplitMix64, events: inout [InputEvent]
    ) throws {
        guard period > config.simulation.tapDurationMicros, let first = chart.notes.first,
            let last = chart.notes.last
        else { throw Error.invalidConfiguration }
        let goodWindow = first.missDeadline - first.time
        let start = first.time - goodWindow
        var id = 0
        for lane in 0..<config.highway.laneCount {
            var time = try add(start, Int64(bounded(UInt64(period), random: &random)))
            while time <= last.missDeadline {
                let release = try add(time, config.simulation.tapDurationMicros)
                try appendTouch(id: id, lane: lane, time: time, release: release, events: &events)
                let (nextID, overflow) = id.addingReportingOverflow(1)
                guard !overflow else { throw Error.overflow }
                id = nextID
                time = try add(time, period)
            }
        }
    }

    private func appendTouch(
        id: Int, lane: Int, time: Int64, release: Int64, events: inout [InputEvent]
    ) throws {
        guard events.count <= config.simulation.maxInputEvents - 2 else { throw Error.tooManyInputs }
        events.append(.touchDown(id: id, lane: lane, time: time))
        events.append(.touchUp(id: id, time: release))
    }

    private func timingOffset(stddev: Int64, random: inout SplitMix64) throws -> Int64 {
        var sum: Int64 = 0
        for _ in 0..<12 { sum += Int64(random.next() >> 48) }
        let (scaled, overflow) = (sum - 393_210).multipliedReportingOverflow(by: stddev)
        guard !overflow else { throw Error.overflow }
        return scaled / 65_536
    }

    private func chance(_ basisPoints: Int, random: inout SplitMix64) -> Bool {
        bounded(10_000, random: &random) < UInt64(basisPoints)
    }

    private func bounded(_ upper: UInt64, random: inout SplitMix64) -> UInt64 {
        let threshold = (0 &- upper) % upper
        while true {
            let value = random.next()
            if value >= threshold { return value % upper }
        }
    }

    private func add(_ left: Int64, _ right: Int64) throws -> Int64 {
        let (result, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw Error.overflow }
        return result
    }
}
