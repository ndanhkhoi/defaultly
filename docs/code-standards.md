# Code Standards

## Principles
**YAGNI → KISS → DRY**, in that order, with **SOLID** design.

- Build nothing "for later". Every type and function has a real caller.
- A function that needs a comment to be understood should be split or renamed instead.
- Business logic lives in `DefaultlyCore` and never imports SwiftUI. UI lives in `Defaultly`.
- Depend on the ports (`LaunchServicesClient`, `AppLocating`). System implementations are only created in the composition root (`DefaultlyApp`).

## Swift
- Swift 6 language mode, `swift-tools-version: 6.0`. CI builds with the default Xcode 26 on the `macos-26` runner (Swift 6.3 at the time of writing); locally, Command Line Tools with the macOS 26 SDK. Both must stay warning-free.
- Models are `Sendable` value types. Only `AppModel` and `IconCache` are classes (`@MainActor`).
- Swift API Design Guidelines naming. File name = main type name (PascalCase).
- Liquid Glass APIs (`glassEffect`, `.glass`, `.glassProminent`) are only used through the adapters in `Support/Glass.swift`, each with an `#available` fallback.
- No force unwraps outside static catalog data (which the tests validate).
- Network access only goes through the `ReleaseSource` port (update checks and downloads). Nothing else talks to the network.

## UI
- Glass only for the control layer (toolbar, floating status bar, action buttons), never for content.
- Every screen handles loading / empty / normal / selected / pending / applying / success-undo / error-recovery.
- Icon-only buttons have `.help` and an accessibility label. Color is never the only signal.
- Expandable rows use `RowDisclosureGroup`, not `DisclosureGroup`: in a macOS form the system one only responds to its small chevron, so clicking its title does nothing.
- Views inside `Table` cells, `List`/`Form` rows and menus take plain values (or the model as an explicit parameter) and never read `@Environment(AppModel.self)` / `@Environment(Navigation.self)`. AppKit hosts them separately and keeps updating cells of removed rows after they leave the hierarchy, where the environment object is missing and SwiftUI traps. Screen-level views may read the environment.

## Localization
- English text is the key. Every user-facing string must also be added to `Resources/vi.lproj/Localizable.strings`.
- Counted strings use `Resources/en.lproj/Localizable.stringsdict` for English plurals.
- `make lint` validates the `.strings` / `.stringsdict` files (`plutil -lint`).

## Tests
- Swift Testing (`import Testing`). Core is tested with fake ports; `Tests/DefaultlyTests` tests the app's `UpdateController` with a fake feed, installer, window and relaunch. No test touches the real LaunchServices database, except the opt-in integration test (`DEFAULTLY_INTEGRATION=1`), which only uses a made-up extension.
- Run `make test` before every commit, and `make smoke-test` after UI changes: a debug-only `SmokeTest` drives every screen, selection, sheet and toast in the real app and fails on any crash. CI runs both.

## Git
- Conventional Commits (`feat:`, `fix:`, `ci:`, `docs:`, `test:`, `chore:`).
- Every user-visible change gets a bullet under `## Unreleased` in `CHANGELOG.md` (**New:**, **Fixed:** or plain).
- To release: rename `## Unreleased` to `## X.Y.Z - YYYY-MM-DD`, commit, then push a `vX.Y.Z` tag. The release workflow publishes that section as the release notes and fails without it; the app bundles the file for Help → Release Notes.
