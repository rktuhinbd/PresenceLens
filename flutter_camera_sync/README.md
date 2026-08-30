# PresenceLens Capture — Advanced Camera & Resilient Sync

## What It Demonstrates

This application is the Task 2 submission for the PresenceLens technical assessment, demonstrating:
- Custom live camera preview implementation
- Genuine physical zoom controls (slider and pinch)
- Tap focus with capability-aware exposure mapping
- Multiple capture batches
- Durable offline queueing (SQLite)
- Background automatic recovery and sync
- Strict BLoC/Cubit state management
- Clean layered architecture

## Architecture

The application strictly adheres to a layered architecture:

**Presentation → Domain ← Data / Platform**

- **Presentation**: Flutter UI widgets, strictly decoupled from business rules.
- **Domain**: Pure Dart policies (e.g., `ZoomPolicy`, `FocusPointMapper`), 100% free of Flutter, UI, or IO dependencies.
- **Data / Platform**: Platform channels, CameraX, SQLite DAOs, and the WorkManager isolate.

## State Management

State is entirely managed by BLoC and Cubit:
- **CameraCubit**: Orchestrates camera discovery, lifecycle, focus, zoom, and capture operations, delegating persistence to the data layer.
- **SyncBloc**: Projects the durable SQLite queue, network connectivity, and lifecycle state into the UI, ensuring the visual representation is always anchored to the single source of truth.

## Offline Flow

The application prioritizes an offline-first capture experience:
1. **Capture** → writes to a durable app-owned file.
2. **SQLite metadata** → records the capture atomically.
3. **Finish batch** → marks the batch as `PENDING` in the queue.
4. **WorkManager** → scheduled to drain the queue in the background.
5. **Deterministic Mock API** → simulates network outcomes cleanly.
6. **Durable success/retry** → failed attempts remain in the queue for automatic retry.

Connectivity is advisory: the application never blocks the user based on network status.

## Camera Identity

Physical lens identity is **never fabricated**. Zoom presets (`1x`, `2x`) are generated dynamically based on the optical range actually reported by the Android device. If the device reports an unknown lens type, the app relies on the truthful fallback rather than inventing a physical camera label.

## Build and Run

```bash
flutter pub get
flutter run
```

## Quality

The codebase enforces strict quality gates:
```bash
flutter analyze
flutter test
flutter build apk --release
```
Over 521 automated tests cover widget rendering, BLoC state transitions, SQLite integration, and the headless worker isolate.

## Device QA

Physically verified on two distinct hardware profiles:

- **Samsung Galaxy S25 (Android 15)**: Primary validation device. Passed cold launch, pinch-to-zoom performance optimization, tap focus, batching, and standard Android background WorkManager execution.
- **HONOR DNP-NX9 (Android 14)**: Validated camera logic and storage. Note: Honor imposes a proprietary OEM background-launch restriction (`HN_USER_EXPERIENCE`) that suppresses WorkManager unless "Manage manually" is enabled in App Launch settings. This is a vendor modification, not a standard Android or application defect.

## Screenshots

![Camera Active](docs/assets/flutter/camera_ready.png)
![Pending Uploads Offline](docs/assets/flutter/pending_uploads.png)

*(Additional screenshots available in `docs/assets/flutter/`)*

## Release APK

[Release APK — PUBLICATION PENDING]
