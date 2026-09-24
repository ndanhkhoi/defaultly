# Defaultly — Product Spec (PDR)

## 1. Problem

Changing which app opens a file type on macOS is tedious:

- Finder changes **one extension at a time** (Get Info → Open With → Change All…). There is no overview of which app opens what.
- Moving a whole family of formats (office documents, source code, video…) to another app means repeating that dozens of times.
- Command-line tools such as `duti` need Homebrew and knowledge of UTIs and bundle IDs. They also usually set a single UTI per extension, but `.docx` alone maps to four UTIs.
- Nothing tells you which apps actually support a format. There is no preview, no undo and no backup.

**Defaultly** is a native macOS app (SwiftUI) that fixes this. You install it and it works, with no helper tools. It lets anyone choose the default app for **any file type** (documents, images, video, source code, archives… plus formats the user adds) through a modern Liquid Glass interface, in English or Vietnamese.

## 2. Goals

| # | Goal | Measured by |
|---|------|-------------|
| G1 | No external dependencies | Only `NSWorkspace` + `UniformTypeIdentifiers` |
| G2 | Cover every file type | Catalog ≥ 350 formats in 17 categories, plus unlimited custom formats |
| G3 | Change a whole group in one action | Quick Setup per category for any installed app, plus multi-app suites |
| G4 | Suggest formats and apps | Search suggestions, apps ranked by coverage, format suggestions per app |
| G5 | Safe by default | Preview before applying, verify after applying, Undo/Redo, Backup/Restore |
| G6 | Install and run | Universal (arm64 + x86_64) `.dmg`/`.zip` built by CI on every release tag |
| G7 | Bilingual | Full English and Vietnamese UI, including category and format names |

## 3. Scope v1.0

### F1. Format catalog by category
17 categories: Documents, Spreadsheets, Presentations, PDF & E-books, Text & Markdown, Web, Source Code, Data & Config, Images, Design, Audio, Video & Subtitles, Archives & Disk Images, Fonts, 3D & CAD, Email & Internet, Databases. Each format has an extension, a friendly name and a category. Technical details (UTIs, system description) appear only in the inspector (progressive disclosure).

### F2. View and change the default app per format
- A table shows each format, its current default app (icon + name) and its status.
- Select several rows, then use **Open With** to assign one app to all of them.
- The **Open With** menu lists apps that declare support (ranked by coverage), followed by **Other App…** to pick any app.
- Every UTI matching an extension is updated: the preferred UTI plus the alternates.

### F3. Quick Setup
- **By category** (all 17, including custom formats in them): suggests installed apps ranked by how many formats of that category they support. The data comes live from LaunchServices, so no app is hard-coded.
- **App suites**: multi-app bundles split by category, e.g. Microsoft Office (Word/Excel/PowerPoint), Apple iWork (Pages/Numbers/Keynote) and LibreOffice. Only installed suites are shown. Adding a suite is a data-only change.
- Picking an option stages the changes (pending). Formats the app does not declare support for start unchecked. Nothing changes until **Apply**.

### F4. App-centric view
A list of installed apps. Selecting an app shows:
- the formats it currently opens by default;
- **suggested formats**: formats it supports but is not the default for, drawn from the catalog, custom formats and the extensions it declares in its `Info.plist`.

The user checks formats, then applies.

### F5. Search and custom formats
- Search by extension or name (English or Vietnamese) with autocomplete suggestions.
- **Custom formats**: users can add any extension.
  - Add several at once, e.g. `kt, kts, gradle` or `*.foo .bar`. Input is normalized: `*.`/`.` is stripped, text is lowercased and the characters are validated.
  - Optional display name (the system description is used when empty) and a category (default: Custom).
  - Edit and remove. Custom formats are persisted in UserDefaults.
  - They show up in their category, in the Custom sidebar item, in search, in Quick Setup and in backups.
  - Error prevention: an extension already in the catalog is reported with its category, with a link to it, instead of being duplicated.
- If a search finds nothing and the query is a valid extension, an **Add .xyz** action is offered.

