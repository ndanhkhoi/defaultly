# Phase 5 — CI/CD & first release

## Files
- `.github/workflows/ci.yml`: push `main` + PRs → `macos-26`: lint strings, `swift build`, `swift test`, universal `make app`, upload artifact.
- `.github/workflows/release.yml`: tag `v*` → test → universal build with `VERSION=${tag#v}` → package → `gh release create` (install notes + generated notes).

## Steps
1. Create the public repo `ndanhkhoi/defaultly` with `gh repo create`; push `main`.
2. Watch CI until green (`gh run watch`).
3. Tag `v1.0.0` → watch the release workflow → verify the release assets.

## Validation
- CI green on `main`.
- Release `v1.0.0` contains `.dmg`, `.zip`, `SHA256SUMS.txt`; `lipo -archs` on the binary prints `x86_64 arm64`.
