// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageUnderstanding",
    // FoundationModels image input needs the 27-era SDKs, and is unavailable
    // on tvOS entirely.
    platforms: [
        .macOS("27.0"),
        .iOS("27.0"),
        .visionOS("27.0"),
        .watchOS("27.0")
    ],
    products: [
        .library(
            name: "ImageUnderstanding",
            targets: ["ImageUnderstanding"]
        ),
    ],
    targets: [
        .target(
            name: "ImageUnderstanding"
        ),
        .testTarget(
            name: "ImageUnderstandingTests",
            dependencies: ["ImageUnderstanding"]
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
