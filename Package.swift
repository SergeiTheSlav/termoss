// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MobaXterm_macOS",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "MobaXterm_macOS",
            dependencies: ["SwiftTerm"],
            path: "MobaXterm_macOS",
            exclude: ["Resources"]
        ),
    ]
)
