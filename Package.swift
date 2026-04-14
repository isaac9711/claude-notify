// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeNotify",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeNotify",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ClaudeNotify",
            linkerSettings: [
                .linkedFramework("SkyLight"),
                .unsafeFlags([
                    "-F", "/System/Library/PrivateFrameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .executableTarget(
            name: "ClaudeNotifySend",
            path: "Sources/ClaudeNotifySend"
        )
    ]
)
