enum FixedID {
    static func encode(_ value: UInt64) -> String {
        let text = String(value, radix: 16)
        return String(repeating: "0", count: 16 - text.count) + text
    }

    static func decode(_ text: String) -> UInt64? {
        guard text.utf8.count == 16,
            text.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
        else { return nil }
        return UInt64(text, radix: 16)
    }
}
