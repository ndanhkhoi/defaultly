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

## UI
- Glass only for the control layer (toolbar, floating status bar, action buttons), never for content.
- Every screen handles loading / empty / normal / selected / pending / applying / success-undo / error-recovery.
- Icon-only buttons have `.help` and an accessibility label. Color is never the only signal.

## Localization
- English text is the key. Every user-facing string must also be added to `Resources/vi.lproj/Localizable.strings`.
- Counted strings use `Resources/en.lproj/Localizable.stringsdict` for English plurals.
- `make lint` validates the `.strings` / `.stringsdict` files (`plutil -lint`).

## Tests
- Swift Testing (`import Testing`). Core is tested with fake ports. No test touches the real LaunchServices database, except the opt-in integration test (`DEFAULTLY_INTEGRATION=1`), which only uses a made-up extension.
- Run `swift test` before every commit.

## Git
- Conventional Commits (`feat:`, `fix:`, `ci:`, `docs:`, `test:`, `chore:`).
- Releases are cut by pushing a `vX.Y.Z` tag.
