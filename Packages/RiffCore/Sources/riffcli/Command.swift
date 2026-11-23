/// One subcommand.
///
/// To add a subcommand, write a file under `Commands/` that declares it as a static member in an extension, then
/// add it to `all`.
struct Command: Sendable {
    /// The word typed after the tool name.
    let name: String

    /// One line for the usage text.
    let summary: String

    /// Other spellings that select this command.
    var aliases: [String] = []

    /// Runs the command with the arguments that follow its name. Throws `UsageError` when they are wrong.
    let run: @Sendable (_ arguments: [String]) throws -> Void
}

extension Command {
    /// Every subcommand, in the order the usage text lists them.
    static let all: [Command] = [.config, .chart, .payload, .version, .help]

    static func named(_ name: String) -> Command? {
        all.first { $0.name == name || $0.aliases.contains(name) }
    }

    /// For commands that take no arguments, so a typo is reported rather than ignored.
    static func requireNoArguments(_ arguments: [String]) throws {
        if let unexpected = arguments.first {
            throw UsageError(message: "unexpected argument '\(unexpected)'")
        }
    }
}

/// A mistake in the command line. The tool reports it with the usage text and exits with `ExitStatus.usage`.
struct UsageError: Error {
    let message: String
}
