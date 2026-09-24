---
title: In-app updates, changelog and notarization-ready releases
description: >-
  Check GitHub Releases for new versions, install them in place with verification,
  show release notes (update window, What's New, Help → Release Notes) from CHANGELOG.md,
  and let CI sign with a Developer ID and notarize when Apple credentials are configured.
status: completed
priority: P1
branch: main
tags: [feature, macos, updates, ci]
created: '2026-09-24T18:16:00+07:00'
---

# In-app updates, changelog and notarization-ready releases

## Decisions (agreed with the project owner, 2026-09-24)

| Topic | Choice | Rejected |
|-------|--------|----------|
| Update engine | Own updater on the GitHub Releases API: no dependency, SwiftUI UI, fits the SwiftPM + Command Line Tools build | Sparkle 2: binary framework to embed by hand, appcast + EdDSA key in CI, AppKit UI |
| Default behavior | Check automatically once a day; ask before installing (notes + Install / Later / Skip). Opt-in setting: download in the background and install on quit | Silent download (gonhanh style); opt-in on first launch |
| Changelog | `CHANGELOG.md` is the single source: CI extracts the tag's section into the release notes; the app bundles it for What's New and Help → Release Notes | GitHub release notes only |
| Gatekeeper | Releases stay ad-hoc signed; CI signs with a Developer ID and notarizes when Apple secrets exist | — |

## Why updates don't trigger Gatekeeper again
Gatekeeper only assesses quarantined files. Files the app downloads itself with `URLSession` (no `LSFileQuarantineEnabled`)
carry only `com.apple.provenance`, verified on macOS 27. So users allow Defaultly once; later versions installed by the
app open without a prompt. Replacing the bundle by renaming it, from the app's own process, raises no App Management prompt
for an ad-hoc app (reported on macOS 26.2).

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Core: versions, release feed, notes, changelog, verified install](./phase-01-core-updates.md) | Completed |
| 2 | [App: update controller, window, settings, menus, What's New](./phase-02-app-updates.md) | Completed |
| 3 | [Release pipeline: CHANGELOG.md, optional Developer ID + notarization, docs](./phase-03-release-pipeline.md) | Completed |

Review and fixes: [reports/code-review-in-app-updates.md](./reports/code-review-in-app-updates.md).

## Outcome
- Merged in [#1](https://github.com/ndanhkhoi/defaultly/pull/1); CI green on `macos-26` (Xcode 26.6, Swift 6.3.3): 90 tests, UI smoke test, 0 warnings.
- Released [v1.1.0](https://github.com/ndanhkhoi/defaultly/releases/tag/v1.1.0): notes taken from `CHANGELOG.md`, ad hoc signed (no Apple secrets yet, so the Developer ID step was skipped), universal, `CHANGELOG.md` bundled.
- `make integration-test` installed the published v1.1.0 through the updater into a temporary folder, without a quarantine flag.

## Acceptance criteria
1. A build older than the latest release finds it (manually and automatically), shows its notes, and after **Install and Relaunch**
   runs the new version from the same path, with no Gatekeeper prompt.
2. The download is rejected unless its SHA-256 matches `SHA256SUMS.txt`, the bundle ID and version match the release, and the
   code signature is valid (same Team ID when the running app has one). A failed install leaves the old app in place.
3. Skip This Version, Remind Me Later, automatic checks on/off and install-on-quit work and persist.
4. First launch after an update opens Release Notes; Help → Release Notes lists the bundled changelog.
5. `make test`, `make smoke-test`, `make lint` pass; the release workflow fails when `CHANGELOG.md` lacks the tag's version.
6. Without Apple secrets the release is unchanged (ad-hoc); with them it is Developer ID signed, notarized and stapled.
