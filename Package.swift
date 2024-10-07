// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "EDFlib",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "EDFlib",
            targets: ["EDFlib"]
        ),
    ],
    targets: [
        .target(
            name: "EDFlib",
            path: "Sources"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
