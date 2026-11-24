import Foundation
import iMessageRiffCore

enum ProgressionTestData {
    static func text() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        return try String(
            contentsOf: root.appendingPathComponent("iMessageRiffMessages/Resources/progression.json"), encoding: .utf8)
    }

    static func unlocks() throws -> Unlocks {
        try Unlocks(data: Data(text().utf8), config: .standard)
    }
}
