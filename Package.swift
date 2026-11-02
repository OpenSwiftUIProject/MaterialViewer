// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MaterialViewer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MaterialViewerKit", targets: ["MaterialViewerKit"]),
        .executable(name: "materialviewer", targets: ["MaterialViewerCLI"])
    ],
    targets: [
        .target(name: "MaterialViewerKit", dependencies: ["MaterialRuntime"]),
        .target(
            name: "MaterialRuntime",
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("QuartzCore")]
        ),
        .executableTarget(
            name: "MaterialViewerCLI",
            dependencies: ["MaterialViewerKit"]
        ),
        .testTarget(name: "MaterialViewerKitTests", dependencies: ["MaterialViewerKit"])
    ]
)
