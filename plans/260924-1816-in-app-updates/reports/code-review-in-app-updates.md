# Code review: in-app updater, release notes, release pipeline

Independent review of the uncommitted in-app update work, 2026-09-24. The reviewer read the code, ran `make test`,
crafted zips through `ditto -x -k`, checked `Bundle(url:)` caching with a standalone script, and read the Security
framework's validation code. Every finding below was checked against the code before it was fixed.

## Findings and outcomes

| # | Severity | Finding | Outcome |
|---|----------|---------|---------|
| H1 | High | The same-team check compared `kSecCodeInfoTeamIdentifier` after validating without a requirement, so a self-signed signature claiming the team would pass; an unreadable running signature disabled the check | Fixed: `RunningSignature` (`adHoc`, `developerID`, `unreadable`). A Developer ID app requires Apple's Developer ID chain with its team as a `SecRequirement`; `unreadable` accepts nothing. Tests cover a mismatched team, Apple's own apps and unsafe team strings |
| H2 | High | If moving the new app in failed and the rollback failed too, the deferred cleanup deleted the old app (possible when the app is on another volume) | Fixed: the new app is moved onto the app's volume first, then swapped with `renamex_np(RENAME_SWAP)` in one atomic step; any failure leaves the installed app untouched. Test: a failed swap keeps the old, valid app |
| M1 | Medium | `Bundle(url:)` caches Info.plist per path, so a second download in one session was checked against the first; the bundle-ID test passed for the wrong reason | Fixed: unpack into a new folder each time and read `Contents/Info.plist` from disk. Tests are parameterized, and one prepares twice with the same staging folder |
| M2 | Medium | Cancel only reached checks started from the window; an automatic check could reopen the window after Cancel | Fixed: every check and download runs as the single `work` task; checks stop on cancellation. Controller test |
| M3 | Medium | `start()` cancelled a background download and left the controller in a phase that stopped automatic checks | Fixed: `start()` only restarts the timer; a cancelled background download goes to `idle`; failures the user asked about reopen the window. Controller tests |
| M4 | Medium | Install on quit ignored turning automatic installs off | Fixed: turning automatic installs or checks off drops the background download, and quitting checks both settings. Controller test |
| M5 | Medium | The language "Relaunch Now" with a downloaded update let the quitting instance replace the bundle under the new one | Fixed: `UpdateController.relaunchApp()` installs a ready update first. Controller test |
| L1 | Low | A double click could start two downloads | Fixed: `begin` sets the phase immediately and refuses while `work` runs. Controller test |
| L2 | Low | A failed relaunch after a successful install said nothing | Fixed: new `installed` phase explains it and offers **Quit Defaultly**. Controller test |
| L3 | Low | A background download could sit in the caches for days and be installed without another check | Fixed: `install` verifies the prepared app again. Test |
| Q | Question | `xcrun stapler staple` can fail right after acceptance | Fixed: `scripts/notarize.sh` retries stapling five times, 20 s apart; exercised with a stub that fails once |
| Q | Question | Should users coming from 1.0.x see Release Notes on first launch? | Left as is: 1.0.x never recorded a version, so they're treated as a fresh install. Owner's call |
| Plan | — | Plan files described names and phases that differ from the code | Fixed in the phase files |

## Verification after the fixes
- `make test`: 77 Core tests and 13 new `UpdateController` tests (`Tests/DefaultlyTests`) pass; `make lint`, `make smoke-test` pass.
- `make integration-test`: installs the published v1.0.1 into a temporary folder; no quarantine flag.
- End to end with the real bundle: a 1.0.0 build in a temporary Applications folder found v1.0.1, a double-clicked
  Install ran once, the bundle was swapped atomically, and v1.0.1 relaunched from the same path, validly signed, without
  a quarantine flag or leftovers.
