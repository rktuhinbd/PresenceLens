# PresenceLens Capture — Advanced Camera & Resilient Sync

This application is the Flutter submission for Task 2 of the PresenceLens technical assessment. It delivers a resilient, offline-first mobile capture experience with a highly responsive custom camera and background sync engine.

## What it demonstrates

- **Custom Camera Implementation**: Directly interfacing with CameraX for precise lifecycle and optics control.
- **Resilient Background Sync**: Durable SQLite queue paired with WorkManager to ensure no data is lost.
- **Physical Capabilities**: Genuine pinch-to-zoom and tap-to-focus tied to actual device capabilities, not assumed constants.
- **Truthful UI**: Only representing camera configurations and zoom ranges strictly reported by the hardware.

## Architecture

The application is built on a strict layered architecture:

**Presentation → Application/Domain ← Data/Platform**

- **Presentation**: Flutter widgets completely decoupled from business rules.
- **Domain**: Pure Dart policies ensuring that logic like zoom bounds and focus mapping are decoupled from the platform.
- **Data/Platform**: Platform channels, CameraX plugins, SQLite DAOs, and the WorkManager isolate.

## State management

The application utilizes the BLoC pattern for rigorous state isolation. 
- **CameraCubit**: Orchestrates camera discovery, lifecycle, switching, focus, zoom, and capture without embedding any persistence logic.
- **SyncBloc**: Projects durable queue state, connectivity, and lifecycle reconciliation into upload presentation state, while the SQLite and worker layers retain absolute transactional correctness.

## Camera engine

- **Live Preview**: Custom viewport mapping without letterboxing issues.
- **Truthful Rear-Camera Discovery**: Prevents invalid optical claims.
- **Actual Min/Max Zoom**: Extracted directly from the platform.
- **Pinch + Slider**: Unified zoom input mapped to a single source of truth.
- **Tap Focus**: Capability-aware exposure and focus region mapping.
- **Lifecycle/Race Protection**: Asynchronous initialization guards and shutter-speed bounds to prevent state races.

## Offline-first flow

1. **Capture** → writes to a durable, app-owned file.
2. **SQLite Metadata** → atomatically claims the capture record.
3. **Finish Batch** → transitions the batch to a `PENDING` state.
4. **WorkManager** → schedules background drainage.
5. **Deterministic Mock API** → ensures testable success and failure outcomes.
6. **Durable Success/Retry** → ensures no image is discarded due to a transient failure.

## Background sync

Connectivity is treated purely as an advisory state. The network and API results are authoritative. The OS (via WorkManager) strictly controls the exact worker execution timing, ensuring battery-efficient, resilient uploading in the background.

## Persistence

All data is stored in app-owned file directories combined with structured SQLite metadata. Image data is strictly kept out of BLOB storage to ensure optimal database performance.

## Build/run

To build and run the application on a connected device or emulator:

```bash
flutter pub get
flutter run
```

## Tests

The codebase enforces strict quality gates, verified by **521 automated tests** covering widget rendering, BLoC state transitions, SQLite integration, and the headless worker isolate.

## Device QA

- **HONOR DNP-NX9 (Android 16)**: Passed physical verification for live preview, zoom slider/presets, tap focus, capture, rapid shutter guard, multiple capture batches, offline batch finishing, durable pending uploads, background automatic upload, lifecycle recovery, and permission recovery.
- **Samsung Galaxy S25**: Physical pinch-to-zoom acceptance user-confirmed.

## Screenshots

![Camera Ready](../../docs/assets/flutter/camera-ready.png)
![Uploads Offline](../../docs/assets/flutter/uploads-offline.png)
![Uploads Success](../../docs/assets/flutter/uploads-success.png)

## Release APK

The signed release APK can be downloaded here:

https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Capture-v1.0.0.apk

## Generative AI Usage

Generative AI was used transparently to assist with requirements extraction, test planning, SQLite edge-case analysis, and architectural review. See the root [AI_USAGE.md](../docs/AI_USAGE.md) for full disclosure and examples.

## Platform notes

HONOR devices impose an OEM-specific background restriction (`HN_USER_EXPERIENCE`) that suppresses standard WorkManager execution. This is a vendor modification, not an Android or application defect.
