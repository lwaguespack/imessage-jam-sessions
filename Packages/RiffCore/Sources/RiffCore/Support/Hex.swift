/// Bytes written as base-16 text.
public enum Hex {
    private static let digits = Array("0123456789abcdef".utf8)

    /// Two lowercase digits for each byte.
    public static func encode(_ bytes: [UInt8]) -> String {
        var text: [UInt8] = []
        text.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0f)])
        }
        return String(decoding: text, as: UTF8.self)
    }
}
