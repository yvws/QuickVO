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
        .package(url: "https://github.com/quickvo/WebRTC-iOS.git", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.32.0"),
        .package(url: "https://github.com/1024jp/GzipSwift", from: "6.0.0"),
        .package(url: "https://github.com/quickvo/SwiftNATDetector", from: "0.0.1"),
        .package(url: "https://github.com/quickvo/gpupixel-iOS.git", from: "1.2.5"),
        // Crash capture. `Recording` for the recording engine and its monitors, `Filters` for the
        // Apple-format report renderer. KSCrash's own report senders (`Installations`, `Sinks`) are
        // not used, because delivery is injected rather than built in.
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.6.0"),
    ],
    targets: [
        .binaryTarget(name: "QuickVO", path: "QuickVO.xcframework"),
        .target(name: "QuickVOKit",dependencies: [
            "Starscream",
            "QuickVO",
            "SwiftNATDetector",
            .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            .product(name: "Gzip", package: "GzipSwift"),
            .product(name: "WebRTC", package: "WebRTC-iOS"),
            .product(name: "gpupixel", package: "gpupixel-iOS", condition: .when(platforms: [.iOS])),
            .product(name: "Recording", package: "KSCrash"),
            .product(name: "Filters", package: "KSCrash"),
        ]),
          
    ],
    swiftLanguageVersions: [.v5]

)
