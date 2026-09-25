<p align="center">
  <img src="docs/images/app-icon.png" width="128" height="128" alt="Defaultly icon">
</p>

<h1 align="center">Defaultly</h1>

<p align="center">
  Choose which app opens every file type on your Mac, in one place.<br>
  Native SwiftUI · Liquid Glass · English &amp; Tiếng Việt · macOS 14+
</p>

<p align="center">
  <b>English</b> · <a href="README.vi.md">Tiếng Việt</a>
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
- **Updates**: Defaultly checks GitHub for a new version once a day and shows what changed. **Install and Relaunch** verifies the download (checksum and code signature) and replaces the app in place. **Help → Release Notes** lists every version.
- **Private**: no data collection. The only network access is the daily update check against GitHub, which you can turn off in Settings.

## Install

1. Download `Defaultly-<version>.dmg` from the [latest release](https://github.com/ndanhkhoi/defaultly/releases/latest), open it, and drag **Defaultly** into **Applications**.
2. Open Defaultly for the first time, as described below.

Universal build for Apple silicon and Intel. Verify downloads with `SHA256SUMS.txt`.

### First launch: allow Defaultly in System Settings

Defaultly is signed ad-hoc, not with a paid Apple Developer ID, so Apple hasn't notarized it. Gatekeeper therefore blocks it the first time you open it. You only need to allow it once; after that it opens normally.

**macOS 15 Sequoia or later**

1. Open **Defaultly** from Applications. macOS says it can't verify the app. Click **Done**, not *Move to Trash*.
2. Open **System Settings → Privacy & Security** and scroll down to **Security**. Next to *“Defaultly.app” was blocked to protect your Mac*, click **Open Anyway**.

   <img src="docs/images/first-launch-privacy-security.png" width="640" alt="System Settings, Privacy &amp; Security: “Defaultly.app” was blocked to protect your Mac, with an Open Anyway button">

3. macOS asks again. Click **Open Anyway**, then enter your password or use Touch ID.

   <img src="docs/images/first-launch-open-anyway.png" width="300" alt="Dialog: Open “Defaultly.app”? with Move to Trash, Open Anyway and Done buttons">

**macOS 14 Sonoma:** Control-click **Defaultly** in Applications, choose **Open**, then click **Open** in the dialog.

**Terminal (any version):** removing the quarantine flag skips all of the above:

```bash
xattr -dr com.apple.quarantine /Applications/Defaultly.app
```

The warning is expected for apps distributed without a Developer ID; it isn't a sign of malware. Every release is built from this repository's source by [GitHub Actions](https://github.com/ndanhkhoi/defaultly/actions/workflows/release.yml), and you can check the download against `SHA256SUMS.txt`.

### Updates

You only allow Defaultly once. After that it updates itself, and macOS doesn't ask again: Gatekeeper only checks files marked as downloaded from the internet, as browsers mark them, and Defaultly's own downloads aren't marked that way. Defaultly 1.0.x has no updater yet, so install the next version from the release page once. It installs an update only when the download matches the release's `SHA256SUMS.txt` and the new app's code signature is valid.

- Defaultly checks once a day. When there's a new version, it shows the release notes with **Install and Relaunch**, **Remind Me Later** and **Skip This Version**.
- **Defaultly → Check for Updates…** checks right away.
- **Settings → Updates**: turn automatic checks off, or let Defaultly download updates in the background and install them when you quit.
- If Defaultly runs from the disk image or the Downloads folder, move it to **Applications** first; otherwise it offers the download instead.

Why there is no way around the first-launch step without a paid Apple Developer ID: [docs/code-signing-and-notarization.md](docs/code-signing-and-notarization.md).

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
| Update | **Defaultly → Check for Updates…**; see what changed in **Help → Release Notes** |

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

- `Sources/DefaultlyCore`: formats catalog, models, the updater and services behind small protocols (`LaunchServicesClient`, `AppLocating`, `ReleaseSource`), unit-tested with fakes.
- `Sources/Defaultly`: the SwiftUI app.
- `scripts/`: app bundling, packaging and icon rendering. `.github/workflows/`: CI, and releases on `v*` tags.

See [docs/system-architecture.md](docs/system-architecture.md), [docs/code-standards.md](docs/code-standards.md) and the [product spec](docs/project-overview-pdr.md).

## Contributing

Issues and pull requests are welcome. Describe user-visible changes under **Unreleased** in [CHANGELOG.md](CHANGELOG.md): releases take their notes from it. To add formats or categories, edit `Sources/DefaultlyCore/Catalog/FileTypeCatalog.swift` and add the Vietnamese names to `Resources/vi.lproj/Localizable.strings`; `make test` checks both.

## License

[MIT](LICENSE)
