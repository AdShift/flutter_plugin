// swift-tools-version: 5.9
import PackageDescription

// Tests for the bridge rules in Core. Those need neither the AdShift SDK nor
// Flutter, so `swift test` runs them on a Mac without a simulator. The plugin
// itself is the package in adshift_flutter_sdk/.
let package = Package(
  name: "AdshiftBridgeCore",
  targets: [
    .target(
      name: "AdshiftBridgeCore",
      path: "adshift_flutter_sdk/Sources/adshift_flutter_sdk/Core"
    ),
    .testTarget(
      name: "AdshiftBridgeCoreTests",
      dependencies: ["AdshiftBridgeCore"],
      path: "Tests/AdshiftBridgeCoreTests"
    ),
  ]
)
