import Foundation

@main
enum SpikeTestRunner {
    private static let nonce = "0123456789ABCDEF0123456789ABCDEF"

    static func main() throws {
        for form in SpikeURLForm.allCases {
            for length in [300, 4_000] {
                let url = try SpikePayload.makeURL(
                    entries: "AB", nonce: nonce, length: length, form: form)
                let decoded = try SpikePayload.read(url)
                check(decoded.entries == "AB", "entries round-trip in \(form)")
                check(decoded.nonce == nonce, "nonce round-trips in \(form)")
                check(decoded.length == length, "length round-trips in \(form)")
                check(decoded.form == form, "URL form round-trips in \(form)")
            }
        }

        let original = try SpikePayload.makeURL(
            entries: "A", nonce: nonce, length: 300, form: .data)
        let changed = URL(string: String(original.absoluteString.dropLast()) + "Z")!
        let truncated = URL(string: String(original.absoluteString.dropLast()))!
        let changedEntry = URL(
            string: original.absoluteString.replacingOccurrences(
                of: "RIFFSPIKE1-A-", with: "RIFFSPIKE1-B-"))!
        let changedNonce = URL(
            string: original.absoluteString.replacingOccurrences(
                of: nonce, with: "1123456789ABCDEF0123456789ABCDEF"))!
        expectError("changed payload") { try SpikePayload.read(changed) }
        check(
            SpikePayload.fingerprint(original.absoluteString)
                != SpikePayload.fingerprint(changed.absoluteString),
            "URL fingerprints detect changed bytes"
        )
        expectError("truncated payload") { try SpikePayload.read(truncated) }
        expectError("changed entry") { try SpikePayload.read(changedEntry) }
        expectError("changed nonce") { try SpikePayload.read(changedNonce) }
        expectError("unrelated URL") {
            try SpikePayload.read(URL(string: "https://example.com/spike")!)
        }

        check(try SpikePayload.adding("B", to: "AC") == "ABC", "entries are sorted")
        check(try SpikePayload.adding("A", to: "A") == "A", "entries are deduplicated")
        expectError("invalid entry") { try SpikePayload.adding("D", to: "A") }
        expectError("unordered entries") {
            try SpikePayload.makeURL(entries: "BA", nonce: nonce, length: 300, form: .query)
        }
        expectError("invalid length") {
            try SpikePayload.makeURL(entries: "A", nonce: nonce, length: 301, form: .query)
        }
        check(SpikeStatistics.median([4, 1, 3, 2]) == 2.5, "even-sample median")
        check(SpikeStatistics.median([3, 1, 2]) == 2, "odd-sample median")
        check(SpikeStatistics.percentile([4, 1, 3, 2], fraction: 0.95) == 4, "p95")
        check(SpikeStatistics.robustSpread([1, 2, 3]) == 1.4826, "robust spread")
        check(SpikeStatistics.median([]) == nil, "empty samples have no median")
        print("PASS  spike payload tests")
    }

    private static func check(_ condition: Bool, _ description: String) {
        guard condition else {
            fputs("FAIL  \(description)\n", stderr)
            exit(1)
        }
    }

    private static func expectError<T>(_ description: String, _ body: () throws -> T) {
        do {
            _ = try body()
        } catch {
            return
        }
        check(false, description)
    }
}
