# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Commands

```bash
make build             # swift build (debug)
make test              # unit tests (Swift Testing)
make integration-test  # touches real LaunchServices with a made-up extension only
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
plugin path explicitly. On CI (Xcode 26 on `macos-26`) no override is used.

## Architecture

Read `docs/system-architecture.md` first; `docs/project-overview-pdr.md` is the spec.

- `Sources/DefaultlyCore` — no SwiftUI. Models, the format catalog (`FileTypeCatalog`), and services behind two ports:
  `LaunchServicesClient` (read/write default apps) and `AppLocating` (installed apps). Unit-tested with fakes.
- `Sources/Defaultly` — SwiftUI app. `DefaultlyApp` is the composition root; `AppModel` holds domain state and is the
  single path for changing associations (`apply(_:named:undoManager:)`), which also registers Undo/Redo;
  `Navigation` holds UI routing state.
- Applying is two-phase (`AssociationService.apply`): an instant LaunchServices write for everything, a read-back,
  then the `NSWorkspace` API only for what macOS ignored (it can show a system confirmation). Do not switch bulk
  writes to `NSWorkspace` alone: it takes about 2 s per content type.

## Conventions

- SOLID, YAGNI → KISS → DRY; see `docs/code-standards.md`.
- Liquid Glass APIs only through `Support/Glass.swift` (each has a macOS 14–15 fallback); glass only on controls.
- English strings are the localization keys. Add every new user-facing string to
  `Resources/vi.lproj/Localizable.strings`; counted English strings go in `Resources/en.lproj/Localizable.stringsdict`.
  A test fails if a catalog name lacks a Vietnamese translation.
- Never run tests that change real file associations except `make integration-test`.
- Conventional Commits; releases are cut by pushing a `vX.Y.Z` tag.
