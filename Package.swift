// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDFTool",
    platforms: [
        .iOS(.v18),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PDFTool",
            targets: ["PDFTool"]
        ),
        .library(
            name: "PDFToolRepository",
            targets: ["PDFToolRepository"]
        ),
    ],
    targets: [
        .target(
            name: "PDFTool",
            dependencies: [],
            path: "Sources/PDFTool"
        ),
        .target(
            name: "PDFToolRepository",
            dependencies: [],
            path: "Sources/PDFToolRepository"
        ),
        .testTarget(
            name: "PDFToolTests",
            dependencies: ["PDFTool"],
            path: "Tests/PDFToolTests"
        ),
        .testTarget(
            name: "PDFToolRepositoryTests",
            dependencies: ["PDFToolRepository"],
            path: "Tests/PDFToolRepositoryTests"
        ),
    ]
)