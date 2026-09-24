# Code signing, notarization and Gatekeeper

## How releases are signed today

Releases are signed **ad hoc** (`codesign --sign -`): the bundle is sealed and valid, but not tied to a developer.
Gatekeeper only lets apps from the internet open without asking when they are signed with a Developer ID and
notarized by Apple, so users allow Defaultly once on first launch (see the README).

Gatekeeper only assesses files that carry the `com.apple.quarantine` flag, which browsers and most download tools
add. Defaultly's own updater downloads with `URLSession`, and the app doesn't set `LSFileQuarantineEnabled`,
so its downloads carry no quarantine flag. Updates that Defaultly installs itself therefore open without asking again.
The opt-in `make integration-test` checks this against the latest published release.

There is no free way to remove the first-launch step for a download from a browser. Homebrew casks aren't an option
either: since 2026-09-01 Homebrew no longer accepts casks that fail Gatekeeper, and it removed `--no-quarantine`.

## Turning on Developer ID signing and notarization

This needs a paid Apple Developer Program membership. Once these repository secrets exist, the release workflow
signs with the Developer ID and the hardened runtime, notarizes and staples the app, then signs, notarizes and
staples the dmg. Without them, releases stay ad hoc and nothing else changes.

| Secret | Value |
|--------|-------|
| `APPLE_SIGNING_IDENTITY` | The certificate's name, e.g. `Developer ID Application: Jane Doe (ABCDE12345)` (`security find-identity -v -p codesigning`) |
| `APPLE_CERTIFICATE_BASE64` | The Developer ID Application certificate and its private key, exported from Keychain Access as `.p12`, then `base64 -i certificate.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | The password chosen when exporting the `.p12` |
| `APPLE_ID` | The Apple Account email of the developer |
| `APPLE_APP_PASSWORD` | An app-specific password for that account, from [account.apple.com](https://account.apple.com) → Sign-In and Security |
| `APPLE_TEAM_ID` | The 10-character Team ID from the developer account's membership details |

Steps:

1. In [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/certificates/list), create a
   **Developer ID Application** certificate from a certificate signing request made in Keychain Access, and install it.
2. Export it with its private key as `.p12` and add the secrets above (`gh secret set NAME`).
3. Update `.github/install-notes-notarized.md` if needed; the workflow uses it instead of `.github/install-notes.md`
   for notarized releases. Then simplify the README's first-launch section.
4. Push a tag. The workflow log shows each notarization result; a rejected submission prints Apple's log and fails
   the release.

The same scripts work locally: `SIGN_IDENTITY="Developer ID Application: …" NOTARIZE=1 APPLE_ID=… APPLE_APP_PASSWORD=… APPLE_TEAM_ID=… make package`.

## Updates after the switch

Once the running app is signed with a Developer ID, the updater only installs builds that satisfy a code
requirement for Apple's Developer ID chain issued to the same team, so a team ID written into a self-signed signature
is rejected. The first Developer ID release can still update ad-hoc installs; from then on only the same team's builds
are accepted. `xcrun stapler` sometimes can't find a ticket right after Apple accepts it, so `scripts/notarize.sh`
retries stapling a few times. The hardened runtime needs no entitlements: Defaultly uses no JIT, plug-ins or protected resources.
