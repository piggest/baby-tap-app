// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BabyTap",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "BabyTap",
            path: "Sources/BabyTap",
            linkerSettings: [
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "MultitouchSupport",
                ])
            ]
        )
    ]
)
