// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iMessageRiffCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "iMessageRiffCore", targets: ["iMessageRiffCore"]),
        .executable(name: "imessageriffcli", targets: ["imessageriffcli"]),
    ],
    targets: [
        .target(name: "iMessageRiffCore"),
        .executableTarget(name: "imessageriffcli", dependencies: ["iMessageRiffCore"]),
        // Tests read the fixtures by path, so they are not bundled as resources.
        .testTarget(name: "iMessageRiffCoreTests", dependencies: ["iMessageRiffCore"], exclude: ["Fixtures"]),
    ],
    swiftLanguageModes: [.v6]
)
