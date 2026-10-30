// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Parlez",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "4.2.1"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ParlezKit",
            dependencies: [
                .product(name: "Voz", package: "desert-ant-core"),
                .product(name: "Uhm", package: "desert-ant-core"),
                "KeyboardShortcuts",
            ]
        ),
        .executableTarget(name: "Parlez", dependencies: ["ParlezKit"]),
        .testTarget(
            name: "ParlezKitTests",
            dependencies: [
                "ParlezKit",
                .product(name: "Voz", package: "desert-ant-core"),
            ]
        ),
    ]
)
