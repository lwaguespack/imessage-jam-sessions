// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RiffCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RiffCore", targets: ["RiffCore"]),
        .executable(name: "riffcli", targets: ["riffcli"]),
    ],
    targets: [
        .target(name: "RiffCore"),
        .executableTarget(name: "riffcli", dependencies: ["RiffCore"]),
        // Tests read the fixtures by path, so they are not bundled as resources.
        .testTarget(name: "RiffCoreTests", dependencies: ["RiffCore"], exclude: ["Fixtures"]),
    ],
    swiftLanguageModes: [.v6]
)
