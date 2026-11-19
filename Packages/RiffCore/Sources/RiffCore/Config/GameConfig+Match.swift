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
    }

    /// Limits on a match itself (D-012, D-058).
    public struct Match: Codable, Equatable, Sendable {
        /// How long a group round stays open after it starts, in hours (D-012).
        public var groupDeadlineHours = 24

        /// Highest try count an entry can carry (D-058).
        public var maxTries = 99
    }
}
