// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoldPrice",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "GoldPrice",
            path: "Sources"
        )
    ]
)
