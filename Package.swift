// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GodotGameFactory",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "GodotGameFactory",
            targets: ["GodotGameFactoryApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "GodotGameFactoryApp",
            path: "Sources/GodotGameFactoryApp"
        ),
        .testTarget(
            name: "GodotGameFactoryAppTests",
            dependencies: ["GodotGameFactoryApp"],
            path: "Tests/GodotGameFactoryAppTests"
        ),
    ]
)
