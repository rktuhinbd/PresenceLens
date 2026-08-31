# PresenceLens Capture — Engineering Documentation

This application demonstrates a resilient, offline-first Flutter camera and synchronization engine for the Intelligent Machines assessment (Task 2).

## Build & Run

```bash
cd flutter_camera_sync
flutter analyze
flutter test
flutter build apk --debug
```

## Platform Limitation

**Important:** This application targets Android as the delivered mobile platform, with a minimum supported SDK of `minSdk = 24` (enforced by `camera: 0.12.x`). The main manifest also explicitly declares the `INTERNET` permission to prevent silent release-build upload failures. Committed runtime screenshots are Android evidence; no physical iOS QA was performed.

## UI Reference

- [design/index.html](design/index.html)

Implementation-faithful UI reference at the documented release-evidence viewport (365.71 × 800 logical, derived from 1280 × 2800 physical at 3.5 density). Derived from the shipped application source and validated against available v1.0.0 runtime screenshots. Browser and Flutter use different rendering engines, so minor font rasterization and platform-chrome differences are not claimed to be pixel-identical.

## Evidence Scope

- **Runtime-backed**: Committed v1.0.0 screenshots available in `../assets/flutter/`.
- **Source-derived**: Shipped source + deterministic state construction, no committed runtime screenshot.
- **Mixed**: Runtime-backed primary frame plus clearly separated source-derived component variants.

## Current Architecture & Specs

- [UX_SPEC.md](UX_SPEC.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [TEST_STRATEGY.md](TEST_STRATEGY.md)

## Engineering Provenance


## Shared Assessment Evidence

- [../PROJECT_STATE.md](../PROJECT_STATE.md)
- [../REQUIREMENTS_MATRIX.md](../REQUIREMENTS_MATRIX.md)
- [../AI_USAGE.md](../AI_USAGE.md)
