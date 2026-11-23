/// Unpadded, canonical base64url without platform compression or networking.
public enum Base64URL {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidEncoding
    }

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

    public static func encode(_ bytes: [UInt8]) -> String {
        var result: [UInt8] = []
        var buffer: UInt32 = 0
        var bits = 0
        for byte in bytes {
            buffer = (buffer << 8) | UInt32(byte)
            bits += 8
            while bits >= 6 {
                bits -= 6
                result.append(alphabet[Int((buffer >> UInt32(bits)) & 0x3F)])
            }
            buffer &= (1 << UInt32(bits)) - 1
        }
        if bits > 0 { result.append(alphabet[Int((buffer << UInt32(6 - bits)) & 0x3F)]) }
        return String(decoding: result, as: UTF8.self)
    }

    public static func decode(_ text: String) throws -> [UInt8] {
        let encoded = Array(text.utf8)
        guard encoded.count % 4 != 1 else { throw Error.invalidEncoding }
        var result: [UInt8] = []
        var buffer: UInt32 = 0
        var bits = 0
        for byte in encoded {
            let value: UInt8
            switch byte {
            case 65...90: value = byte - 65
            case 97...122: value = byte - 97 + 26
            case 48...57: value = byte - 48 + 52
            case 45: value = 62
            case 95: value = 63
            default: throw Error.invalidEncoding
            }
            buffer = (buffer << 6) | UInt32(value)
            bits += 6
            if bits >= 8 {
                bits -= 8
                result.append(UInt8((buffer >> UInt32(bits)) & 0xFF))
                buffer &= (1 << UInt32(bits)) - 1
            }
        }
        guard buffer == 0 else { throw Error.invalidEncoding }
        return result
    }
}
