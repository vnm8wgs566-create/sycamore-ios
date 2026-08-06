// swift-tools-version: 6.0
//
//  Package.swift
//  Sycamore
//
//  This package does not ship the app — `Sycamore.xcodeproj` does. It exists so the shared
//  sources can be typechecked and, now, **tested** without opening Xcode. Everything under
//  `Sycamore/` is written to compile for macOS as well as iOS, with the genuinely iOS-only APIs
//  (`presentationDetents`, `PhotosPicker`, `UIImpactFeedbackGenerator`, …) behind
//  `#if os(iOS)` / `#if canImport(UIKit)`.
//
//  The tests:
//
//      swift test
//
//  On a machine with Xcode selected (`xcode-select -p`) that is the whole command — the macro
//  plugins `#Preview` and `@Entry` need live inside Xcode, and `swift test` finds them there.
//
//  On a machine with only the Command Line Tools, two things get in the way, neither of them a
//  problem with the code:
//
//  1. The default SDK can be newer than the bundled compiler, which refuses it outright. Point
//     the build at a matching SDK:
//
//         SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk swift test
//
//  2. `#Preview` and `@Entry` report "plugin for module … not found", because those plugins are
//     not in the Command Line Tools at all. `Scripts/typecheck.sh` shims `#Preview`; it does not
//     yet shim `@Entry`, so that path currently stops in `DesignSystem/Components.swift`.
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
            // Info.plist and the entitlements are consumed by the Xcode target's build
            // settings — `INFOPLIST_FILE` and `CODE_SIGN_ENTITLEMENTS` — not by SwiftPM,
            // which would otherwise treat them as unhandled resources and warn on every build.
            //
            // `App/SycamoreApp.swift` is excluded for a different reason: it carries `@main`,
            // which synthesises a `_main` symbol into the library. The test bundle's runner
            // has one of its own, so linking the two together fails with `duplicate symbol
            // '_main'` and no test can run. Excluding the scene here rather than putting an
            // `#if !TESTING` around `@main` keeps the accommodation inside the build file
            // instead of inside the app. The file is still typechecked by
            // `Scripts/typecheck.sh`, which copies the whole tree, and compiled for real by
            // the Xcode target — which is the only build that ships it anyway.
            // The asset catalogue, the two variable fonts and their licence are shipped by the
            // Xcode target's synchronised group and loaded by name from the app bundle; nothing
            // reaches for `Bundle.module`. Declaring them as SwiftPM resources would build a
            // bundle nobody opens, so they are excluded — which also silences the "found 5
            // file(s) which are unhandled" warning on every `swift test`.
            exclude: [
                "Resources/Info.plist",
                "Resources/Sycamore.entitlements",
                "Resources/Assets.xcassets",
                "Resources/Fonts",
                "App/SycamoreApp.swift",
            ]
        ),
        // The app's tests. They live here rather than in an Xcode test target because
        // `Sycamore.xcodeproj` has none, and adding one means hand-editing `project.pbxproj`
        // — a file the whole team merges. A SwiftPM test target reaches exactly the same
        // internal symbols through `@testable import Sycamore`, needs no project change at
        // all, and runs anywhere `swift test` does.
        .testTarget(
            name: "SycamoreTests",
            dependencies: ["Sycamore"],
            path: "SycamoreTests"
        ),
    ],
    // Matches SWIFT_VERSION = 6.0 in the Xcode target. The module typechecks clean in this
    // mode — no strict-concurrency diagnostics anywhere in the design system, the store or
    // the feature views.
    swiftLanguageModes: [.v6]
)
