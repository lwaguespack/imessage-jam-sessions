import Foundation
import RiffCore
import Testing

@Suite("Package info")
struct RiffCoreInfoTests {
    /// `Config/Base.xcconfig` at the repository root, five levels above this file.
    private static let baseXcconfig: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
        }
        return url.appendingPathComponent("Config").appendingPathComponent("Base.xcconfig")
    }()

    @Test("The version is three dot-separated numbers")
    func versionIsSemantic() {
        let parts = RiffCoreInfo.version.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0).map { $0 >= 0 } ?? false })
    }

    @Test("Current schema versions are pinned")
    func schemaVersionsArePositive() {
        #expect(RiffCoreInfo.payloadSchemaVersion == 2)
        #expect(RiffCoreInfo.chartSchemaVersion == 1)
    }

    // Skipped when the package is checked out on its own, without the Xcode project around it.
    @Test(
        "The version equals MARKETING_VERSION in Config/Base.xcconfig",
        .enabled(if: FileManager.default.fileExists(atPath: baseXcconfig.path))
    )
    func versionMatchesXcodeProject() throws {
        let settings = try String(contentsOf: Self.baseXcconfig, encoding: .utf8)
        let values = settings.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let setting = line.prefix { $0 != "/" }.split(separator: "=", maxSplits: 1)
            guard setting.count == 2, setting[0].trimmingCharacters(in: .whitespaces) == "MARKETING_VERSION" else {
                return nil
            }
            return setting[1].trimmingCharacters(in: .whitespaces)
        }
        #expect(values == [RiffCoreInfo.version])
    }
}
