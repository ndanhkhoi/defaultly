# System Architecture

## Technology decisions (agreed with the project owner, 2026-09-24)

| Topic | Choice | Why |
|-------|--------|-----|
| Language / UI | Swift 6 + SwiftUI | 100% native, real Liquid Glass, direct `NSWorkspace` access |
| Build | SwiftPM (no `.xcodeproj`) | Most CI-friendly: nothing to install on the runner, same commands as local, fastest builds. Local development only needs Command Line Tools |
| Minimum macOS | 14 Sonoma with fallback | Liquid Glass on 26+, materials on 14–15 |
| Signing | Ad-hoc (`codesign -s -`) | Free. Users confirm "Open Anyway" on first launch |
| Localization | `en.lproj` + `vi.lproj` `Localizable.strings` in the app bundle | Works with SwiftPM + Command Line Tools (no Xcode string catalog compiler needed) |
| Updates | Own updater on the GitHub Releases API | No dependency, SwiftUI UI, fits SwiftPM + Command Line Tools. Sparkle rejected: a binary framework to embed by hand, an appcast and an EdDSA key in CI, AppKit UI |
| Update policy | Check daily, ask before installing; automatic install on quit is opt-in | The user stays in control; the check can be turned off |
| Release notes | `CHANGELOG.md`, published by CI and bundled in the app | One source for GitHub, the update window's history and Help → Release Notes |
| Rejected | Xcode project, pure AppKit, Tauri, Electron, Flutter | Heavier CI, no real Liquid Glass, or much more code |

## Overview

