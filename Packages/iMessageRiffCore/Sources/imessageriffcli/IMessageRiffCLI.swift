import Foundation

@main
enum IMessageRiffCLI {
    static let toolName = "imessageriffcli"

    static func main() {
        exit(run(arguments: Array(CommandLine.arguments.dropFirst())))
    }

    /// Runs one invocation and returns its exit status.
    static func run(arguments: [String]) -> Int32 {
        guard let name = arguments.first else {
            Console.writeError(usage)
            return ExitStatus.usage
        }
        guard let command = Command.named(name) else {
            Console.writeError("\(toolName): unknown command '\(name)'\n\n\(usage)")
            return ExitStatus.usage
        }
        do {
            try command.run(Array(arguments.dropFirst()))
            return ExitStatus.success
        } catch let error as UsageError {
            Console.writeError("\(toolName) \(command.name): \(error.message)\n\n\(usage)")
            return ExitStatus.usage
        } catch {
            Console.writeError("\(toolName) \(command.name): \(error)\n")
            return ExitStatus.failure
        }
    }

    static var usage: String {
        let width = Command.all.map(\.name.count).max() ?? 0
        let rows = Command.all.map { command in
            "  " + command.name + String(repeating: " ", count: width - command.name.count + 2) + command.summary
        }
        return "Usage: \(toolName) <command>\n\nCommands:\n" + rows.joined(separator: "\n") + "\n"
    }
}

enum ExitStatus {
    static let success: Int32 = 0
    static let failure: Int32 = 1
    /// EX_USAGE from sysexits.h: the command line itself was wrong.
    static let usage: Int32 = 64
}
