# Phase 1 — Project setup

## Context
- Spec: `docs/project-overview-pdr.md`
- Architecture: `docs/system-architecture.md`

## Requirements
- Git repo on `main`; SwiftPM package with `DefaultlyCore`, `Defaultly`, `DefaultlyCoreTests`.
- `platforms: [.macOS(.v14)]`, `swift-tools-version: 6.0`.

## Files
- Create: `Package.swift`, `.gitignore`, `LICENSE` (MIT), `README.md`, `CLAUDE.md`, `Makefile`.
- Create: `docs/*.md` and this plan.

## Steps
1. Verified: a SwiftUI app + Swift Testing builds and runs with Command Line Tools only (Swift 6.4). The macOS 27 SDK makes `@State` a macro whose plugin only ships with Xcode, so local builds use the macOS 26 SDK (`scripts/sdk-root.sh`).
2. Verified: `NSWorkspace.setDefaultApplication(at:toOpen:)` sets and reads back a made-up extension.
3. Create skeleton and docs.

## Validation
- `swift build` passes.
