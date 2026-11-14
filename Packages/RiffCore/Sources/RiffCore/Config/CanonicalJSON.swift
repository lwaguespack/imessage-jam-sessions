import Foundation

/// JSON text that is the same, byte for byte, on every platform and every run.
///
/// `JSONEncoder` leaves the order of sorted keys and the exact layout to the platform's Foundation, so its output
/// cannot be compared or hashed across devices. This writer fixes every choice: UTF-8, object keys in code-point
/// order, two-space indentation, `": "` after a key, and one trailing newline. Python's
/// `json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"` produces the same bytes.
///
/// Only null, booleans, integers, strings, arrays and objects are accepted. A number with a fractional part is an
/// error, in keeping with the rule that game values are never floating point.
public enum CanonicalJSON {
    /// Encodes `value` as canonical JSON text, ending in a newline.
    public static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        // Round-tripping through Foundation's coder gives a plain value tree without a hand-written `Encoder`.
        let node = try JSONDecoder().decode(Node.self, from: JSONEncoder().encode(value))
        var text = ""
        node.write(to: &text, indent: 0)
        text += "\n"
        return Data(text.utf8)
    }
}

private indirect enum Node: Decodable {
    case null
    case bool(Bool)
    case integer(Int64)
    case string(String)
    case array([Node])
    case object([String: Node])

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    init(from decoder: any Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: Key.self) {
            var members: [String: Node] = [:]
            for key in keyed.allKeys {
                members[key.stringValue] = try keyed.decode(Node.self, forKey: key)
            }
            self = .object(members)
        } else if var unkeyed = try? decoder.unkeyedContainer() {
            var elements: [Node] = []
            while !unkeyed.isAtEnd {
                elements.append(try unkeyed.decode(Node.self))
            }
            self = .array(elements)
        } else {
            let single = try decoder.singleValueContainer()
            if single.decodeNil() {
                self = .null
            } else if let value = try? single.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? single.decode(String.self) {
                self = .string(value)
            } else {
                // Last, so that a fractional or oversized number surfaces as this decode's own error.
                self = .integer(try single.decode(Int64.self))
            }
        }
    }

    func write(to text: inout String, indent: Int) {
        switch self {
        case .null:
            text += "null"
        case .bool(let value):
            text += value ? "true" : "false"
        case .integer(let value):
            text += String(value)
        case .string(let value):
            Node.writeQuoted(value, to: &text)
        case .array(let elements):
            Node.writeLines(elements, open: "[", close: "]", to: &text, indent: indent) { element, text in
                element.write(to: &text, indent: indent + 1)
            }
        case .object(let members):
            // UTF-8 byte order is code-point order, and unlike `String`'s `<` it ignores Unicode equivalence.
            let sorted = members.sorted { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }
            Node.writeLines(sorted, open: "{", close: "}", to: &text, indent: indent) { member, text in
                Node.writeQuoted(member.key, to: &text)
                text += ": "
                member.value.write(to: &text, indent: indent + 1)
            }
        }
    }

    private static func writeLines<Item>(
        _ items: [Item],
        open: String,
        close: String,
        to text: inout String,
        indent: Int,
        writeItem: (Item, inout String) -> Void
    ) {
        guard !items.isEmpty else {
            text += open + close
            return
        }
        let innerPadding = String(repeating: "  ", count: indent + 1)
        text += open
        for (index, item) in items.enumerated() {
            text += index == 0 ? "\n" : ",\n"
            text += innerPadding
            writeItem(item, &text)
        }
        text += "\n" + String(repeating: "  ", count: indent) + close
    }

    private static func writeQuoted(_ string: String, to text: inout String) {
        text += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": text += "\\\""
            case "\\": text += "\\\\"
            case "\n": text += "\\n"
            case "\r": text += "\\r"
            case "\t": text += "\\t"
            case "\u{08}": text += "\\b"
            case "\u{0C}": text += "\\f"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                text += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default:
                text.unicodeScalars.append(scalar)
            }
        }
        text += "\""
    }
}
