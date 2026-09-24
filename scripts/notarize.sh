#!/usr/bin/env bash
# Submits a signed .zip, .dmg or .pkg to Apple's notary service, waits for the verdict, then staples the ticket
# to <staple-target>, or to the file itself when it is a dmg or pkg (a zip can't be stapled; pass the app inside).
#   scripts/notarize.sh <file> [staple-target]
#   APPLE_ID             Apple Account email of the developer
#   APPLE_APP_PASSWORD   app-specific password for that account
#   APPLE_TEAM_ID        10-character team ID
set -euo pipefail

file="${1:?usage: scripts/notarize.sh <file> [staple-target]}"
target="${2:-}"
if [[ -z "$target" && ( "$file" == *.dmg || "$file" == *.pkg ) ]]; then target="$file"; fi
: "${APPLE_ID:?APPLE_ID is not set}" "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD is not set}" "${APPLE_TEAM_ID:?APPLE_TEAM_ID is not set}"
credentials=(--apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID")

result="$(mktemp)"
trap 'rm -f "$result"' EXIT
echo "Notarizing $(basename "$file")…"
xcrun notarytool submit "$file" "${credentials[@]}" --wait --timeout 30m --output-format json > "$result" || true
status="$(plutil -extract status raw "$result" 2>/dev/null || echo unknown)"
submission="$(plutil -extract id raw "$result" 2>/dev/null || true)"

if [[ "$status" != "Accepted" ]]; then
    echo "error: notarization of $(basename "$file") ended with status '$status'" >&2
    cat "$result" >&2
    if [[ -n "$submission" ]]; then xcrun notarytool log "$submission" "${credentials[@]}" >&2 || true; fi
    exit 1
fi

echo "Notarized $(basename "$file")"
if [[ -n "$target" ]]; then
    # Right after acceptance the ticket may not be published yet ("Record not found"), so try a few times.
    for attempt in 1 2 3 4 5; do
        if xcrun stapler staple "$target"; then break; fi
        [[ $attempt -lt 5 ]] || { echo "error: couldn't staple $(basename "$target")" >&2; exit 1; }
        sleep 20
    done
fi
