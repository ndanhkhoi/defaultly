#!/usr/bin/env bash
# Prints extra flags for `swift build` and `swift test`, or nothing when no SDK override is used (Xcode, as on CI).
# With the SDK from scripts/sdk-root.sh, SwiftPM links without SDKROOT in the environment, so clang records the
# deployment target (14.0) as the SDK version. SwiftUI then keeps its macOS 14 behavior, and a local build looks and
# lays out unlike the release (no Liquid Glass). Giving the linking clang -isysroot records the SDK's real version.
set -euo pipefail
cd "$(dirname "$0")/.."

sdk="$(scripts/sdk-root.sh)"
if [[ -n "$sdk" ]]; then
    echo "-Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc $sdk"
fi
