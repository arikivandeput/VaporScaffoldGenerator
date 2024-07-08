// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ScaffoldGenerator",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ScaffoldGenerator",
            dependencies: []),
       
    ]
)
