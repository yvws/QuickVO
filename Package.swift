// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickVO",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "QuickVO",
            targets: ["QuickVO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.8"),
        .package(url: "https://github.com/stasel/WebRTC", from: "129.0.0")
    ],
    targets: [
        .binaryTarget(name: "QuickVO", path: "QuickVO.xcframework"),
        .target(name: "QuickVOKit",dependencies: ["Starscream","WebRTC","QuickVO"]),
          
    ]



)
