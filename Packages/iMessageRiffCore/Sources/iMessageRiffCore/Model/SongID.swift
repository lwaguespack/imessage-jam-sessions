enum SongID {
    static func isValid(_ value: String, maxBytes: Int) -> Bool {
        let bytes = value.utf8
        return !bytes.isEmpty && bytes.count <= maxBytes
            && bytes.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
    }
}
