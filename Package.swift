// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CornucopiaDBUI",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CornucopiaDBUI",
            targets: ["CornucopiaDBUI"]),
    ],
    dependencies: [
        .package(name: "CornucopiaDB", url: "https://github.com/Cornucopia-Swift/CornucopiaDB", .branch("master")),
        .package(name: "Swift-YapDatabase", url: "https://github.com/mickeyl/SwiftYapDatabase", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CornucopiaDBUI",
            dependencies: [
                "CornucopiaDB",
                .product(name: "YapDatabase", package: "Swift-YapDatabase")
            ]
        ),
        .testTarget(
            name: "CornucopiaDBUITests",
            dependencies: ["CornucopiaDBUI"]
        ),
    ]
)
