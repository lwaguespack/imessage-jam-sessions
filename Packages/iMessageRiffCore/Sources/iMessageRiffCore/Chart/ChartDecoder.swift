import Foundation

/// Reads a chart file, refusing anything the format does not define (CHART_FORMAT section 1).
public enum ChartDecoder {
    /// Why a file is not a chart this build can read.
    public enum Failure: Error, Equatable {
        /// Not JSON, or a field is missing or has the wrong type. The text says which.
        case malformed(String)

        case unknownFormat(String)
        case unsupportedVersion(Int)

        /// The file has a field the format does not define, or an explicit null, at this path.
        case unknownField(String)
    }

    private struct Header: Decodable {
        var format: String
        var version: Int
    }

    public static func decode(_ data: Data) throws -> Chart {
        // Read as a tree as well: it tells bad JSON from a bad chart and shows what the typed read ignored.
        guard let written = try? JSONSerialization.jsonObject(with: data) else {
            throw Failure.malformed("not valid JSON")
        }
        let chart: Chart
        do {
            // Format and version first, so a newer file is reported as such and not as a missing field.
            let header = try JSONDecoder().decode(Header.self, from: data)
            guard header.format == Chart.formatName else { throw Failure.unknownFormat(header.format) }
            guard header.version == IMessageRiffCoreInfo.chartSchemaVersion else {
                throw Failure.unsupportedVersion(header.version)
            }
            chart = try JSONDecoder().decode(Chart.self, from: data)
        } catch let error as DecodingError {
            throw Failure.malformed(describe(error, written: written))
        }
        // A misspelt optional key, such as a hold's `length`, would otherwise be dropped without a word.
        let understood = try JSONSerialization.jsonObject(with: JSONEncoder().encode(chart))
        if let path = firstExtraField(in: written, comparedWith: understood, path: "") {
            throw Failure.unknownField(path)
        }
        return chart
    }

    private static func describe(_ error: DecodingError, written: Any) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "\(path(context.codingPath + [key])) is missing"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "\(path(context.codingPath)) has the wrong type"
        case .dataCorrupted(let context):
            // Foundation reports a fraction or an oversized number without a path on some platforms.
            if let place = firstFraction(in: written, path: "") {
                return "\(place) is not a whole number, or is too large"
            }
            guard !context.codingPath.isEmpty else { return "a value cannot be read" }
            return "\(path(context.codingPath)) cannot be read"
        @unknown default:
            return "cannot be read"
        }
    }

    /// The path of the first number that is not a whole number an `Int` can hold; every number in a chart is one.
    private static func firstFraction(in value: Any, path: String) -> String? {
        if let members = value as? [String: Any] {
            for (key, member) in members.sorted(by: { $0.key < $1.key }) {
                let memberPath = path.isEmpty ? key : path + "." + key
                if let found = firstFraction(in: member, path: memberPath) { return found }
            }
        } else if let elements = value as? [Any] {
            for (index, element) in elements.enumerated() {
                if let found = firstFraction(in: element, path: path + "[\(index)]") { return found }
            }
        } else if let number = value as? NSNumber, Int(exactly: number.doubleValue) == nil {
            return path
        }
        return nil
    }

    private static func path(_ keys: [any CodingKey]) -> String {
        var text = ""
        for key in keys {
            if let index = key.intValue {
                text += "[\(index)]"
            } else {
                text += text.isEmpty ? key.stringValue : "." + key.stringValue
            }
        }
        return text.isEmpty ? "the file" : text
    }

    /// The path of the first member `written` has and `understood` lacks, taking keys in sorted order.
    private static func firstExtraField(in written: Any, comparedWith understood: Any, path: String) -> String? {
        if let written = written as? [String: Any], let understood = understood as? [String: Any] {
            for (key, value) in written.sorted(by: { $0.key < $1.key }) {
                let memberPath = path.isEmpty ? key : path + "." + key
                guard let match = understood[key] else { return memberPath }
                if let found = firstExtraField(in: value, comparedWith: match, path: memberPath) {
                    return found
                }
            }
        } else if let written = written as? [Any], let understood = understood as? [Any] {
            for (index, (value, match)) in zip(written, understood).enumerated() {
                if let found = firstExtraField(in: value, comparedWith: match, path: path + "[\(index)]") {
                    return found
                }
            }
        }
        return nil
    }
}
