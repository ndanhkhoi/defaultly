# System Architecture

## Technology decisions (agreed with the project owner, 2026-09-24)

| Topic | Choice | Why |
|-------|--------|-----|
| Language / UI | Swift 6 + SwiftUI | 100% native, real Liquid Glass, direct `NSWorkspace` access |
| Build | SwiftPM (no `.xcodeproj`) | Most CI-friendly: nothing to install on the runner, same commands as local, fastest builds. Local development only needs Command Line Tools |
| Minimum macOS | 14 Sonoma with fallback | Liquid Glass on 26+, materials on 14–15 |
| Signing | Ad-hoc (`codesign -s -`) | Free. Users confirm "Open Anyway" on first launch |
| Localization | `en.lproj` + `vi.lproj` `Localizable.strings` in the app bundle | Works with SwiftPM + Command Line Tools (no Xcode string catalog compiler needed) |
| Rejected | Xcode project, pure AppKit, Tauri, Electron, Flutter | Heavier CI, no real Liquid Glass, or much more code |

## Overview

```
┌──────────────────────────── Defaultly (executable, SwiftUI) ───────────────────────────┐
│  DefaultlyApp ── composition root: Window + Settings + Commands                        │
│  AppModel (@Observable, @MainActor) ── statuses, apps, activity, custom formats        │
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
│  Ports:    LaunchServicesClient  ◄── SystemLaunchServices (NSWorkspace + UTType)       │
│            AppLocating           ◄── SystemAppLocator (Bundle + FileManager)           │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

## Principles

- **SRP**: each type does one job. `SystemLaunchServices` only talks to LaunchServices, `PlanBuilder` only builds pending changes, and `AppModel` only coordinates UI state.
- **OCP**: new formats or categories are data edits in `FileTypeCatalog`, and new suites are one more `AppSuite` value. User-defined formats are merged at runtime by `FormatLibrary`. None of these touch logic.
- **LSP / ISP**: two small ports, `LaunchServicesClient` and `AppLocating`, each with three methods. Tests swap in fakes.
- **DIP**: `AssociationService` and `AppModel` depend on the ports. Concrete system implementations are injected in `DefaultlyApp`.
- **DRY**: every change flows through `AppModel.apply(_:named:undoManager:)`, including Open With, Quick Setup, app suggestions, restore and Undo/Redo. Every confirmation screen reuses `ChangeReviewList`.

## Main data flow

0. **Library**: `FormatLibrary(categories:custom:)` merges the static catalog with `CustomFormat`s, which `CustomFormatStore` persists in UserDefaults.
1. **Load**: `AppModel.reload()` → `Task.detached` → `AssociationService.statuses(for:)`. For each extension it collects the matching `UTType`s, then calls `urlForApplication` + `urlsForApplications` to build a `FormatStatus(current, candidates)`.
2. **Stage (pending)**: `PlanBuilder.items(...)` builds `[PlanItem]` holding current, target, `isSupported` and `isIncluded`. No-ops are dropped.
3. **Apply** (`AssociationService.apply(_:)`, one batch):
   1. Record the previous app of every format (for Undo).
   2. **Instant write** for every assignment and every UTI of its extension (`LSSetDefaultRoleHandlerForContentType`, looked up at runtime because it is deprecated). It takes milliseconds, where `NSWorkspace.setDefaultApplication` takes about 2 s per call and serializes.
   3. **Verify**: poll the associations until each one reads back, or a 3 s timeout expires. LaunchServices usually needs 0.5–1.5 s to report a change.
   4. **Interactive retry**: for what macOS ignored (typically types another app owns, such as `.doc` for Word), call `NSWorkspace.setDefaultApplication`. macOS may show a confirmation prompt; then verify again.
   5. Return an `AssignmentOutcome` per format: `applied`, `notAccepted(actual)` or `failed(message)`.
4. **Report**: `ApplyReport` summarizes the outcomes and builds the `inverse` assignments (restore previous apps), which are registered with `UndoManager`. Redo is registered synchronously inside the undo handler, so the stack order stays correct.
5. **Local refresh**: only the statuses of the changed extensions are read again.

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
- `scripts/build-app.sh`: build per arch (copying each binary aside, since newer SwiftPM reuses one output folder) → `lipo` → assemble `Defaultly.app` (Info.plist template, `AppIcon.icns`, `*.lproj`) → `codesign --sign -` (ad-hoc).
- `scripts/sdk-root.sh`: with Command Line Tools only, selects the macOS 26 SDK, because newer SDKs make `@State` a macro whose plugin ships with Xcode. `make test` then passes the Swift Testing plugin path explicitly.
- `scripts/package-release.sh`: `.zip` (ditto) + `.dmg` (hdiutil, with an Applications symlink) + `SHA256SUMS.txt`.
- CI `ci.yml` (push/PR): lint strings, build, test, universal app bundle, upload artifact.
- CD `release.yml` (tag `v*`): test → universal build → package → `gh release create`.
