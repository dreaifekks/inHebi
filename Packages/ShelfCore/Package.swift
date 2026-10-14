// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ShelfCore", platforms: [.tvOS(.v18), .iOS(.v18), .macOS(.v15)], products: [.library(name: "ShelfCore", targets: ["ShelfCore"])], dependencies: [.package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")], targets: [.target(name: "ShelfCore", dependencies: ["SwiftSoup"]), .testTarget(name: "ShelfCoreTests", dependencies: ["ShelfCore"], resources: [.copy("Fixtures")])])
