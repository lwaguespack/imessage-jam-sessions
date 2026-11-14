extension GameConfig {
    /// Limits on the match payload carried in a message (plan 5.5, appendix C).
    ///
    /// Sizes read "KB" as 1,024 bytes.
    public struct Payload: Codable, Equatable, Sendable {
        /// Schema version written into every payload; decoding rejects any other (plan 5.5).
        public var schemaVersion = RiffCoreInfo.payloadSchemaVersion

        /// Largest encoded payload accepted, in bytes: 4 KB (plan 5.5).
        public var maxEncodedBytes = 4096

        /// Size an encoded two-player duel must stay under, in bytes: 1 KB (plan section 3, appendix C).
        public var maxDuelEncodedBytes = 1024

        /// Most player entries in one round (plan 5.5).
        public var maxEntries = 32

        /// Longest nickname, in characters (plan appendix C).
        public var maxNicknameCharacters = 16

        /// Length of a match id, in characters (plan appendix C).
        public var matchIDCharacters = 10

        /// Length of a player id: the leading hex characters of the participant UUID (plan appendix C).
        public var playerIDHexCharacters = 8

        /// Length of a chart hash, in hex characters (plan appendix A and C).
        public var chartHashHexCharacters = 8

        /// Bytes kept from the HMAC-SHA256 signature (plan 5.5).
        public var signatureBytes = 16
    }
}
