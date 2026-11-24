import iMessageRiffCore

extension Command {
    static let payload = Command(
        name: "payload",
        summary: "Inspect an authenticated match URL: 'payload inspect <url> [--host <host>]'."
    ) { arguments in
        guard arguments.count == 2 || (arguments.count == 4 && arguments[2] == "--host"),
            arguments[0] == "inspect"
        else { throw UsageError(message: "expected 'inspect <url> [--host <host>]'") }
        let host = arguments.count == 4 ? arguments[3] : "riff.invalid"
        let config = GameConfig.standard
        let bytes = try MatchURL.extract(arguments[1], host: host, config: config)
        let decoded = try PayloadCodec.decode(bytes, config: config)
        let state = decoded.state
        Console.write(
            "wireVersion: \(decoded.wireVersion)\n"
                + "matchId: \(hex(state.matchID))\n"
                + "mode: \(state.mode == .duel ? "duel" : "round")\n"
                + "rulesVersion: \(state.rulesVersion)\n"
                + "contentRevision: \(state.contentRevision)\n"
                + "round: \(state.round)\n"
                + "proposals: \(state.proposals.count)\n"
        )
        for item in state.history.series {
            Console.write("series player=\(hex(item.playerID)) wins=\(item.wins)\n")
        }
        if let chart = state.history.previousChart {
            Console.write(
                "previousChart: song=\(chart.songID) part=\(chart.part.rawValue) "
                    + "difficulty=\(chart.difficulty.rawValue) chartHash=\(hex(chart.chartHash))\n"
            )
        }
        for entry in state.history.previous {
            Console.write(
                "previous player=\(hex(entry.playerID)) score=\(entry.score) accuracy=\(entry.accuracy) "
                    + "streak=\(entry.longestStreak) tries=\(entry.tries) fullCombo=\(entry.fullCombo) "
                    + "t=\(entry.finishedAt)\n"
            )
        }
        for (index, proposal) in state.proposals.enumerated() {
            let descriptor = proposal.descriptor
            Console.write(
                "proposal \(index): song=\(descriptor.chart.songID) part=\(descriptor.chart.part.rawValue) "
                    + "difficulty=\(descriptor.chart.difficulty.rawValue) chartHash=\(hex(descriptor.chart.chartHash)) "
                    + "starter=\(hex(descriptor.starter)) t0=\(descriptor.startTime) "
                    + "roster=\(descriptor.rosterSize) deadlineHours=\(descriptor.deadlineHours) "
                    + "closedAt=\(proposal.closedAt.map(String.init) ?? "open")\n"
            )
            for entry in proposal.entries {
                Console.write(
                    "  player=\(hex(entry.playerID)) nickname=\(entry.nickname) score=\(entry.score) "
                        + "accuracy=\(entry.accuracy) streak=\(entry.longestStreak) tries=\(entry.tries) "
                        + "level=\(entry.level) title=\(entry.titleID) frame=\(entry.frameID) "
                        + "fullCombo=\(entry.fullCombo) t=\(entry.finishedAt)\n"
                )
            }
        }
        for warning in decoded.warnings { Console.write("warning: \(warning)\n") }
        let canonical = try PayloadCodec.encode(state, config: config)
        Console.write(
            "canonicalV2: \(Base64URL.encode(canonical))\n"
                + "Chart bounds and content revision were not checked.\n")
    }

    private static func hex<T: FixedWidthInteger>(_ value: T) -> String {
        let text = String(value, radix: 16)
        return String(repeating: "0", count: T.bitWidth / 4 - text.count) + text
    }
}
