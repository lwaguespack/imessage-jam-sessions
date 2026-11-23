extension GameConfig {
    /// Limits on the match payload carried in a message (MATCH_PROTOCOL section 10).
    public struct Payload: Codable, Equatable, Sendable {
        /// Schema version written into every payload; decoding rejects any other (plan 5.5).
        public var schemaVersion = RiffCoreInfo.payloadSchemaVersion

        /// Longest message URL accepted, payload included, in characters (MATCH_PROTOCOL section 10).
        public var maxURLCharacters = 4096

        /// Size an encoded two-player duel must stay under, in bytes: 1 KB (plan section 3, appendix C).
        public var maxDuelEncodedBytes = 1024

        /// Most player entries in one round (plan 5.5).
        public var maxEntries = 32

        /// Most competing proposals retained in a group round (D-097).
        public var maxRoundProposals = 8

        /// Most competing proposals and entries retained in a duel (D-097).
        public var maxDuelProposals = 4
        public var maxDuelEntries = 8

        /// Longest nickname, in grapheme clusters (D-018).
        public var maxNicknameCharacters = 16

        /// Longest nickname, in UTF-8 bytes; both nickname limits apply (D-018).
        public var maxNicknameBytes = 32

        /// Length of a match id, in bytes (D-015).
        public var matchIDBytes = 8

        /// Length of a player id, in bytes (D-010).
        public var playerIDBytes = 8

        /// Bytes kept from a chart's SHA-256 hash (D-015).
        public var chartHashBytes = 4

        /// Longest song id, in ASCII bytes (D-015).
        public var maxSongIDBytes = 24

        /// Bytes kept from the HMAC-SHA256 integrity tag (D-016).
        public var tagBytes = 8

        /// Key for the integrity tag of wire version 1: SHA-256 of the ASCII text "riff-match-integrity-key-v1".
        /// It detects corruption and is not a secret (D-016, D-084).
        public var integrityKeyV1: [UInt8] = [
            0x96, 0xe0, 0x50, 0xf5, 0x2d, 0x06, 0x42, 0x31, 0x43, 0x30, 0xc2, 0x55, 0x2c, 0x2f, 0x81, 0xe0,
            0xda, 0x7f, 0xb9, 0xfb, 0xd0, 0xfb, 0x12, 0xd8, 0xa3, 0xc6, 0x91, 0xf5, 0xec, 0xd0, 0x07, 0x15,
        ]

        /// Key for version 2: SHA-256 of the ASCII text "riff-match-integrity-key-v2".
        public var integrityKeyV2: [UInt8] = [
            0x9e, 0xa5, 0x5f, 0xff, 0x2a, 0xaf, 0xba, 0xb8, 0xd5, 0x2d, 0x76, 0x0c, 0x7e, 0x73, 0x37, 0xf3,
            0x7c, 0x56, 0xcc, 0xd1, 0xe9, 0xaa, 0xde, 0x6d, 0x75, 0x1d, 0x18, 0x26, 0xcb, 0x3e, 0xf5, 0x79,
        ]
    }

    /// Limits on a match itself (D-012, D-058).
    public struct Match: Codable, Equatable, Sendable {
        /// How long a group round stays open after it starts, in hours (D-012).
        public var groupDeadlineHours = 24

        /// Highest try count an entry can carry (D-058).
        public var maxTries = 99
    }
}
