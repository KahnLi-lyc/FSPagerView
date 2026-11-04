// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FSPagerView",
    platforms: [.iOS(.v16)],
    products: [.library(name: "FSPagerView", targets: ["FSPagerView"])],
    targets: [
        .target(
            name: "FSPagerView",
            path: "Sources",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "FSPagerViewTests", dependencies: ["FSPagerView"]),
    ],
    swiftLanguageModes: [.v6]
)
