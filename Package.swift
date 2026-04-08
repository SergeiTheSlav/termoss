// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Termoss",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Termoss",
            dependencies: ["SwiftTerm"],
            path: "Termoss_macOS",
            exclude: ["Resources"]
        ),
    ]
)
