import iMessageRiffCore

extension Command {
    /// Prints the bare version string, with nothing around it, so scripts can compare it directly.
    static let version = Command(
        name: "version",
        summary: "Print the iMessageRiffCore version.",
        aliases: ["--version"]
    ) { arguments in
        try requireNoArguments(arguments)
        Console.write(IMessageRiffCoreInfo.version + "\n")
    }
}
