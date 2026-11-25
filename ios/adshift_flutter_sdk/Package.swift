// swift-tools-version: 5.9

import PackageDescription

// The AdShift iOS SDK ships inside this package, in Frameworks/. The version is
// pinned in native_sdk.json at the root of the plugin.
let package = Package(
    name: "adshift_flutter_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "adshift-flutter-sdk", targets: ["adshift_flutter_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "adshift_flutter_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "AdshiftSDK",
            ]
        ),
        .binaryTarget(
            name: "AdshiftSDK",
            path: "Frameworks/AdshiftSDK.xcframework"
        ),
    ]
)
