import Foundation

/// Output helpers. Results go to standard output and nothing else does, so scripts can capture them.
enum Console {
    /// Writes bytes to standard output exactly as given.
    static func write(_ data: Data) {
        FileHandle.standardOutput.write(data)
    }

    /// Writes text to standard output exactly as given; the caller supplies any newline.
    static func write(_ text: String) {
        write(Data(text.utf8))
    }

    /// Writes text to standard error exactly as given.
    static func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }
}
