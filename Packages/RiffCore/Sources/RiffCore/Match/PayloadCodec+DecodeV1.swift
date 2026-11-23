extension PayloadCodec {
    /// Version 1 was never shipped; only the fully specified round-1 group form is accepted.
    static func decodeV1(_ reader: inout ByteReader, config: GameConfig) throws -> Decoded {
        let matchID = try reader.fixed64()
        let mode = try readMode(&reader)
        let rulesVersion = try reader.varint()
        let contentRevision = try reader.varint()
        let round = try reader.varint()
        guard mode == .round, round == 1 else { throw Failure.unsupportedLegacy }
        let chart = try readChart(&reader, config: config)
        let starter = try reader.fixed64()
        let start = try reader.varint()
        let roster = try reader.byte()
        let deadline = try reader.byte()
        let closedOffset = try reader.varint()
        let closedAt: UInt32?
        if closedOffset == 0 {
            closedAt = nil
        } else {
            let (time, overflow) = start.addingReportingOverflow(closedOffset)
            guard !overflow else { throw Failure.invalidStructure }
            closedAt = time
        }
        let count = Int(try reader.byte())
        guard count <= config.payload.maxEntries else { throw Failure.invalidStructure }
        var entries: [MatchEntry] = []
        var warnings: [Warning] = []
        for _ in 0..<count {
            if let entry = try readEntry(
                &reader, proposalIndex: 0, legacyStart: start, warnings: &warnings, config: config)
            {
                entries.append(entry)
            }
        }
        guard try reader.byte() == 0 else { throw Failure.unsupportedLegacy }
        let descriptor = try MatchDescriptor(
            chart: chart, starter: starter, startTime: start, rosterSize: roster,
            deadlineHours: deadline, mode: mode, config: config)
        let state = try MatchState(
            matchID: matchID, mode: mode, rulesVersion: rulesVersion, contentRevision: contentRevision,
            round: round, history: MatchHistory(),
            proposals: [MatchProposal(descriptor: descriptor, closedAt: closedAt, entries: entries)], config: config)
        return Decoded(wireVersion: 1, state: state, warnings: warnings)
    }
}
