import Foundation
import RiffCore

extension Command {
    /// Validates a chart file, then checks or rewrites its computed values (CHART_FORMAT section 3).
    static let chart = Command(
        name: "chart",
        summary: "Validate a chart: 'chart check <file>', or 'chart compute <file>' to write its computed values."
    ) { arguments in
        guard arguments.count == 2, ["check", "compute"].contains(arguments[0]) else {
            throw UsageError(message: "expected 'check <file>' or 'compute <file>'")
        }
        let path = arguments[1]
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { throw ChartFailure("\(path): cannot be read") }
        var chart: Chart
        do {
            chart = try ChartDecoder.decode(data)
        } catch let failure as ChartDecoder.Failure {
            throw ChartFailure("\(path): \(describe(failure))")
        }

        let config = GameConfig.standard
        let issues = ChartValidator.issues(in: chart, config: config)
        guard issues.isEmpty else {
            let count = issues.count == 1 ? "1 issue" : "\(issues.count) issues"
            throw ChartFailure("\(path): not valid, \(count)\n" + issues.map(describe).joined(separator: "\n"))
        }

        if arguments[0] == "compute" {
            chart.computed = ChartComputation.computed(for: chart, config: config)
            try CanonicalJSON.encode(chart).write(to: url, options: .atomic)
        } else {
            let stale = ChartComputation.staleFields(in: chart, config: config)
            guard stale.isEmpty else {
                let names = stale.joined(separator: ", ")
                throw ChartFailure("\(path): stored \(names) out of date; run '\(RiffCLI.toolName) chart compute'")
            }
        }
        Console.write("\(path): valid, \(chart.computed.noteCount) notes, hash \(chart.computed.hash)\n")
    }
}

/// A failure whose text is already written for the person at the terminal.
private struct ChartFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private func describe(_ failure: ChartDecoder.Failure) -> String {
    switch failure {
    case .malformed(let detail): "not a chart file: \(detail)"
    case .unknownFormat(let format): "unknown format '\(format)'"
    case .unsupportedVersion(let version): "chart version \(version) is not one this build reads"
    case .unknownField(let path): "'\(path)' is not a field of the chart format, or is written as null"
    }
}

private func describe(_ issue: ChartIssue) -> String {
    var place = ""
    if let tick = issue.tick {
        place += " at tick \(tick)"
    }
    if let lane = issue.lane {
        place += ", lane \(lane)"
    }
    return "  \(issue.rule.rawValue)\(place): \(issue.message)"
}
