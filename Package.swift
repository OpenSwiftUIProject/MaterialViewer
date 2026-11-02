// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MaterialRecipeViewer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MaterialRecipeViewer", targets: ["MaterialRecipeViewer"])
    ],
    targets: [
        .target(name: "RecipeKit"),
        .target(
            name: "MaterialRuntime",
            cSettings: [.unsafeFlags(["-fobjc-arc"])],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("QuartzCore")]
        ),
        .executableTarget(
            name: "MaterialRecipeViewer",
            dependencies: ["RecipeKit", "MaterialRuntime"]
        ),
        .testTarget(name: "RecipeKitTests", dependencies: ["RecipeKit"])
    ]
)
