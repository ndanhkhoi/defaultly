---
title: Defaultly v1.0
description: >-
  Native macOS app (SwiftUI + SwiftPM) to set the default app for any file type:
  17-category catalog, custom formats, Quick Setup, per-app suggestions,
  Undo/Redo, Backup/Restore, English + Vietnamese, Liquid Glass UI,
  CI/CD producing universal release builds.
status: completed
priority: P1
branch: main
tags: [feature, macos, swiftui, ci]
created: '2026-09-24T13:58:00+07:00'
---

# Defaultly v1.0

## Overview
Implement the spec in `docs/project-overview-pdr.md` following `docs/system-architecture.md`. Principles: SOLID, YAGNI → KISS → DRY (`docs/code-standards.md`).

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Project setup](./phase-01-project-setup.md) | Completed |
| 2 | [Core domain & services](./phase-02-core-domain.md) | Completed |
| 3 | [SwiftUI app, Liquid Glass UI & localization](./phase-03-swiftui-app.md) | Completed |
| 4 | [Packaging (.app, icon, dmg/zip)](./phase-04-packaging.md) | Completed |
| 5 | [CI/CD & first release](./phase-05-ci-release.md) | Completed |

## Dependencies
- Phase 3 needs phase 2 (Core ports and models).
- Phase 4 needs phase 3 (executable target).
- Phase 5 needs phase 4 (packaging scripts are reused by CI).

## Acceptance criteria
See section 6 of `docs/project-overview-pdr.md`.

## Outcome
- CI green on `main` (macos-26, Xcode 26.6, Swift 6.3.3): lint, 47 unit tests, universal build, 0 warnings.
- Release [v1.0.0](https://github.com/ndanhkhoi/defaultly/releases/tag/v1.0.0): `Defaultly-1.0.0.dmg`, `.zip`, `SHA256SUMS.txt`; binary `x86_64 arm64`, ad-hoc signed, verified by download.
- Review outcomes: [reports/code-review-v1-release.md](./reports/code-review-v1-release.md).
- Release [v1.0.1](https://github.com/ndanhkhoi/defaultly/releases/tag/v1.0.1): fixes the crash when switching categories, makes Undo/refresh/prompts safe under concurrency, and gates CI and releases on a UI smoke test. Details: [reports/crash-fix-v1.0.1.md](./reports/crash-fix-v1.0.1.md).

## Risks
| Risk | Mitigation |
|------|-----------|
| macOS silently rejects a handler change for some formats | Read back after every change; retry through NSWorkspace (system prompt); report "macOS kept X" with recovery actions |
| `NSWorkspace.setDefaultApplication` takes ~2 s per call | Instant LaunchServices write first; NSWorkspace only for rejected formats |
| CI toolchain (Xcode 26.6, Swift 6.3) differs from local (Swift 6.4, SDK 26.5) | Only use Swift 6 / SDK 26 features behind `#available`; CI is the gate |
| Tests mutating the user's real associations | Unit tests use fakes only; the integration test is opt-in and uses a made-up extension |
| Gatekeeper blocks the ad-hoc signed app | README documents "Open Anyway" / `xattr` |
| Missing Vietnamese translations | Core test checks catalog names; `plutil -lint` in CI |
