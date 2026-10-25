// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageUnderstanding",
    // The 26 floors let a tool that links this still run there (vid analyze
    // skips scene descriptions on 26): FoundationModels' image input is
    // 27-only, so the API is `@available(macOS 27, …)` and the call sites
    // check. Unavailable on tvOS entirely.
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v26),
        .watchOS(.v26)
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
