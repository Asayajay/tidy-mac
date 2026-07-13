// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TidyMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TidyMacCore", targets: ["TidyMacCore"]),
        .executable(name: "TidyMac", targets: ["TidyMac"])
    ],
    targets: [
        .target(
            name: "TidyMacCore",
            dependencies: []
        ),
        .executableTarget(
            name: "TidyMac",
            dependencies: ["TidyMacCore"]
        ),
        .testTarget(
            name: "TidyMacCoreTests",
            dependencies: ["TidyMacCore"]
        )
    ]
)
