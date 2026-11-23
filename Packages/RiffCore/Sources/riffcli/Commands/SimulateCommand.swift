import Foundation
import RiffCore

extension Command {
    static let simulate = Command(
        name: "simulate",
        summary: "Run seeded bots: 'simulate <chart> --seed <n> --runs <n>'."
    ) { arguments in
        let config = GameConfig.standard
        guard arguments.count == 5, arguments[1] == "--seed", arguments[3] == "--runs",
            let seed = UInt64(arguments[2]), let runs = Int(arguments[4]),
            runs > 0, runs <= config.simulation.maxRuns
        else { throw UsageError(message: "expected '<chart> --seed <n> --runs <1...\(config.simulation.maxRuns)>'") }

        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[0]))
        let chart = try ChartDecoder.decode(data)
        let issues = ChartValidator.issues(in: chart, config: config)
        guard issues.isEmpty else {
            throw SimulationFailure("invalid chart: " + issues.map { $0.rule.rawValue }.joined(separator: ", "))
        }
        let simulator = try BotSimulator(chart: chart, config: config)
        var generator = SplitMix64(seed: seed)
        let seeds = (0..<runs).map { _ in generator.next() }
        var bots: [(String, BotKind)] = [
            ("perfect", .perfect), ("skilled", .skilled), ("good", .good),
            ("casual", .casual), ("beginner", .beginner), ("clustered", .clustered),
        ]
        bots += config.simulation.masherPeriodsMicros.map { ("masher-\($0)us", .masher(periodMicros: $0)) }
        Console.write("seed=\(seed) runs=\(runs)\n")
        for (name, bot) in bots {
            var counts = [Int](repeating: 0, count: config.stars.goldStarValue + 1)
            var scores: [Int64] = []
            var combos = 0
            for runSeed in seeds {
                let result = try simulator.run(bot, seed: runSeed)
                guard counts.indices.contains(result.stars) else { throw SimulationFailure("invalid star result") }
                counts[result.stars] += 1
                scores.append(result.score)
                if result.fullCombo { combos += 1 }
            }
            scores.sort()
            let histogram = counts.enumerated().map { "\($0.offset):\($0.element)" }.joined(separator: ",")
            Console.write(
                "\(name) medianScore=\(scores[(scores.count - 1) / 2]) "
                    + "fullCombos=\(combos) stars=\(histogram)\n")
        }
    }

    private struct SimulationFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
