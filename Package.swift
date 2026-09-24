// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Defaultly",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Defaultly", targets: ["Defaultly"]),
    ],
    targets: [
        .target(name: "DefaultlyCore"),
        .executableTarget(name: "Defaultly", dependencies: ["DefaultlyCore"]),
        .testTarget(name: "DefaultlyCoreTests", dependencies: ["DefaultlyCore"]),
        .testTarget(name: "DefaultlyTests", dependencies: ["Defaultly", "DefaultlyCore"]),
    ]
)
