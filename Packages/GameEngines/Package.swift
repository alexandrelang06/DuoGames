// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameEngines",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "BattleshipEngine", targets: ["BattleshipEngine"]),
        .library(name: "AirHockeyEngine", targets: ["AirHockeyEngine"]),
        .library(name: "PostureKit", targets: ["PostureKit"]),
        .library(name: "Diagnostics", targets: ["Diagnostics"]),
        .library(name: "MillEngine", targets: ["MillEngine"]),
        .library(name: "TronEngine", targets: ["TronEngine"]),
        .library(name: "DraughtsEngine", targets: ["DraughtsEngine"]),
        .library(name: "ChessEngine", targets: ["ChessEngine"]),
        .library(name: "AppFlow", targets: ["AppFlow"]),
    ],
    targets: [
        .target(name: "BattleshipEngine", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "AirHockeyEngine", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "PostureKit", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "Diagnostics", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "MillEngine", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "TronEngine", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "DraughtsEngine", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "ChessEngine", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "AppFlow", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "BattleshipEngineTests", dependencies: ["BattleshipEngine"]),
        .testTarget(name: "AirHockeyEngineTests", dependencies: ["AirHockeyEngine"]),
        .testTarget(name: "DiagnosticsTests", dependencies: ["Diagnostics"]),
        .testTarget(name: "MillEngineTests", dependencies: ["MillEngine"]),
        .testTarget(name: "TronEngineTests", dependencies: ["TronEngine"]),
        .testTarget(name: "DraughtsEngineTests", dependencies: ["DraughtsEngine"]),
        .testTarget(name: "ChessEngineTests", dependencies: ["ChessEngine"]),
        .testTarget(name: "AppFlowTests", dependencies: ["AppFlow"]),
    ]
)
