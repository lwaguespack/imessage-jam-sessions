import Foundation
import RiffCore
import Testing

@Suite("Canonical JSON")
struct CanonicalJSONTests {
    private func text<Value: Encodable>(_ value: Value) throws -> String {
        String(decoding: try CanonicalJSON.encode(value), as: UTF8.self)
    }

    @Test("Layout is fixed: two-space indent, colon and space, trailing newline")
    func layoutIsFixed() throws {
        struct Sample: Encodable {
            var name = "riff"
            var count = 3
            var flag = true
            var nothing: Int?
            var list = [1, 2]
            var inner = ["k": -7]

            // A synthesized conformance would leave the nil out; null has to be written to be tested.
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(name, forKey: .name)
                try container.encode(count, forKey: .count)
                try container.encode(flag, forKey: .flag)
                try container.encode(nothing, forKey: .nothing)
                try container.encode(list, forKey: .list)
                try container.encode(inner, forKey: .inner)
            }

            enum CodingKeys: String, CodingKey {
                case name, count, flag, nothing, list, inner
            }
        }

        let expected = """
            {
              "count": 3,
              "flag": true,
              "inner": {
                "k": -7
              },
              "list": [
                1,
                2
              ],
              "name": "riff",
              "nothing": null
            }

            """
        #expect(try text(Sample()) == expected)
    }

    @Test("Keys sort by code point, so capitals come first and digits are not read as numbers")
    func keysSortByCodePoint() throws {
        // Chosen so that case-insensitive or numeric-aware sorting, which some platforms use, gives another order.
        let value = ["perfect": 1, "perStar": 2, "a10": 3, "a9": 4, "Zed": 5, "\u{E9}": 6, "z": 7]
        let expected = """
            {
              "Zed": 5,
              "a10": 3,
              "a9": 4,
              "perStar": 2,
              "perfect": 1,
              "z": 7,
              "\u{E9}": 6
            }

            """
        #expect(try text(value) == expected)
    }

    @Test("Strings escape quotes, backslashes and control characters, and keep other text as UTF-8")
    func stringsAreEscaped() throws {
        let value = [
            "say \"hi\"", "back\\slash", "line\nbreak\r\ttab", "\u{08}\u{0C}\u{01}\u{1F}", "caf\u{E9} / \u{1F3B8}",
        ]
        let expected = """
            [
              "say \\"hi\\"",
              "back\\\\slash",
              "line\\nbreak\\r\\ttab",
              "\\b\\f\\u0001\\u001f",
              "caf\u{E9} / \u{1F3B8}"
            ]

            """
        #expect(try text(value) == expected)
    }

    @Test("Empty containers and bare values have one spelling")
    func emptyContainersAndFragments() throws {
        #expect(try text([Int]()) == "[]\n")
        #expect(try text([String: Int]()) == "{}\n")
        #expect(try text(["a": [Int]()]) == "{\n  \"a\": []\n}\n")
        #expect(try text(Int64.min) == "-9223372036854775808\n")
        #expect(try text(false) == "false\n")
        #expect(try text("") == "\"\"\n")
    }

    @Test("A number with a fractional part is refused")
    func fractionsAreRefused() {
        #expect(throws: DecodingError.self) {
            try CanonicalJSON.encode(["ratio": 0.5])
        }
        #expect(throws: DecodingError.self) {
            try CanonicalJSON.encode([[1.25]])
        }
    }

    @Test("Output does not depend on the order values were inserted in")
    func insertionOrderDoesNotMatter() throws {
        var forward: [String: Int] = [:]
        var backward: [String: Int] = [:]
        let keys = (0..<200).map { "key\($0)" }
        for (index, key) in keys.enumerated() {
            forward[key] = index
        }
        for (index, key) in keys.enumerated().reversed() {
            backward[key] = index
        }
        #expect(try CanonicalJSON.encode(forward) == CanonicalJSON.encode(backward))
    }
}
