/// Canonical offline, fragment and query URL forms for match payloads.
public enum MatchURL {
    public enum Form: CaseIterable, Sendable {
        case data
        case fragment
        case query
    }

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidConfiguration
        case invalidHost
        case invalidURL
        case invalidEncoding
        case emptyPayload
        case tooLong
    }

    public static func make(
        payload: [UInt8], form: Form, host: String? = nil, config: GameConfig
    ) throws -> String {
        try validateLimit(config)
        guard !payload.isEmpty else { throw Error.emptyPayload }
        guard payload.count <= config.payload.maxURLCharacters * 3 / 4 else { throw Error.tooLong }
        let encoded = Base64URL.encode(payload)
        let url: String
        switch form {
        case .data:
            url = "data:text/plain," + encoded
        case .fragment, .query:
            guard let host, validHost(host) else { throw Error.invalidHost }
            url = "https://\(host)/m" + (form == .fragment ? "#" : "?p=") + encoded
        }
        guard url.utf8.count <= config.payload.maxURLCharacters else { throw Error.tooLong }
        return url
    }

    public static func extract(_ url: String, host: String? = nil, config: GameConfig) throws -> [UInt8] {
        try validateLimit(config)
        guard url.utf8.count <= config.payload.maxURLCharacters else { throw Error.tooLong }
        guard url.utf8.allSatisfy({ $0 < 128 }) else { throw Error.invalidURL }
        let encoded: Substring
        let dataPrefix = "data:text/plain,"
        if url.hasPrefix(dataPrefix) {
            encoded = url.dropFirst(dataPrefix.count)
        } else {
            guard let host, validHost(host) else { throw Error.invalidHost }
            let prefix = "https://\(host)/m"
            if url.hasPrefix(prefix + "#") {
                encoded = url.dropFirst(prefix.count + 1)
            } else if url.hasPrefix(prefix + "?p=") {
                encoded = url.dropFirst(prefix.count + 3)
            } else {
                throw Error.invalidURL
            }
        }
        guard !encoded.isEmpty else { throw Error.emptyPayload }
        do {
            return try Base64URL.decode(String(encoded))
        } catch Base64URL.Error.invalidEncoding {
            throw Error.invalidEncoding
        }
    }

    private static func validateLimit(_ config: GameConfig) throws {
        guard (1...5_000).contains(config.payload.maxURLCharacters) else { throw Error.invalidConfiguration }
    }

    private static func validHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-"
                && label.utf8.allSatisfy {
                    (97...122).contains($0) || (48...57).contains($0) || $0 == 45
                }
        }
    }
}
