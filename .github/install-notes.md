## Install

1. Download **Defaultly-*.dmg**, open it, and drag **Defaultly** into **Applications**.
2. First launch only: Defaultly is ad-hoc signed (no Apple Developer ID), so macOS blocks it once.
   - **macOS 15 or later:** open Defaultly and click **Done**. Then go to **System Settings → Privacy & Security**, click **Open Anyway** next to Defaultly, click **Open Anyway** again, and authenticate.
   - **macOS 14:** Control-click Defaultly in Applications and choose **Open**.
   - Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Defaultly.app`

   Step-by-step with screenshots: [First launch](https://github.com/ndanhkhoi/defaultly#first-launch-allow-defaultly-in-system-settings).

Already using a Defaultly with **Defaultly → Check for Updates…**? Use it to install this version in place; updates that Defaultly installs itself open without the first-launch step.

Requires macOS 14 Sonoma or later. Universal build for Apple silicon and Intel. Checksums are in `SHA256SUMS.txt`.
