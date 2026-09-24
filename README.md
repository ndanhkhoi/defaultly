<p align="center">
  <img src="docs/images/app-icon.png" width="128" height="128" alt="Defaultly icon">
</p>

<h1 align="center">Defaultly</h1>

<p align="center">
  Choose which app opens every file type on your Mac, in one place.<br>
  Native SwiftUI · Liquid Glass · English &amp; Tiếng Việt · macOS 14+
</p>

<p align="center">
  <a href="https://github.com/ndanhkhoi/defaultly/releases/latest"><img src="https://img.shields.io/github/v/release/ndanhkhoi/defaultly?label=download" alt="Latest release"></a>
  <a href="https://github.com/ndanhkhoi/defaultly/actions/workflows/ci.yml"><img src="https://github.com/ndanhkhoi/defaultly/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

<p align="center">
  <img src="docs/images/screenshot.png" alt="Defaultly showing the Documents category, its formats and the apps that open them">
</p>

## Why

On macOS, Finder changes default apps one extension at a time (Get Info → Open With → Change All…), with no overview of what opens what. Moving a whole family of formats (every Office document, all source code, all video) to another app means repeating that dozens of times. Command-line tools need Homebrew, UTIs and bundle IDs.

Defaultly shows every format, the app that opens it, and the apps that could. You can switch one format, a selection, or a whole category in one step, review the changes first, and undo them.

## Features

- **400+ formats in 17 categories**: documents, spreadsheets, presentations, PDF & e-books, text & Markdown, web, source code, data & config, images, design, audio, video & subtitles, archives & disk images, fonts, 3D & CAD, email & internet, databases.
- **Your own formats**: add any extension (several at once: `kt, kts, gradle`), name it and file it under a category. Search offers to add an extension it doesn't know.
- **Quick Setup**: switch a whole category to one app. Installed apps are ranked by how many of its formats they support. App suites (Microsoft Office, Apple iWork, LibreOffice) switch documents, spreadsheets and presentations in one go.
- **Suggestions**: pick an app to see the formats it can open but doesn't yet, including extensions from its own `Info.plist`. Pick a format to see related formats that could use the same app.
- **Safe changes**: every bulk change is previewed first. Formats an app doesn't declare start unchecked. Every change is read back, and anything macOS refused is reported with a way to fix it.
- **Undo and Redo** from the Edit menu (⌘Z / ⇧⌘Z) or the confirmation toast. **Backup and Restore** your associations as JSON.
- **Complete, not partial**: sets every content type behind an extension (`.docx` alone has four), not just one.
- **Native Mac app**: Liquid Glass on macOS 26, sidebar → table → inspector layout, full keyboard and VoiceOver support. English and Vietnamese, switchable in Settings.
- **Private**: no network access, no data collection.

## Install

1. Download `Defaultly-<version>.dmg` from the [latest release](https://github.com/ndanhkhoi/defaultly/releases/latest), open it, and drag **Defaultly** into **Applications**.
2. The app is ad-hoc signed but not notarized, so macOS blocks the first launch:
   - **macOS 15 or later:** open Defaultly once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
   - **macOS 14:** Control-click Defaultly in Applications and choose **Open**.
   - Or run `xattr -dr com.apple.quarantine /Applications/Defaultly.app`.

Universal build for Apple silicon and Intel. Verify downloads with `SHA256SUMS.txt`.

## Use

| To… | Do this |
|-----|---------|
| Change one format | Select it in a category, then pick an app in the inspector, or right-click → **Open With** |
| Change many formats | Select several rows (⌘-click, ⇧-click, ⌘A) → **Open With** in the toolbar, or review suggestions in the inspector |
| Switch a whole category or suite | **Quick Setup** → pick a category or suite → pick an app → **Apply** |
| Find apps' hidden talents | **Apps** → select an app → check suggested formats → **Apply** |
| Add your own extension | ⌘N, or search for it and choose **Add … as Custom Format** |
| Undo | ⌘Z, or **Undo** in the confirmation toast |
| Back up / restore | **File → Export Backup…** (⇧⌘E) / **Restore from Backup…** (⇧⌘O) |
| Switch language | **Defaultly → Settings… → Language** |

If macOS keeps an app for a format (usually one another app "owns"), Defaultly asks macOS through its confirmation API. Allow the system prompt to finish the change.

## Build from source

Requires macOS 14+ and either Xcode 26 or Command Line Tools with the macOS 26 SDK.

```bash
git clone https://github.com/ndanhkhoi/defaultly.git
cd defaultly
make test      # unit tests
make run       # build dist/Defaultly.app and open it
make package   # universal .dmg and .zip in dist/
```

The project is a Swift package with no Xcode project and no dependencies:

- `Sources/DefaultlyCore`: formats catalog, models and services behind small protocols (`LaunchServicesClient`, `AppLocating`), unit-tested with fakes.
- `Sources/Defaultly`: the SwiftUI app.
- `scripts/`: app bundling, packaging and icon rendering. `.github/workflows/`: CI, and releases on `v*` tags.

See [docs/system-architecture.md](docs/system-architecture.md), [docs/code-standards.md](docs/code-standards.md) and the [product spec](docs/project-overview-pdr.md).

## Contributing

Issues and pull requests are welcome. To add formats or categories, edit `Sources/DefaultlyCore/Catalog/FileTypeCatalog.swift` and add the Vietnamese names to `Resources/vi.lproj/Localizable.strings`; `make test` checks both.

## License

[MIT](LICENSE)
