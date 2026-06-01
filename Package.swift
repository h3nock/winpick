// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "winpick",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "winpick", targets: ["winpick"]),
        .library(name: "WinpickCore", targets: ["WinpickCore"]),
    ],
    targets: [
        .target(
            name: "WinpickCore"
        ),
        .executableTarget(
            name: "winpick",
            dependencies: ["WinpickCore"]
        ),
        .testTarget(
            name: "winpickTests",
            dependencies: ["WinpickCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
