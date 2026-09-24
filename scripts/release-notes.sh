#!/usr/bin/env bash
# Prints the GitHub release notes for a version: its section of CHANGELOG.md, the install notes, and a compare link.
# Fails when CHANGELOG.md has no section for the version, so a release can't ship without notes.
#   scripts/release-notes.sh 1.2.3 [previous-tag]
#   NOTARIZED=1   use the install notes for Developer ID signed, notarized builds
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/release-notes.sh <version> [previous-tag]}"
version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "error: version must look like 1.2.3, got '$version'" >&2
    exit 1
fi
previous="${2:-}"
repository="${GITHUB_REPOSITORY:-ndanhkhoi/defaultly}"

# The lines under "## <version> - <date>" (or "## [<version>] …"), up to the next "## " heading,
# without leading blank lines; command substitution drops the trailing ones.
changes="$(awk -v version="$version" '
    /^## / { if (found) exit; heading = $2; gsub(/[][]/, "", heading); found = (heading == version); next }
    found && (started || NF) { started = 1; print }
' CHANGELOG.md)"
if [[ -z "${changes//[[:space:]]/}" ]]; then
    echo "error: CHANGELOG.md has no notes for $version; add a '## $version - YYYY-MM-DD' section" >&2
    exit 1
fi

install_notes=.github/install-notes.md
if [[ "${NOTARIZED:-0}" == 1 ]]; then install_notes=.github/install-notes-notarized.md; fi

printf "## What's changed\n\n%s\n\n" "$changes"
cat "$install_notes"
if [[ -n "$previous" ]]; then
    printf '\n**Full Changelog**: https://github.com/%s/compare/%s...v%s\n' "$repository" "$previous" "$version"
fi
