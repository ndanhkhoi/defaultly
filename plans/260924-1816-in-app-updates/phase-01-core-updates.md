# Phase 1 — Core: versions, release feed, notes, changelog, verified install

## Files (new, `Sources/DefaultlyCore/Updates/`)
- `AppVersion.swift`: parse `1.2.3` / `v1.2.3`, compare numerically.
- `Release.swift`: `Release` + GitHub `/releases` decoding; `AvailableUpdate(releases:current:skipping:)` picks the highest newer stable release that has the zip and checksums.
- `ReleaseNotes.swift`: notes as blocks (heading, bullet, paragraph); keeps a release body's "What's changed" section only.
- `Changelog.swift`: parse `CHANGELOG.md` into entries (`## 1.2.3 - 2026-09-24`), skipping "Unreleased".
- `UpdateInstaller.swift`: `UpdateInstalling` port; download → SHA-256 against `SHA256SUMS.txt` → `ditto -x -k` into a new folder → validate bundle ID and version (Info.plist read from disk), signature (`RunningSignature`: ad hoc, Developer ID requirement, or refuse) → atomic `RENAME_SWAP` on the app's volume.
- `ReleaseSource.swift`: `ReleaseSource` port, `UpdateError`, and `GitHubReleaseClient` (URLSession: API, download with progress).
- `UpdateSchedule.swift`: a check is due a day after the last one.

## Tests
- Version ordering, feed selection (drafts, prereleases, skipped, missing assets), notes/changelog parsing, checksum parsing.
- Installer, on real ad-hoc signed bundles in temp folders: swap, failed swap keeps the old app, re-verification before install, wrong bundle ID/version, unsigned/modified apps, Developer ID team requirement, unreadable signature.
- Opt-in integration test (`DEFAULTLY_INTEGRATION=1`): prepare the real latest release from GitHub into a temp folder.

## Risks
- Quarantine carried onto the new bundle makes an ad-hoc app "damaged": move the new bundle in, never copy metadata from the old one.
- Translocated or read-only locations: detect up front and fall back to opening the release page.
