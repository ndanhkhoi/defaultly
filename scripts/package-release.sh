#!/usr/bin/env bash
# Packages dist/Defaultly.app as a zip and a dmg, plus SHA-256 checksums.
set -euo pipefail
cd "$(dirname "$0")/.."

app_name="Defaultly"
app="dist/$app_name.app"
[[ -d "$app" ]] || { echo "error: $app not found; run scripts/build-app.sh first" >&2; exit 1; }

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
zip="$app_name-$version.zip"
dmg="$app_name-$version.dmg"
rm -f "dist/$zip" "dist/$dmg" dist/SHA256SUMS.txt

ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$zip"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
# hdiutil occasionally fails with "Resource busy" on CI runners; a retry is enough.
for attempt in 1 2 3; do
    if hdiutil create -volname "$app_name" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "dist/$dmg" >/dev/null; then
        break
    fi
    [[ $attempt -lt 3 ]] || { echo "error: hdiutil create failed" >&2; exit 1; }
    sleep 5
done

(cd dist && shasum -a 256 "$zip" "$dmg" > SHA256SUMS.txt)
echo "Packaged dist/$zip and dist/$dmg"
