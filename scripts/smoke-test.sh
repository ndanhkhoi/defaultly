#!/usr/bin/env bash
# Launches a debug build and lets SmokeTest drive every screen; fails on a crash or a hang.
set -euo pipefail
cd "$(dirname "$0")/.."

sdk="$(scripts/sdk-root.sh)"
if [[ -n "$sdk" ]]; then export SDKROOT="$sdk"; fi
swift_flags="$(scripts/swift-flags.sh)"

# shellcheck disable=SC2086 # the flags are separate words; the SDK path has no spaces
swift build $swift_flags --product Defaultly
binary="$(swift build --show-bin-path)/Defaultly"

DEFAULTLY_SMOKE_TEST=1 "$binary" &
pid=$!
( sleep "${SMOKE_TIMEOUT:-180}"; echo "error: smoke test timed out" >&2; kill -9 "$pid" ) 2>&1 &
watchdog=$!

status=0
wait "$pid" || status=$?
# Stop the watchdog and its sleep, which would otherwise keep the output pipe open.
pkill -P "$watchdog" 2>/dev/null || true
kill "$watchdog" 2>/dev/null || true
if [[ $status -ne 0 ]]; then
    echo "error: smoke test failed (exit $status)" >&2
    exit "$status"
fi
