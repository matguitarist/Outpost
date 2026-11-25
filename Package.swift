// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Outpost",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        // The Activity Log's viewer, shared by my Mac apps.
        .package(url: "https://github.com/matguitarist/LogKit", from: "0.6.0"),
        // Runs ssh, shared by my Mac apps.
        .package(url: "https://github.com/matguitarist/ProcessKit", from: "0.1.1"),
    ],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "OutpostKit", dependencies: [.product(name: "LogKit", package: "LogKit"),
                                                   .product(name: "ProcessKit", package: "ProcessKit")]),
        .executableTarget(
            name: "Outpost",
            dependencies: ["OutpostKit", .product(name: "Sparkle", package: "Sparkle"),
                           .product(name: "LogKitUI", package: "LogKit")],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)],
            // Sparkle.framework sits in Contents/Frameworks (build.sh copies it).
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "OutpostKitTests", dependencies: ["OutpostKit", .product(name: "LogKit", package: "LogKit")]),
    ]
)
