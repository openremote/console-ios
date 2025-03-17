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
        .package(
            name: "ESPProvision",
            url: "https://github.com/espressif/esp-idf-provisioning-ios.git",
            "3.0.2" ..< "4.0.0"
        )
    ],
    targets: [
        .target(
            name: "ORLib",
            dependencies: ["ESPProvision"],
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
