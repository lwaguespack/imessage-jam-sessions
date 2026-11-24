import Testing
import iMessageRiffCore

#if canImport(CryptoKit)
    import CryptoKit
#endif

@Suite("SHA-256")
struct SHA256Tests {
    private func digest(_ text: String) -> String {
        Hex.encode(iMessageRiffCore.SHA256.hash(Array(text.utf8)))
    }

    @Test("The example messages in FIPS 180-4 hash to their published digests")
    func publishedExamples() {
        #expect(digest("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(digest("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(
            digest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
                == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
        let twoBlocks =
            "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"
            + "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
        #expect(digest(twoBlocks) == "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1")
    }

    // The padding changes shape at 55/56 bytes and again at each 64-byte block edge.
    @Test(
        "Lengths either side of each padding boundary hash correctly",
        arguments: [
            (55, "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"),
            (56, "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a"),
            (63, "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34"),
            (64, "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"),
            (65, "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0"),
            (119, "31eba51c313a5c08226adf18d4a359cfdfd8d2e816b13f4af952f7ea6584dcfb"),
            (120, "2f3d335432c70b580af0e8e1b3674a7c020d683aa5f73aaaedfdc55af904c21c"),
        ]
    )
    func paddingBoundaries(length: Int, expected: String) {
        #expect(Hex.encode(iMessageRiffCore.SHA256.hash([UInt8](repeating: 0x61, count: length))) == expected)
    }

    @Test("One million repetitions of 'a' hash to the published digest")
    func oneMillionBytes() {
        let message = [UInt8](repeating: 0x61, count: 1_000_000)
        let hexDigest = Hex.encode(iMessageRiffCore.SHA256.hash(message))
        #expect(hexDigest == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test("A digest is always 32 bytes")
    func digestLength() {
        #expect(iMessageRiffCore.SHA256.digestLength == 32)
        #expect(iMessageRiffCore.SHA256.hash([]).count == 32)
        #expect(iMessageRiffCore.SHA256.hash([UInt8](repeating: 0xff, count: 200)).count == 32)
    }

    #if canImport(CryptoKit)
        @Test("Digests equal CryptoKit's for every length from 0 to 300 bytes")
        func matchesCryptoKit() {
            // Bytes from a fixed recurrence, so a failure is reproducible.
            var message: [UInt8] = []
            var value: UInt8 = 17
            for _ in 0...300 {
                #expect(iMessageRiffCore.SHA256.hash(message) == Array(CryptoKit.SHA256.hash(data: message)))
                value = value &* 73 &+ 41
                message.append(value)
            }
        }
    #endif
}
