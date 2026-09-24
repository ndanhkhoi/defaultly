#!/usr/bin/env bash
# Builds dist/Defaultly.app.
#   VERSION=1.2.3        marketing version (default: latest git tag, else 0.0.0)
#   BUILD_NUMBER=42      build number (default: commit count)
#   ARCHS="arm64 x86_64" architectures to include (default: this Mac's)
set -euo pipefail
cd "$(dirname "$0")/.."

app_name="Defaultly"
version="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
version="${version#v}"
build_number="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
archs="${ARCHS:-$(uname -m)}"
app="dist/$app_name.app"

sdk="$(scripts/sdk-root.sh)"
if [[ -n "$sdk" ]]; then export SDKROOT="$sdk"; fi

# Newer SwiftPM builds every architecture into the same folder, so keep each binary as it's built.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
binaries=()
for arch in $archs; do
    swift build -c release --arch "$arch" --product "$app_name"
    cp "$(swift build -c release --arch "$arch" --show-bin-path)/$app_name" "$work/$app_name-$arch"
    binaries+=("$work/$app_name-$arch")
done

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/$app_name"
sed -e "s/__VERSION__/$version/" -e "s/__BUILD__/$build_number/" Resources/Info.plist > "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
cp -R Resources/en.lproj Resources/vi.lproj "$app/Contents/Resources/"

# Ad-hoc signature: no Developer ID, but a valid, sealed bundle.
codesign --force --sign - "$app"
codesign --verify --strict "$app"

echo "Built $app $version ($build_number) for $(lipo -archs "$app/Contents/MacOS/$app_name")"
