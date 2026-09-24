#!/usr/bin/env bash
# Prints the SDK to build with, or nothing to use the default.
# With Command Line Tools only, newer SDKs need a SwiftUI macro plugin that ships with Xcode;
# the macOS 26 SDK builds without it. Xcode (as on CI) always uses its own default SDK.
set -euo pipefail

developer_dir="$(xcode-select -p 2>/dev/null || true)"
sdk="$developer_dir/SDKs/MacOSX26.sdk"
if [[ "$developer_dir" == *CommandLineTools* && -d "$sdk" ]]; then
    echo "$sdk"
fi
