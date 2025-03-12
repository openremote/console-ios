// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ORLib",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "ORLib",
            targets: ["ORLib"]),
    ],
    dependencies: [
        // No external dependencies required
    ],
    targets: [
        .target(
            name: "ORLib",
            dependencies: [],
            path: "ORLib",
            resources: [
                .process("Media.xcassets")
            ]
        ),
        .testTarget(
            name: "ORLibTests",
            dependencies: ["ORLib"],
            path: "Tests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
