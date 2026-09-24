# Changelog

Notable changes to Defaultly. Each release's notes on GitHub, and in the app under **Help → Release Notes**,
come from this file.

## 1.1.3 - 2026-09-24

- **Fixed:** closing the Software Update window after choosing **Install and Relaunch** made Defaultly quit and
  reopen by itself as soon as the download finished. It now shows the window again, so you choose **Relaunch Now** or
  **Install on Quit**.
- **Fixed:** when an update couldn't be installed as Defaultly quit, nothing said so. The next launch now shows why.

## 1.1.2 - 2026-09-24

- **Fixed:** Defaultly quit on macOS 27 when it found an update, whether you chose **Check for Updates…** or it
  checked by itself. It now shows the update, as it does on earlier versions of macOS.
- **Fixed:** in **Help → Release Notes**, the button next to **Check for Updates…** that opens every release on GitHub
  now looks like a toolbar button.
- **Fixed:** on macOS 27, changing a default app could ask for confirmation two or three times for the same format,
  and choosing **Keep** didn't stop the questions for the rest of the change. macOS still asks once for each format
  (this can't be turned off); choosing **Keep** once now skips the remaining formats.
- On macOS 27, Defaultly 1.1.0 and 1.1.1 quit as soon as they find this update. Download this version from the
  release page once; later versions install themselves.

## 1.1.1 - 2026-09-24

- **Fixed:** clicking **More Apps**, **Technical Details** or the skipped formats of a backup now opens them. Before,
  only the small arrow next to them responded.

## 1.1.0 - 2026-09-24

- **New:** Defaultly checks for updates once a day and shows what's new before you install. **Install and Relaunch**
  downloads the update, verifies it and replaces the app in place, so macOS doesn't ask you to allow it again.
- **New:** **Defaultly → Check for Updates…**, and an **Updates** section in Settings: turn automatic checks off, or
  let Defaultly download updates in the background and install them when you quit.
- **New:** **Help → Release Notes** lists the changes in every version, and opens by itself after an update.
- Coming from 1.0.x? Install this version from the download once; later versions install themselves.

## 1.0.1 - 2026-09-24

- **Fixed:** Defaultly quit when switching between some categories in the sidebar (for example Documents → Spreadsheets).
- **Fixed:** pressing ⌘Z while changes were still being applied undid the previous change instead of the current one.
- **Fixed:** refreshing while applying could briefly show outdated default apps.
- macOS asks for confirmation at most once per format, and stops asking for the rest of a batch as soon as you choose
  *Don't Allow*.
- Pressing Return no longer applies pending changes while you browse Quick Setup; use the **Apply** button.
- Every release now passes a UI smoke test that opens every screen before it's published.

## 1.0.0 - 2026-09-24

- First release: see and change the default app of 400+ formats in 17 categories, add your own formats, switch a
  whole category or app suite with Quick Setup, and find formats an app can open.
- Every bulk change is previewed first, read back after applying, and can be undone. Back up and restore your
  associations as JSON.
- Native SwiftUI with Liquid Glass on macOS 26, in English and Vietnamese.
