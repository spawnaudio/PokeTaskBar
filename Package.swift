// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokeTaskBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PokeTaskBar",
            path: "Sources/PokeTaskBar",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "PokeTaskBarTests",
            dependencies: ["PokeTaskBar"],
            path: "Tests/PokeTaskBarTests",
            resources: [
                .copy("Fixtures/CodexFork"),
                .copy("Fixtures/CodexSubagent"),
            ]
        ),
    ]
)
