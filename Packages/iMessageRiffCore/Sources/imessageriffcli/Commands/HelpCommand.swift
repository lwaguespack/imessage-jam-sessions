extension Command {
    static let help = Command(
        name: "help",
        summary: "Show this help.",
        aliases: ["-h", "--help"]
    ) { arguments in
        try requireNoArguments(arguments)
        Console.write(IMessageRiffCLI.usage)
    }
}
