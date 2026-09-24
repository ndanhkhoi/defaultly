# Code review — v1.0.0 pre-release

Scope: all of `Sources/`, `Tests/`, `scripts/`, `Makefile`, workflows. Baseline: `make build` 0 warnings, `make test` 42/42, CI green on `macos-26` (Xcode 26.6, Swift 6.3.3).

| # | Finding | Severity | Resolution |
|---|---------|----------|------------|
| 1 | Undo pressed during an apply was dropped (`execute` bailed out while busy) | High | Applies are chained onto the previous one, so Undo mid-apply is queued |
| 2 | Toast "Undo" undid whatever was on top of the stack | High | Shown and run only when `undoActionName` matches the toast's change |
| 3 | Restore could not re-create custom formats when no association differed | Med-High | `ApplyBar(otherChanges:)` counts them; Apply stays enabled |
| 4 | Review list bound rows by index (out-of-range risk when the list shrinks) | Med | Bindings look items up by ID |
| 5 | `.task(id: revision)` reset checkboxes; suite screen flashed "nothing to change" | Med | `PlanBuilder.keepingChoices`; suite plan is `nil` (loading) until computed |
| 6 | Active search overrode sidebar navigation | Med | Changing the sidebar clears the search |
| 7 | Relaunch hint lost after reopening Settings; app quit even if relaunch failed | Med | `LanguagePreference.atLaunch`; quit only when the new instance started |
| 8 | Some apply buttons stayed enabled while applying | Low-Med | Disabled while applying |
| 9 | One undecodable custom format wiped the whole list | Low-Med | Lossy per-entry decoding |
| 10 | App list counted stale statuses | Low | Counts over `library.allExtensions` |
| 11 | Verification loop spun on cancellation | Low | Returns when cancelled |
| 12 | `LSRegisterURL` per assignment | Low | **Not changed**: measured 70 µs per call (≈28 ms for 400 formats) |
| 13 | Search needed Vietnamese accents | Low | Diacritic-insensitive name matching |
| 14 | Docs claimed Swift 6.2; CI actually runs Xcode 26.6 / Swift 6.3 | Med | Docs state the real CI toolchain; CI remains the gate |
| 15 | Script details: `git describe` matched any tag, unvalidated version, `hdiutil` flakiness, loose tag filter, CI permissions | Low | `--match 'v[0-9]*'`, version validation, hdiutil retry, `v[0-9]*` tags, `contents: read` |
| — | Dead code / duplication (`appliedCount`, unused conformances, forwarding `app(at:)`, duplicated normalization, "top 4 + More Apps", inclusion overrides, redundant `assumeIsolated`) | — | Removed or extracted (`FileExtension.normalized`, `CappedAppList`, `PlanBuilder.Inclusion`) |
| — | Undo/Redo pairing untested | — | Moved to Core as `ReversibleChange` with tests against a real `UndoManager` |
| — | File-menu items disabled via observation in `Commands` | Manual check | Removed state-dependent `.disabled`; `BackupFlow` and `reload()` guard instead |

After fixes: `make build` 0 warnings, `make test` 47/47.
