// swift-tools-version: 6.0
//
//  Package.swift
//  Sycamore
//
//  This package does not ship the app — `Sycamore.xcodeproj` does. It exists so the shared
//  sources can be typechecked with `swift build` on a machine that has only the Command Line
//  Tools installed (no Xcode, no iOS SDK, no simulator). Everything under `Sycamore/` is
//  written to compile for macOS as well as iOS, with the genuinely iOS-only APIs
//  (`presentationDetents`, `PhotosPicker`, `UIImpactFeedbackGenerator`, …) behind
//  `#if os(iOS)` / `#if canImport(UIKit)`.
//
//  The app's `Info.plist` is excluded: SwiftPM would otherwise treat it as an unhandled
//  resource and refuse to build.
//
//  Two things about this machine's toolchain, neither of which is a problem with the code:
//
//  1. The default SDK (MacOSX26.2) is newer than the installed compiler (Swift 6.1.2), which
//     refuses it outright. Point the build at a matching SDK:
//
//         SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk swift build
//
//  2. The `#Preview` macro's plugin ships inside Xcode, not the Command Line Tools, so every
//     `#Preview` in the module reports "plugin for module 'PreviewsMacros' not found" here.
//     Those errors say nothing about the previews themselves.
//

import PackageDescription

let package = Package(
    name: "Sycamore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Sycamore", targets: ["Sycamore"])
    ],
    targets: [
        .target(
            name: "Sycamore",
            path: "Sycamore",
            // Both are consumed by the Xcode target's build settings — `INFOPLIST_FILE` and
            // `CODE_SIGN_ENTITLEMENTS` — not by SwiftPM, which would otherwise treat them as
            // unhandled resources and warn on every build.
            exclude: ["Resources/Info.plist", "Resources/Sycamore.entitlements"]
        )
    ],
    // Matches SWIFT_VERSION = 6.0 in the Xcode target. The module typechecks clean in this
    // mode — no strict-concurrency diagnostics anywhere in the design system, the store or
    // the feature views.
    swiftLanguageModes: [.v6]
)
