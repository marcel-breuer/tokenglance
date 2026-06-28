// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "TokenGlance",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "TokenGlanceCore", targets: ["TokenGlanceCore"]),
    .executable(name: "TokenGlance", targets: ["TokenGlance"]),
  ],
  targets: [
    .target(
      name: "TokenGlanceCore",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ],
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    ),
    .executableTarget(
      name: "TokenGlance",
      dependencies: ["TokenGlanceCore"],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "TokenGlanceCoreTests",
      dependencies: ["TokenGlanceCore"],
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ]
)
