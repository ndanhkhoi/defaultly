# Phase 3 — SwiftUI app, Liquid Glass UI & localization (`Sources/Defaultly`)

## Layout
`NavigationSplitView` three columns: **Sidebar → Content → Inspector**.

| Sidebar | Content | Inspector (detail) |
|---------|---------|--------------------|
| Quick Setup | Setup list (app suites + 17 categories) | Pick a suggested app → review pending changes → Apply |
| All Formats / category / Custom / search | Format table (multi-select) | One item: details, supporting apps, related formats. Many: bulk assign. None: category setup |
| Apps | Installed apps | Formats it opens + suggested formats (pending) → Apply |

## Files
- `DefaultlyApp.swift` (composition root, Window, Settings, Commands), `AppModel.swift`, `Navigation.swift`, `DefaultlyCommands.swift`.
- `Views/RootView.swift`, `Views/SidebarView.swift`, `Views/SettingsView.swift`.
- `Views/Formats/`: `FormatTableView`, `FormatInspector`, `FormatDetailView`, `AssignmentPanel` (multi-selection and category setup).
- `Views/Setup/`: `SetupListView`, `SetupDetailView`.
- `Views/Apps/`: `AppListView`, `AppDetailView`.
- `Views/Shared/`: `ChangeReviewList`, `ActivityOverlay`, `AppIconView`, `ExtensionBadge`, `AppChoiceMenu`, `AppLabel`.
- `Views/Sheets/`: `CustomFormatSheet`, `RestoreSheet`, `IssuesSheet`.
- `Support/`: `Glass.swift`, `IconCache.swift`, `AppPicker.swift`, `BackupFlow.swift`, `CustomFormatStore.swift`, `Localization.swift`, `LanguagePreference.swift`, `CategoryTint+Color.swift`.
- `Resources/en.lproj/Localizable.strings(dict)`, `Resources/vi.lproj/Localizable.strings`.

## States (mandatory)
loading, empty, normal, selected, pending, applying, success-undo, error-recovery (spec §5).

## Native patterns
- Toolbar: Refresh, Open With (selection), Add Format, Backup menu.
- Row context menu: Open With ▸, Reveal Default App in Finder, Copy Extension, Edit/Remove (custom).
- Commands: File (New Custom Format ⌘N, Export Backup ⇧⌘E, Restore Backup ⇧⌘O), View (Refresh ⌘R). Edit Undo/Redo via `UndoManager`.
- Sheets: add/edit custom formats, restore backup, issue details. Settings window: language.

## Liquid Glass
- Sidebar, toolbar and inspector are system components and adopt glass automatically with SDK 26.
- Custom glass only on the control layer: `ActivityOverlay` (floating capsule) and action buttons (`.glass` / `.glassProminent`). Bottom apply bars use `safeAreaBar` with the hard scroll-edge effect. Content (tables, lists, sections) stays non-glass.

## Validation
- Build, launch the bundled app, and check the three columns and key states via screenshots, in both languages.
