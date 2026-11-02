// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "Woss",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic: no AppKit, fully unit-testable.
        .target(name: "WossCore"),
        // The actual menu bar app.
        .executableTarget(name: "Woss", dependencies: ["WossCore"]),
        .testTarget(name: "WossCoreTests", dependencies: ["WossCore"]),
    ]
)
