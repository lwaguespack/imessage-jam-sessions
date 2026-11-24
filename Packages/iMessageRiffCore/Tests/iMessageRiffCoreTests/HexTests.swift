import Testing
import iMessageRiffCore

@Suite("Hex")
struct HexTests {
    @Test("Each byte is written as two lowercase digits")
    func encodes() {
        #expect(Hex.encode([]) == "")
        #expect(Hex.encode([0x00, 0x0f, 0x10, 0xa5, 0xff]) == "000f10a5ff")
        #expect(Hex.encode(Array(UInt8.min...UInt8.max)).count == 512)
    }
}