### F6. Verification, Undo/Redo, Backup/Restore
- After every change the association is read back. Changes macOS ignores are retried through the system API, which may ask the user to confirm. If macOS still keeps another app, the app says "macOS kept X" and offers recovery actions (Retry, Choose Another App).
- Native Undo/Redo through `UndoManager` (⌘Z / ⇧⌘Z, Edit menu). The success toast has an **Undo** button.
- Export the current associations (including custom formats) to JSON. Restore from JSON with a preview sheet before applying; missing custom formats are re-created.

### F7. Localization
- English (development language) and Vietnamese (`en.lproj`, `vi.lproj`).
- Follows the system language by default. **Settings → Language** offers System / English / Tiếng Việt (stored as the app's `AppleLanguages`, applied after relaunch with a **Relaunch** button).

### Out of scope (YAGNI)
URL schemes (browser/mail handlers), menu bar extra, CLI, auto-update (Sparkle), App Store/sandbox, telemetry, languages other than English and Vietnamese.

## 4. Non-functional requirements

- **Platform**: macOS 14 Sonoma or later. Liquid Glass on macOS 26+, with a material fallback on 14–15.
- **Performance**: reading about 400 formats takes < 300 ms and never blocks the UI; applying a batch of any size takes about 1–2 s (plus one confirmation per format macOS protects).
- **Distribution**: GitHub Releases, ad-hoc signed (no Apple Developer ID). The README explains the Gatekeeper first-launch step.
- **Privacy**: no network access, no data collection. The app only reads and writes the current user's LaunchServices handlers.

## 5. UI/UX standards

- Apple HIG + Liquid Glass: system-first, functional glass only (toolbar, system sidebar, floating status bar, action buttons), no glass-on-glass, content clarity over effects.
- `NavigationSplitView` three-column layout: **Sidebar → Content (format table / lists) → Inspector**, following the master–detail + inspector pattern.
- Native patterns: Toolbar, Sheet, Context Menu, Commands (menu bar), Settings window, Undo/Redo.
- Nielsen's 10 heuristics. Jakob's Law (behave like Finder / System Settings), Hick's Law (at most ~4 primary suggestions, the rest under "More"), Fitts's Law (large primary buttons pinned to the bottom of the inspector).
- Progressive disclosure (UTIs under "Technical Details"). Recognition over recall (app icons, format names, suggestions).
- WCAG 2.2 POUR: labels on icon-only buttons, color is never the only signal, full keyboard navigation, VoiceOver announcements when an action completes.

### Mandatory UI states

| State | Presentation |
|-------|--------------|
| loading | Progress indicator "Reading file associations…" on first scan / refresh |
| empty | `ContentUnavailableView` (no search results, no custom formats, nothing selected) |
| normal | Table / list with data |
| selected | Inspector shows one or many selected items |
| pending | Staged changes awaiting confirmation (Quick Setup, app suggestions, restore sheet) |
| applying | Floating status bar "Applying 18 changes…" with a progress indicator; affected rows show a spinner; apply buttons disabled |
| success with undo | Toast "Set LibreOffice for 18 formats" with an **Undo** button |
| error with recovery | Error toast with **Retry** / **Details**; the details sheet explains each cause and suggests a fix |

## 6. Acceptance criteria

1. `swift build` and `swift test` pass locally (Command Line Tools) and on CI (`macos-26`).
2. `make app` produces `dist/Defaultly.app`, which launches with a double-click.
3. Quick Setup (per category and per suite) changes a whole group with one Apply and reports any format macOS rejected.
4. Custom formats (one or many) can be added, assigned an app, and survive a relaunch.
5. Undo restores the previous default apps; Redo re-applies them.
6. Export → Restore brings back the same associations.
7. The UI is fully available in English and Vietnamese; switching language in Settings takes effect after relaunch.
8. Pushing a `v*` tag creates a GitHub Release with `Defaultly-<ver>.dmg`, `.zip` and `SHA256SUMS.txt`.
