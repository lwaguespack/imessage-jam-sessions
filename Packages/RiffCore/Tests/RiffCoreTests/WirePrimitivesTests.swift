import Testing

@testable import RiffCore

@Suite("Wire primitives")
struct WirePrimitivesTests {
    @Test("Base64url matches standard unpadded vectors and rejects non-canonical input")
    func base64() throws {
        let vectors = [
            ("", ""), ("f", "Zg"), ("fo", "Zm8"), ("foo", "Zm9v"),
            ("foob", "Zm9vYg"), ("fooba", "Zm9vYmE"), ("foobar", "Zm9vYmFy"),
        ]
        for (plain, encoded) in vectors {
            #expect(Base64URL.encode(Array(plain.utf8)) == encoded)
            #expect(try Base64URL.decode(encoded) == Array(plain.utf8))
        }
        #expect(Base64URL.encode([0xFB, 0xFF]) == "-_8")
        #expect(throws: Base64URL.Error.invalidEncoding) { try Base64URL.decode("Zg==") }
        #expect(throws: Base64URL.Error.invalidEncoding) { try Base64URL.decode("Zh") }
        #expect(throws: Base64URL.Error.invalidEncoding) { try Base64URL.decode("A") }
        var random = SplitMix64(seed: 42)
        for length in 0...256 {
            let bytes = (0..<length).map { _ in UInt8(truncatingIfNeeded: random.next()) }
            #expect(try Base64URL.decode(Base64URL.encode(bytes)) == bytes)
        }
    }

    @Test("Fixed-width integers and minimal UInt32 varints round-trip")
    func integers() throws {
        var writer = ByteWriter()
        writer.fixed64(.max)
        writer.fixed32(0x1234_5678)
        let values: [UInt32] = [0, 127, 128, 16_384, .max]
        for value in values { writer.varint(value) }
        var reader = ByteReader(writer.bytes)
        #expect(try reader.fixed64() == .max)
        #expect(try reader.fixed32() == 0x1234_5678)
        for value in values {
            #expect(try reader.varint() == value)
        }
        #expect(reader.remaining == 0)
    }

    @Test("Truncated, overflowing and overlong varints are rejected")
    func invalidVarints() {
        var truncated = ByteReader([0x80])
        #expect(throws: ByteReader.Error.truncated) { try truncated.varint() }
        var overflow = ByteReader([0xFF, 0xFF, 0xFF, 0xFF, 0x10])
        #expect(throws: ByteReader.Error.invalidVarint) { try overflow.varint() }
        var overlong = ByteReader([0x80, 0x00])
        #expect(throws: ByteReader.Error.nonCanonicalVarint) { try overlong.varint() }
    }
}
