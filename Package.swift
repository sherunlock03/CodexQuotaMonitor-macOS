// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodexQuotaMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexQuotaMonitor", targets: ["CodexQuotaMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "CodexQuotaMonitor",
            path: "Sources/CodexQuotaMonitor"
        )
    ]
)
