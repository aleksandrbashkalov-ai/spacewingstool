// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Spacewingstool",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spacewingstool", targets: ["Spacewingstool"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
    ],
    targets: [
        .executableTarget(
            name: "Spacewingstool",
            dependencies: [
                .product(name: "GRDB", package: "grdb.swift"),
            ],
            path: "Sources",
            exclude: ["Spacewingstool/Info.plist"],
            resources: [.process("Spacewingstool/Resources")]
        ),
        .testTarget(
            name: "SpacewingstoolTests",
            dependencies: ["Spacewingstool"]
        ),
    ]
)
