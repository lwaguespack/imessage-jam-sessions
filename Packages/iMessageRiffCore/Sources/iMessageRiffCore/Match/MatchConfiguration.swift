enum MatchConfiguration {
    static func validate(_ config: GameConfig) throws {
        let payload = config.payload
        guard (3...32).contains(payload.maxEntries),
            (2...8).contains(payload.maxDuelEntries),
            (1...4).contains(payload.maxDuelProposals),
            (1...8).contains(payload.maxRoundProposals),
            (6...16).contains(payload.maxNicknameCharacters),
            (6...32).contains(payload.maxNicknameBytes),
            (1...24).contains(payload.maxSongIDBytes),
            (1...99).contains(config.match.maxTries),
            (1...255).contains(config.levels.maxLevel),
            (0...255).contains(config.unlocks.titles),
            (0...255).contains(config.unlocks.scoreCardFrames)
        else { throw MatchModelError.invalidConfiguration }
    }
}
