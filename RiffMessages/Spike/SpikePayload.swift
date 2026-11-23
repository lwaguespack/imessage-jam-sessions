import CryptoKit
import Foundation

enum SpikePayloadError: String, Error, LocalizedError {
    case invalidLength = "The spike payload must contain 300 or 4,000 ASCII characters."
    case invalidEntries = "Spike entries must be a sorted, nonempty subset of A, B and C."
    case invalidNonce = "The spike payload identifier must be 32 hexadecimal characters."
    case invalidURL = "The message does not contain a supported spike URL."
    case corrupted = "The spike payload is malformed or was changed in transit."

    var errorDescription: String? { rawValue }
}

enum SpikeURLForm: String, CaseIterable {
    case data
    case fragment
    case query
}

struct SpikePayload: Equatable {
    let entries: String
    let nonce: String
    let length: Int
    let form: SpikeURLForm

    private static let prefix = "RIFFSPIKE1"
    private static let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    static func adding(_ entry: String, to entries: String) throws -> String {
        guard ["A", "B", "C"].contains(entry) else { throw SpikePayloadError.invalidEntries }
        let result = String(Set(entries + entry).sorted())
        guard validEntries(result) else { throw SpikePayloadError.invalidEntries }
        return result
    }

    static func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02X", $0) }.joined()
    }

    static func makeURL(
        entries: String,
        nonce: String,
        length: Int,
        form: SpikeURLForm
    ) throws -> URL {
        let payload = try make(entries: entries, nonce: nonce, length: length)
        if form == .data {
            guard let url = URL(string: "data:text/plain,\(payload)") else {
                throw SpikePayloadError.invalidURL
            }
            return url
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "riff.invalid"
        components.path = "/spike"
        if form == .fragment {
            components.fragment = payload
        } else {
            components.queryItems = [URLQueryItem(name: "p", value: payload)]
        }
        guard let url = components.url else { throw SpikePayloadError.invalidURL }
        return url
    }

    static func read(_ url: URL) throws -> SpikePayload {
        let payload: String
        let form: SpikeURLForm
        if url.scheme == "data" {
            let header = "data:text/plain,"
            let value = url.absoluteString
            guard value.hasPrefix(header) else { throw SpikePayloadError.invalidURL }
            payload = String(value.dropFirst(header.count))
            form = .data
        } else {
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                components.scheme == "https",
                components.host == "riff.invalid",
                components.path == "/spike"
            else { throw SpikePayloadError.invalidURL }
            if let fragment = components.fragment, components.query == nil {
                payload = fragment
                form = .fragment
            } else if components.fragment == nil,
                let items = components.queryItems,
                items.count == 1,
                items[0].name == "p",
                let value = items[0].value
            {
                payload = value
                form = .query
            } else {
                throw SpikePayloadError.invalidURL
            }
        }

        let pieces = payload.split(separator: "-", maxSplits: 4, omittingEmptySubsequences: false)
        guard pieces.count == 5, pieces[0] == prefix else { throw SpikePayloadError.corrupted }
        let entries = String(pieces[1])
        let nonce = String(pieces[2])
        let length = payload.utf8.count
        guard (try? make(entries: entries, nonce: nonce, length: length)) == payload else {
            throw SpikePayloadError.corrupted
        }
        return SpikePayload(entries: entries, nonce: nonce, length: length, form: form)
    }

    private static func make(entries: String, nonce: String, length: Int) throws -> String {
        guard length == 300 || length == 4_000 else { throw SpikePayloadError.invalidLength }
        guard validEntries(entries) else { throw SpikePayloadError.invalidEntries }
        let hex = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard nonce.utf8.count == 32, nonce.unicodeScalars.allSatisfy(hex.contains) else {
            throw SpikePayloadError.invalidNonce
        }
        let header = "\(prefix)-\(entries)-\(nonce)-"
        let remaining = length - header.utf8.count - 65
        let filler = String(repeating: alphabet, count: remaining / alphabet.count + 1)
        let body = header + filler.prefix(remaining)
        return "\(body)-\(fingerprint(body))"
    }

    private static func validEntries(_ entries: String) -> Bool {
        !entries.isEmpty && entries == String(Set(entries).sorted())
            && entries.allSatisfy { "ABC".contains($0) }
    }
}
