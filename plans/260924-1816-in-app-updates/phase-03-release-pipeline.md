# Phase 3 — Release pipeline: CHANGELOG.md, optional Developer ID + notarization, docs

## Files
- `CHANGELOG.md` (new), bundled by `scripts/build-app.sh`.
- `scripts/release-notes.sh` (new): the tag's changelog section + install notes + compare link; fails when missing.
- `scripts/build-app.sh`: `SIGN_IDENTITY` (default `-`); Developer ID signs with hardened runtime and a timestamp.
- `scripts/notarize.sh` (new) and `scripts/package-release.sh`: when `NOTARIZE=1`, sign + notarize + staple the dmg, staple the app, then zip.
- `.github/workflows/release.yml`: import the certificate and notarize only when secrets exist; notes from `scripts/release-notes.sh`.
- Docs: README (updates, privacy, Gatekeeper), `docs/code-signing-and-notarization.md` (new), spec, architecture, code standards, CLAUDE.md.

## Validation
- `scripts/release-notes.sh 1.0.1` prints the section; an unknown version fails.
- Signing/notarization paths exercised with stub `codesign`/`xcrun` on PATH (no Apple account available).
