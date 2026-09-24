# v1.0.1 — crash when switching categories

## Symptom
Switching between some sidebar categories quit the app ("Defaultly quit unexpectedly"). Six crash reports, all `EXC_BREAKPOINT` in `EnvironmentValues.subscript.getter`, no app frames.

## Root cause
Reproduced by driving the sidebar programmatically: `Fatal error: No Observable object of type AppModel found`. `FormatCell`, a `Table` cell, read `@Environment(AppModel.self)`. macOS hosts table cells separately and keeps updating cells of removed rows after they leave the view hierarchy, where the environment object is gone. Documents → Spreadsheets (17 → 14 rows) crashed every time.

## Fix
- Every Table cell, List/Form row and menu/toolbar-hosted view now takes plain values or the model as an explicit parameter; only screen-level views read the environment. Rule recorded in `docs/code-standards.md` and `CLAUDE.md`.
- Regression guard: a debug-only `SmokeTest` drives every screen, selection (including switching with rows selected), setup, app, sheet, toast and custom-format add/remove; `make smoke-test` runs on CI and before releases. Verified it fails (exit 133) with the old cell code.

## Also fixed during the review
| Finding | Fix |
|---------|-----|
| `UndoManager` doesn't retain targets; a per-change token was freed, so ⌘Z would crash (caught by a new unit test) | The handler captures the token |
| ⌘Z during an apply undid the previous change | Undo registered as soon as the apply is queued; handler waits for the report |
| Refresh racing an apply could overwrite newer statuses; `loadIfNeeded` didn't wait for a running load | One serial queue for loads, refreshes and applies |
| Interactive retry could prompt repeatedly | Preferred UTI only; stop after the user declines |
| Return applied pending changes while browsing Quick Setup | Return is the default action only in sheets |
| Toolbar/menu content read the environment; menu undo manager could be nil | Passed explicitly |
| Alerts from inside a sheet appeared out of context; "Try Again" could be swallowed | Sheet closes first; alert actions run after dismissal |
| Empty custom category could stay selected in Quick Setup | Treated as no selection |
| Hand-edited backups repeating an extension produced duplicate list IDs | De-duplicated on read |

Verification: 50 unit tests, `make smoke-test` (local and CI), a real apply → mid-apply ⌘Z → redo check on a made-up extension, and stress runs of 5 rounds at 40 ms per step.
