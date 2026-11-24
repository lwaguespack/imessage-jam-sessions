/// Bounds-checked fixed-width and canonical UInt32 LEB128 input.
struct ByteReader {
    enum Error: Swift.Error, Equatable {
        case truncated
        case invalidVarint
        case nonCanonicalVarint
    }

    private let bytes: [UInt8]
    private(set) var position = 0
    var remaining: Int { bytes.count - position }

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func byte() throws -> UInt8 {
        guard position < bytes.count else { throw Error.truncated }
        defer { position += 1 }
        return bytes[position]
    }

    mutating func read(_ count: Int) throws -> [UInt8] {
        guard count >= 0, count <= remaining else { throw Error.truncated }
        let value = Array(bytes[position..<(position + count)])
        position += count
        return value
    }

    mutating func fixed64() throws -> UInt64 {
        var result: UInt64 = 0
        for _ in 0..<8 { result = (result << 8) | UInt64(try byte()) }
        return result
    }

    mutating func fixed32() throws -> UInt32 {
        var result: UInt32 = 0
        for _ in 0..<4 { result = (result << 8) | UInt32(try byte()) }
        return result
    }

    mutating func varint() throws -> UInt32 {
        var result: UInt32 = 0
        for index in 0..<5 {
            let value = try byte()
            let group = value & 0x7F
            if index == 4 && group > 0x0F { throw Error.invalidVarint }
            result |= UInt32(group) << UInt32(index * 7)
            if value & 0x80 == 0 {
                if index > 0 && group == 0 { throw Error.nonCanonicalVarint }
                return result
            }
        }
        throw Error.invalidVarint
    }
}
