#!/bin/zsh
#
# Typecheck the whole app without Xcode.
#
# This machine has Command Line Tools only — no iOS SDK, no simulator, no xcodebuild —
# so `swift build` is not the verification path here. Two things stand in the way and
# this script works around both:
#
#   1. `#Preview` is a macro whose plugin (PreviewsMacros) ships inside Xcode. Without it
#      every preview is a hard error. We rewrite each `#Preview { … }` into a function
#      taking the same `@ViewBuilder @MainActor` closure, so preview bodies are still
#      typechecked rather than skipped.
#
#   2. `#if os(iOS)` branches are invisible to a macOS build. But the macOS SDK ships the
#      Mac Catalyst slice under `SDKs/MacOSX*.sdk/System/iOSSupport`, and targeting
#      `arm64-apple-ios17.0-macabi` makes both `os(iOS)` and `canImport(UIKit)` true —
#      so the iOS half of the tree compiles for real.
#
# Usage:  Scripts/typecheck.sh [macos|ios|both]   (default: both)
#
# Neither pass links or runs anything; this is `-typecheck` only. It is not a substitute
# for building in Xcode, but it does catch every type, concurrency and API error.

set -e

ROOT=${0:A:h:h}
MODE=${1:-both}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Pick the newest SDK this compiler can actually consume. The newest SDK on disk is not
# necessarily usable: Command Line Tools ship SDKs built by a later Swift than the bundled
# compiler, and those fail with "this SDK is not supported by the compiler". So probe from
# newest to oldest and take the first that typechecks a trivial file.
print '_ = 1' > "$WORK/.probe.swift"
SDK=""
for candidate in ${(f)"$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null \
                         | grep -E 'MacOSX[0-9]+\.[0-9]+\.sdk' | sort -Vr)"}; do
  if swiftc -typecheck -sdk "$candidate" -target arm64-apple-macos14.0 \
       "$WORK/.probe.swift" >/dev/null 2>&1; then
    SDK=$candidate
    break
  fi
done
if [[ -z "$SDK" ]]; then
  print -u2 "no macOS SDK under /Library/Developer/CommandLineTools/SDKs works with $(swiftc --version | head -1)"
  exit 1
fi

cp -R "$ROOT/Sycamore" "$WORK/Sycamore"

python3 - "$WORK" <<'PY'
import sys, re, pathlib

root = pathlib.Path(sys.argv[1], "Sycamore")
count = 0
for path in root.rglob("*.swift"):
    text = path.read_text()
    if "#Preview" not in text:
        continue
    out, depth = [], 0
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("#Preview"):
            stripped = line.strip()
            match = re.match(r'^#Preview\s*(\((.*)\))?\s*\{$', stripped)
            if not match:
                raise SystemExit(f"unhandled #Preview form: {stripped} in {path}")
            count += 1
            out.append("private func __pv%d() { __PreviewShim(%s) {\n" % (count, match.group(2) or ""))
            depth = 1
        elif depth == 1 and line.rstrip("\n") == "}":
            out.append("} }\n")
            depth = 0
        else:
            out.append(line)
    path.write_text("".join(out))

(root / "__PreviewShim.swift").write_text('''import SwiftUI

// Stand-in for SwiftUI's `#Preview` macro, whose plugin ships only inside Xcode.
// Same shape as the real macro's body closure, so preview contents typecheck identically.
func __PreviewShim<V: View>(
    _ name: String = "",
    @ViewBuilder body: @escaping @MainActor () -> V
) -> Void { _ = name; _ = body }
''')
print(f"rewrote {count} previews", file=sys.stderr)
PY

cd "$WORK"
SOURCES=($(find Sycamore -name '*.swift'))

typecheck() {
  local target=$1 label=$2
  shift 2
  print "── $label ($target)"
  swiftc -typecheck -parse-as-library -swift-version 6 \
    -target "$target" -sdk "$SDK" -module-name Sycamore "$@" "${SOURCES[@]}"
  print "   ok"
}

# The Catalyst slice lives in a sysroot-within-the-sysroot; Swift and the Clang importer
# each need to be pointed at it explicitly, or ObjC frameworks (PhotosUI -> UIKit) fail
# to resolve against the macOS headers.
IOS_SUPPORT="$SDK/System/iOSSupport"
CATALYST_FLAGS=(
  -Fsystem "$IOS_SUPPORT/System/Library/Frameworks"
  -I       "$IOS_SUPPORT/usr/lib/swift"
  -Xcc -iframework -Xcc "$IOS_SUPPORT/System/Library/Frameworks"
  -Xcc -isystem    -Xcc "$IOS_SUPPORT/usr/include"
)

[[ "$MODE" == "macos" || "$MODE" == "both" ]] && typecheck arm64-apple-macos14.0 "macOS"
[[ "$MODE" == "ios"   || "$MODE" == "both" ]] && \
  typecheck arm64-apple-ios17.0-macabi "iOS (Catalyst slice)" "${CATALYST_FLAGS[@]}"

print "\ntypecheck clean — $SDK"
