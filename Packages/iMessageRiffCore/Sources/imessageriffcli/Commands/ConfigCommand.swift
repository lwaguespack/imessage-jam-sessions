import iMessageRiffCore

extension Command {
    /// Prints the standard config so that tools outside Swift read the same numbers the game uses.
    static let config = Command(
        name: "config",
        summary: "Print the standard game config as canonical JSON."
    ) { arguments in
        try requireNoArguments(arguments)
        Console.write(try CanonicalJSON.encode(GameConfig.standard))
    }
}
