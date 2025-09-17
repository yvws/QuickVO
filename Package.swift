// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickVO",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "QuickVO",
            targets: ["QuickVOKit","QuickVO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.8"),
        .package(url: "https://github.com/stasel/WebRTC", from: "137.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.2"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "6.0.0"),
        .package(url: "https://github.com/motian30/GPUPixelLib.git", from: "1.0.4"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.1.1"),
        .package(url: "https://github.com/motian30/SwiftNATDetector.git", from: "1.0.1"),
    ],
    targets: [
        .binaryTarget(name: "QuickVO", path: "QuickVO.xcframework"),
        .target(name: "QuickVOKit",dependencies: [
            "Starscream",
            "WebRTC",
            "QuickVO",
            "SwiftyBeaver",
            "SwiftNATDetector",
            .product(name: "GPUPixelLib", package: "GPUPixelLib", condition: .when(platforms: [.iOS])),
            .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            .product(name: "Gzip", package: "GzipSwift"),

        ]),
          
    ],
    swiftLanguageVersions: [.v5]

)
