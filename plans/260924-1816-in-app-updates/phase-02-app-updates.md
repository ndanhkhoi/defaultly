# Phase 2 — App: update controller, window, settings, menus, What's New

## Files
- `Sources/Defaultly/UpdateController.swift`: `@Observable` state machine (idle, checking, upToDate, available, installing(progress), ready, installed, failed), one `work` task for every check and download, daily schedule, install on quit; `UpdatePresenting` and `Relauncher` injected.
- `Sources/Defaultly/Support/UpdatePreferences.swift`: UserDefaults-backed settings (auto check, auto install, last check, skipped version, last launched version).
- `Sources/Defaultly/Support/UpdateWindow.swift`: non-restorable `NSWindow` hosting `UpdateView`; `ProjectLinks.swift`.
- `Sources/Defaultly/Views/Updates/UpdateView.swift`, `ReleaseNotesList.swift`, `ReleaseNotesScreen.swift`.
- `Tests/DefaultlyTests/UpdateControllerTests.swift`: the state machine with a fake feed, installer, window and relaunch.
- `Support/Relaunch.swift`: shared relaunch (language change and updates).
- Edits: `DefaultlyApp` (composition, windows), `DefaultlyCommands` (Check for Updates…, Release Notes), `SettingsView` (Updates section), `SmokeTest`, `vi.lproj` strings.

## Validation
- `make smoke-test` renders every update state and the release notes window.
- Manual end-to-end: build as 1.0.0 in a temporary folder, check, install 1.0.1, confirm it relaunches from the same path without quarantine.
