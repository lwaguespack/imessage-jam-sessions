/// Canonical fixed-width and unsigned LEB128 byte output.
struct ByteWriter {
    private(set) var bytes: [UInt8] = []

    mutating func byte(_ value: UInt8) {
        bytes.append(value)
    }

    mutating func append(_ values: [UInt8]) {
        bytes.append(contentsOf: values)
    }

    mutating func fixed64(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            byte(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }

    mutating func fixed32(_ value: UInt32) {
        for shift in stride(from: 24, through: 0, by: -8) {
            byte(UInt8(truncatingIfNeeded: value >> UInt32(shift)))
        }
    }

    mutating func varint(_ value: UInt32) {
        var remaining = value
        repeat {
            var next = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { next |= 0x80 }
            byte(next)
        } while remaining != 0
    }
}
