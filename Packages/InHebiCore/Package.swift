// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "InHebiCore", platforms: [.tvOS(.v18), .iOS(.v18), .macOS(.v15)], products: [.library(name: "InHebiCore", targets: ["InHebiCore"])], dependencies: [.package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")], targets: [.target(name: "InHebiCore", dependencies: ["SwiftSoup"]), .testTarget(name: "InHebiCoreTests", dependencies: ["InHebiCore"], resources: [.copy("Fixtures")])])
