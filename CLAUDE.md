# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Commands

```bash
make build             # swift build (debug)
make test              # unit tests (Swift Testing)
make integration-test  # real LaunchServices with a made-up extension, and installs the latest GitHub release into a temp folder
make smoke-test        # launches a debug build that clicks through every screen; fails on crash (also on CI)
make lint              # plutil -lint Info.plist and .strings/.stringsdict
make app               # dist/Defaultly.app for this Mac's architecture
make universal         # dist/Defaultly.app for arm64 + x86_64
make package           # universal app + dist/Defaultly-<version>.{dmg,zip} + SHA256SUMS.txt
make run               # build and open the app
make icon              # regenerate Resources/AppIcon.icns from scripts/generate-icon.swift
```

Always go through `make` (or the scripts) rather than bare `swift build`: with Command Line Tools only,
the default macOS 27 SDK makes `@State` a macro whose plugin ships only with Xcode, so
`scripts/sdk-root.sh` switches to the macOS 26 SDK, and `make test` then passes the Swift Testing
plugin path explicitly. `scripts/swift-flags.sh` adds a linker flag so the binary records that SDK's version:
without it, SwiftPM stamps 14.0 and SwiftUI keeps its macOS 14 behavior locally (no Liquid Glass), unlike the
release. Check with `vtool -show-build <binary> | grep sdk`. On CI (Xcode 26 on `macos-26`) no override is used.

## Architecture

Read `docs/system-architecture.md` first; `docs/project-overview-pdr.md` is the spec.

- `Sources/DefaultlyCore` — no SwiftUI. Models, the format catalog (`FileTypeCatalog`), and services behind three ports:
  `LaunchServicesClient` (read/write default apps), `AppLocating` (installed apps) and `ReleaseSource` (GitHub releases).
  Unit-tested with fakes.
- `Sources/Defaultly` — SwiftUI app. `DefaultlyApp` is the composition root; `AppModel` holds domain state and is the
  single path for changing associations (`apply(_:named:undoManager:)`), which also registers Undo/Redo;
  `Navigation` holds UI routing state.
- Updates: `UpdateController` (app) drives `UpdateInstaller` + `GitHubReleaseClient` (Core). An update is installed only
  after its checksum, bundle ID, version and code signature check out; the bundle is swapped by moving, never copied.
  Its state machine is unit-tested with fakes in `Tests/DefaultlyTests`. See the Updates section of
  `docs/system-architecture.md` and `docs/code-signing-and-notarization.md`.
- Applying is two-phase (`AssociationService.apply`): an instant LaunchServices write for everything, a read-back,
  then the `NSWorkspace` API only for what macOS ignored (it can show a system confirmation). Do not switch bulk
  writes to `NSWorkspace` alone: it takes about 2 s per content type. Exception, macOS 27+: the instant write queues
  a system confirmation per content type and returns before the answer (`instantWritesAreSilent` is false), so only
  `NSWorkspace` is used there, which asks once per format and reports "Keep" as a decline.

## Conventions

- SOLID, YAGNI → KISS → DRY; see `docs/code-standards.md`.
- Liquid Glass APIs only through `Support/Glass.swift` (each has a macOS 14–15 fallback); glass only on controls.
- Row/cell/menu views get plain values, never `@Environment(AppModel.self)`: macOS updates cells of removed
  rows outside the hierarchy and SwiftUI traps ("No Observable object of type AppModel found"). This crashed v1.0.0
  when switching categories; `make smoke-test` guards it.
- English strings are the localization keys. Add every new user-facing string to
  `Resources/vi.lproj/Localizable.strings`; counted English strings go in `Resources/en.lproj/Localizable.stringsdict`.
  A test fails if a catalog name lacks a Vietnamese translation.
- Never run tests that change real file associations except `make integration-test`.
- Conventional Commits. Add user-visible changes under `## Unreleased` in `CHANGELOG.md`; to release, rename it to
  `## X.Y.Z - YYYY-MM-DD`, commit, and push a `vX.Y.Z` tag (the workflow fails without that section).
- Debug and smoke-test runs (`swift run`, `make smoke-test`) have no bundle version, so they never check for updates.
