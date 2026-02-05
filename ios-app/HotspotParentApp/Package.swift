// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "HotspotParentApp",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(name: "HotspotParentApp", targets: ["HotspotParentApp"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "HotspotParentApp",
      dependencies: []
    ),
    .testTarget(
      name: "HotspotParentAppTests",
      dependencies: ["HotspotParentApp"]
    )
  ]
)
