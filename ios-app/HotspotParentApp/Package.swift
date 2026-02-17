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
  dependencies: [
    .package(url: "https://github.com/TimOliver/TOCropViewController.git", from: "2.7.4")
  ],
  targets: [
    .target(
      name: "HotspotParentApp",
      dependencies: [
        .product(name: "TOCropViewController", package: "TOCropViewController")
      ]
    ),
    .testTarget(
      name: "HotspotParentAppTests",
      dependencies: ["HotspotParentApp"],
      path: "Tests/HotspotParentAppTests"
    )
  ]
)
