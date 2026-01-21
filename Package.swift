// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickVO",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "QuickVO",
            targets: ["QuickVOKit","QuickVO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.8"),
        .package(url: "https://github.com/motian30/WebRTC-iOS", from: "137.0.4"),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMinor(from: "1.32.0")),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "6.0.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.1.1"),
        .package(url: "https://github.com/motian30/SwiftNATDetector.git", from: "1.0.1"),
        .package(url: "https://github.com/quickvo/gpupixel-iOS.git", .upToNextMinor(from: "1.2.0")),
    ],
    targets: [
        .binaryTarget(name: "QuickVO", path: "QuickVO.xcframework"),
        .target(name: "QuickVOKit",dependencies: [
            "Starscream",
            "QuickVO",
            "SwiftyBeaver",
            "SwiftNATDetector",
            .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            .product(name: "Gzip", package: "GzipSwift"),
            .product(name: "WebRTC", package: "WebRTC-iOS"),
            .product(name: "gpupixel", package: "gpupixel-iOS", condition: .when(platforms: [.iOS])),
        ]),
          
    ],
    swiftLanguageVersions: [.v5]

)
