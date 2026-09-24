## Install

1. Download **Defaultly-*.dmg**, open it, and drag **Defaultly** into **Applications**.
2. Open Defaultly. This build is ad-hoc signed, not notarized, so macOS blocks it the first time:
   - **macOS 15 or later:** open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Defaultly.
   - **macOS 14:** Control-click Defaultly in Applications and choose **Open**.
   - Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Defaultly.app`

Requires macOS 14 Sonoma or later. Universal build for Apple silicon and Intel. Checksums are in `SHA256SUMS.txt`.
