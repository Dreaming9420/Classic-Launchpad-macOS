// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClassicLaunchpad",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ClassicLaunchpad", targets: ["ClassicLaunchpad"])
    ],
    targets: [
        .executableTarget(
            name: "ClassicLaunchpad",
            path: "ClassicLaunchpad",
            exclude: ["Info.plist", "Resources"]
        )
    ],
    swiftLanguageModes: [.v5]
)