```
┌──────────────────────────── Defaultly (executable, SwiftUI) ───────────────────────────┐
│  DefaultlyApp ── composition root: Window + Settings + Commands                        │
│  AppModel (@Observable, @MainActor) ── statuses, apps, activity, custom formats        │
│  UpdateController (@Observable) ── update phases, daily checks, Software Update window │
│  Views: Sidebar │ Content (FormatTable / SetupList / AppList) │ Inspector (…Detail)    │
│  Support: Glass adapters, IconCache, AppPicker, CustomFormatStore, Localization        │
└───────────────────────────────▲────────────────────────────────────────────────────────┘
                                │ depends on abstractions only
┌───────────────────────────────┴────── DefaultlyCore (library, no SwiftUI) ─────────────┐
│  Models:   FileExtension, FileFormat, FileCategory, CustomFormat, AppInfo,             │
│            FormatStatus, Assignment, AssignmentOutcome, ApplyReport, PlanItem          │
│  Catalog:  FileTypeCatalog (17 categories), AppSuite, FormatLibrary (catalog + custom) │
│  Services: AssociationService (read status, two-phase apply + verify)                  │
│            PlanBuilder (pending changes), AppRanking (ranking suggestions)             │
│            DeclaredFormats (Info.plist), AssociationBackup (JSON)                      │
│  Updates:  AppVersion, Release/AvailableUpdate, ReleaseNotes, Changelog,               │
│            UpdateInstaller (verify + swap), UpdateSchedule                             │
│  Ports:    LaunchServicesClient  ◄── SystemLaunchServices (NSWorkspace + UTType)       │
│            AppLocating           ◄── SystemAppLocator (Bundle + FileManager)           │
│            ReleaseSource         ◄── GitHubReleaseClient (URLSession)                  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

## Principles

- **SRP**: each type does one job. `SystemLaunchServices` only talks to LaunchServices, `PlanBuilder` only builds pending changes, and `AppModel` only coordinates UI state.
- **OCP**: new formats or categories are data edits in `FileTypeCatalog`, and new suites are one more `AppSuite` value. User-defined formats are merged at runtime by `FormatLibrary`. None of these touch logic.
- **LSP / ISP**: three small ports, `LaunchServicesClient`, `AppLocating` and `ReleaseSource`, each with three methods. Tests swap in fakes.
- **DIP**: `AssociationService`, `AppModel`, `UpdateInstaller` and `UpdateController` depend on the ports. `UpdateController` also takes an `UpdateInstalling`, an `UpdatePresenting` window and a relaunch function, so its state machine is unit-tested with fakes (`Tests/DefaultlyTests`). Concrete system implementations are injected in `DefaultlyApp`.
- **DRY**: every change flows through `AppModel.apply(_:named:undoManager:)`, including Open With, Quick Setup, app suggestions, restore and Undo/Redo. Every confirmation screen reuses `ChangeReviewList`.

## Main data flow

0. **Library**: `FormatLibrary(categories:custom:)` merges the static catalog with `CustomFormat`s, which `CustomFormatStore` persists in UserDefaults.
1. **Load**: `AppModel.reload()` → `Task.detached` → `AssociationService.statuses(for:)`. For each extension it collects the matching `UTType`s, then calls `urlForApplication` + `urlsForApplications` to build a `FormatStatus(current, candidates)`.
2. **Stage (pending)**: `PlanBuilder.items(...)` builds `[PlanItem]` holding current, target, `isSupported` and `isIncluded`. No-ops are dropped.
3. **Apply** (`AssociationService.apply(_:)`, one batch):
   1. Record the previous app of every format (for Undo).
   2. **Instant write** for every assignment and every UTI of its extension (`LSSetDefaultRoleHandlerForContentType`, looked up at runtime because it is deprecated). It takes milliseconds, where `NSWorkspace.setDefaultApplication` takes about 2 s per call and serializes.
   3. **Verify**: poll the associations until each one reads back, or a 3 s timeout expires. LaunchServices usually needs 0.5–1.5 s to report a change.
   4. **Interactive retry**: for what macOS ignored (typically types another app owns, such as `.doc` for Word), call `NSWorkspace.setDefaultApplication` for the preferred UTI only. macOS may show a confirmation prompt; if the user declines once, the rest of the batch isn't asked again. Only what was asked is verified then — waiting on the unasked formats would just burn the timeout — and a write that throws is reported as a failure, not as a kept app.
   5. Return an `AssignmentOutcome` per format: `applied`, `notAccepted(actual)` or `failed(message)`.

   On macOS 27 and later, steps 2–3 are skipped (`LaunchServicesClient.instantWritesAreSilent` is false). There, the instant write is no longer silent: it returns at once but queues a system confirmation ("Do you want all documents with the extension … to open with …?") for every content type, and applies it whenever the user answers. Combined with the retry, one change could ask two or three times. Instead, every format that isn't already set goes through `NSWorkspace.setDefaultApplication`. It asks once and waits for the answer: **Use** applies it, **Keep** throws a user-cancelled error, which stops the rest of the batch. macOS asks about each format, and an app can't turn that off.
4. **Report & Undo**: `ApplyReport` summarizes the outcomes and derives the undo/redo assignments. `ReversibleChange` (Core, unit-tested) is registered with `UndoManager` as soon as the apply is queued, holding the apply's task: ⌘Z during an apply undoes that apply once it finishes. Its handler registers the mirrored change first, so Undo and Redo keep alternating, and the entry is removed if the batch turns out to have nothing to revert.
5. **One queue**: loads, refreshes and applies run through a single serial queue in `AppModel`, so a Refresh can never overwrite newer results and every caller of the first load waits for the same load.
6. **Local refresh**: only the statuses of the changed extensions are read again.

## Updates

1. **Schedule**: `UpdateController.start()` (from the main window's `.task`) waits a few seconds, then every hour checks whether a day has passed since the last check (`UpdateSchedule`). Checks only run while nothing else is in progress.
2. **Check**: `GitHubReleaseClient.releases()` reads `GET /repos/ndanhkhoi/defaultly/releases`. `AvailableUpdate` picks the newest installable release above the running version, honoring a skipped version for automatic checks, and keeps every newer release for their notes.
3. **Ask**: the Software Update window (`UpdateWindow`, an AppKit window so a background check can open it and it is never restored) shows `UpdateView` for the current `UpdateController.Phase`: checking, up to date, available, installing (download progress, then verifying), ready (downloaded, installed on quit), failed.
4. **Prepare** (`UpdateInstaller.prepare`): download `SHA256SUMS.txt` and the zip into `~/Library/Caches/<bundle id>/Update`, compare the SHA-256, unpack with `ditto` into a new folder, then require exactly one app whose `Info.plist` (read from disk, since `Bundle` caches per path) has the running bundle ID and the release's version, and a valid signature (`SecStaticCodeCheckValidity`, all architectures, nested code, strict). `CodeSignature.running` decides the rest: an ad-hoc app accepts any valid signature (the checksum ties the download to the release); a Developer ID app requires Apple's Developer ID chain with its own team (a code requirement, so a team ID written into a self-signed signature fails); an unreadable signature accepts nothing.
5. **Install** (`UpdateInstaller.install`): verify the prepared app again, move it into an item-replacement folder on the app's volume (this may copy; the installed app is untouched), then exchange the two with `renamex_np(RENAME_SWAP)` in one atomic step and delete the old one. A failure at any step leaves the installed app as it was, and nothing of the old bundle, such as a quarantine flag, reaches the new one. Then `Relaunch` starts the new copy and quits; if it can't start, the window says the update is installed.
6. **Why no Gatekeeper prompt**: the app doesn't set `LSFileQuarantineEnabled`, so its `URLSession` downloads carry no `com.apple.quarantine` flag, and Gatekeeper only assesses quarantined apps. Replacing its own bundle raises no App Management prompt for an ad-hoc app.
7. **One task**: every check and download runs as `UpdateController.work`, set exactly while the phase is `checking` or `installing`. Cancel reaches it wherever it started; restarting the daily timer never interrupts it; a second click can't start another.
8. **Install on quit**: with automatic installs on, a background check prepares the update and waits in `ready`; `NSApplication.willTerminateNotification` installs it, unless the user has turned automatic installs (or checks) off since, which drops it. **Install and Relaunch** also ends in `ready` when the window was closed during the download: the window opens again to ask, rather than the app quitting unannounced, and changing the automatic settings doesn't drop this one. A failed install on quit can't be shown, so its reason is kept in `UpdatePreferences.installFailure` and the last check time is cleared: the next launch checks within seconds, even with automatic checks off or the version skipped, and shows the failure once instead of downloading again. Relaunching to switch languages installs it first. Locations the app can't replace (`InstallLocationProblem`: not a bundle, translocated, read-only) offer the release page instead.
9. **Release notes**: `ReleaseNotes.changes(inReleaseBody:)` keeps a GitHub release body's "What's changed" section; `ReleaseNotes.blocks` turns Markdown into headings, bullets and paragraphs that `ReleaseNotesList` renders with inline Markdown. **Help → Release Notes** (`ReleaseNotesScreen`) parses the bundled `CHANGELOG.md` with `Changelog.parse`. `UpdatePreferences.lastLaunchedVersion` detects the first launch after an update, which opens that window.

## Localization

- Static UI strings: SwiftUI `LocalizedStringKey` with English text as the key.
- Dynamic strings (category and format names from Core, messages built in `AppModel`): `String(localized:)` / `Bundle.main.localizedString`, via `Localization.swift`.
- Plurals: `en.lproj/Localizable.stringsdict`. Vietnamese has no plural forms.
- Language override: Settings writes `AppleLanguages` to the app's own UserDefaults domain and relaunches.
- A Core test checks that every category and format name in the catalog has a Vietnamese translation.

## Concurrency

- Swift 6 language mode (strict concurrency).
- Ports and services are stateless `Sendable` structs (nonisolated). `AppModel` is `@MainActor` and `await`s them, so verification polling never blocks the UI.
- App icons (`NSImage`) are loaded on the main actor only, through `IconCache` (NSCache).

## Build & release

- SwiftPM targets: `DefaultlyCore` (library), `Defaultly` (executable), `DefaultlyCoreTests` (Swift Testing).
- `scripts/build-app.sh`: build per arch (copying each binary aside, since newer SwiftPM reuses one output folder) → `lipo` → assemble `Defaultly.app` (Info.plist template, `AppIcon.icns`, `CHANGELOG.md`, `*.lproj`) → `codesign --sign -` (ad-hoc), or with `SIGN_IDENTITY` a Developer ID signature with the hardened runtime and a timestamp.
- `scripts/sdk-root.sh`: with Command Line Tools only, selects the macOS 26 SDK, because newer SDKs make `@State` a macro whose plugin ships with Xcode. `make test` then passes the Swift Testing plugin path explicitly.
- `scripts/swift-flags.sh`: with that SDK, adds `-isysroot` for the linking clang. SwiftPM links without `SDKROOT` in the environment, so clang would record the deployment target (14.0) as the SDK version, and SwiftUI would keep its macOS 14 behavior in local builds (no Liquid Glass, other layout), unlike the release built with Xcode.
- `scripts/package-release.sh`: `.zip` (ditto) + `.dmg` (hdiutil, with an Applications symlink) + `SHA256SUMS.txt`. With `NOTARIZE=1`: notarize and staple the app first (`scripts/notarize.sh`), then sign, notarize and staple the dmg.
- `scripts/release-notes.sh <version> [previous-tag]`: the version's `CHANGELOG.md` section + install notes (`.github/install-notes*.md`) + compare link; fails without a section.
- CI `ci.yml` (push/PR): lint strings, build, test, universal app bundle, upload artifact.
- CD `release.yml` (tag `v*`): release notes from `CHANGELOG.md` (fails fast) → lint, test, smoke test → import the Developer ID certificate if the secrets exist → universal build, package (notarized when signed) → `gh release create`. See `docs/code-signing-and-notarization.md`.
