import RiffCore
import Testing

#if canImport(CryptoKit)
    import CryptoKit
#endif

@Suite("HMAC-SHA256")
struct HMACSHA256Tests {
    private func code(key: [UInt8], message: [UInt8]) -> String {
        Hex.encode(HMACSHA256.authenticationCode(for: message, key: key))
    }

    // Test cases 1 to 4, 6 and 7; case 5 is about truncating the code.
    @Test("The test cases in RFC 4231 give their published codes")
    func publishedCases() {
        let longKey = [UInt8](repeating: 0xaa, count: 131)
        let longText =
            "This is a test using a larger than block-size key and a larger than block-size data. "
            + "The key needs to be hashed before being used by the HMAC algorithm."
        let cases: [(key: [UInt8], message: [UInt8], code: String)] = [
            (
                [UInt8](repeating: 0x0b, count: 20), Array("Hi There".utf8),
                "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
            ),
            (
                Array("Jefe".utf8), Array("what do ya want for nothing?".utf8),
                "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
            ),
            (
                [UInt8](repeating: 0xaa, count: 20), [UInt8](repeating: 0xdd, count: 50),
                "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"
            ),
            (
                Array(UInt8(1)...UInt8(25)), [UInt8](repeating: 0xcd, count: 50),
                "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b"
            ),
            (
                longKey, Array("Test Using Larger Than Block-Size Key - Hash Key First".utf8),
                "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
            ),
            (
                longKey, Array(longText.utf8),
                "9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2"
            ),
        ]
        for (index, testCase) in cases.enumerated() {
            #expect(code(key: testCase.key, message: testCase.message) == testCase.code, "case \(index)")
        }
    }

    // A key longer than one 64-byte block is hashed first; expected values are from Python's hmac module.
    @Test("Keys of exactly one block, one byte more, and no bytes at all are handled")
    func keyLengths() {
        let message = Array("message".utf8)
        #expect(
            code(key: [UInt8](repeating: 0x6b, count: 64), message: message)
                == "890f3a16e0ca0aaa3bf180f70fa8e3970b3fd6505e98fde157988dcc19d1685c"
        )
        #expect(
            code(key: [UInt8](repeating: 0x6b, count: 65), message: message)
                == "0c256505306af48015530c139bb7add5ad7a6a9291cd511278a067e765816fbd"
        )
        #expect(code(key: [], message: []) == "b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad")
    }

    #if canImport(CryptoKit)
        @Test("Codes equal CryptoKit's for keys and messages of many lengths")
        func matchesCryptoKit() {
            // Bytes from a fixed recurrence, so a failure is reproducible.
            var bytes: [UInt8] = []
            var value: UInt8 = 29
            for _ in 0..<200 {
                value = value &* 73 &+ 41
                bytes.append(value)
            }
            for keyLength in [0, 1, 31, 32, 63, 64, 65, 128, 200] {
                for messageLength in [0, 1, 55, 56, 64, 119, 200] {
                    let key = Array(bytes.prefix(keyLength))
                    let message = Array(bytes.suffix(messageLength))
                    let symmetricKey = SymmetricKey(data: key)
                    let expected = HMAC<CryptoKit.SHA256>.authenticationCode(for: message, using: symmetricKey)
                    #expect(HMACSHA256.authenticationCode(for: message, key: key) == Array(expected))
                }
            }
        }
    #endif
}
