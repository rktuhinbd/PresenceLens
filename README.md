# PresenceLens

PresenceLens is a senior-level technical assessment submission comprising two separate applications: a native Android geolocation app and a Flutter camera-and-sync app.

This repository satisfies all requirements specified in the Intelligent Machines technical assessment, prioritizing simple, production-defensible architectures, offline-first reliability, and strict separation of concerns.

## Tasks

### [Task 1 — Native Android Attendance](android-attendance/)
A geo-fenced attendance system built with Kotlin and Jetpack Compose.
- High-accuracy FusedLocationProvider integration.
- Strictly bounds-checked attendance logic (50m radius).
- Graceful recovery from permission denials and location service dropouts.
- Offline-durable DataStore persistence.
- Layered MVVM architecture using Kotlin Flow UDF.

### [Task 2 — Flutter Advanced Camera & Sync](flutter_camera_sync/)
An offline-first camera application with a resilient background sync engine.
- Custom live camera preview using CameraX via method channels.
- Genuine capability-driven zoom controls (pinch and slider) and tap focus.
- Multiple capture batches with offline-durable SQLite queueing.
- Background automatic recovery and sync via WorkManager.
- Strict BLoC/Cubit state management separating UI from persistence.

## Quick Links

- [Flutter Application Details](flutter_camera_sync/README.md)
- [Requirements Traceability Matrix](docs/REQUIREMENTS_MATRIX.md)
- [Generative AI Usage](docs/AI_USAGE.md)
- [Architecture & Design Decisions](docs/DECISIONS.md)

## Architecture Highlights

Both applications share a strict adherence to layered architecture and testable business logic:
- **Presentation**: Pure UI functions and ViewModels/Cubits that manage state transitions.
- **Domain**: Pure business rules (e.g., `AttendanceRule`, `ZoomPolicy`, `FocusPointMapper`). Flutter domain is 100% free of Flutter/UI dependencies.
- **Data**: Repositories abstracting local SQLite/DataStore, file system, and API connections.

**Flutter BLoC/Cubit Highlights:**
- `CameraCubit`: Orchestrates camera discovery, lifecycle, focus, zoom, and capture without owning persistence.
- `BatchCubit`: Manages the draft capture batch and the atomic finish action.
- `SyncBloc`: Projects the durable queue, connectivity, and lifecycle state into the UI while SQLite and the WorkManager handle correctness.

## Device QA & Testing

Both applications have been rigorously verified on hardware and through automated testing:
- **Android QA Device**: HONOR DNP-NX9 (Android 14)
- **Flutter QA Device**: Samsung Galaxy S25 (Android 15)
- **Automated Tests**: Over 590 total tests across both apps (70 Android, 521 Flutter). All tests PASS.

## Screenshots

### Native Android Attendance
![Android Attendance](docs/assets/android/attendance_ready.png)
*(See `docs/assets/android` for full set)*

### Flutter Camera & Sync
![Camera Ready](docs/assets/flutter/camera_ready.png)
![Pending Uploads](docs/assets/flutter/pending_uploads.png)
*(See `docs/assets/flutter` for full set)*

## Release Artifacts

- **Android Task 1 APK**: [PUBLICATION PENDING]
- **Flutter Task 2 APK**: [PUBLICATION PENDING]

## Generative AI Usage

AI was employed strategically for this assessment to accelerate research, explore edge cases, and ensure robust test coverage. See [docs/AI_USAGE.md](docs/AI_USAGE.md) for full details. 

AI was used for:
- Requirements traceability and matrix generation
- Architecture and API research
- Adversarial edge-case discovery (e.g., WorkManager races, camera lifecycle dropouts)
- Test strategy and implementation reviews

*Example Prompt (WorkManager Race Condition):*
> "I have a WorkManager task draining a SQLite queue. The user can also manually press 'Retry' in the UI. How do I prevent duplicate uploads of the same image if the periodic background job fires exactly when the user presses Retry?"

Outputs were validated strictly through automated tests, static analysis (`flutter analyze`), and real-device QA on Samsung and Honor devices.

## How to Run

### Clean Clone
```bash
git clone https://github.com/rktuhinbd/PresenceLens.git
cd PresenceLens
```

### Run Native Android (Task 1)
Prerequisites: JDK 17, Android SDK.
```bash
cd android-attendance
./gradlew assembleDebug
```
Open in Android Studio and run on an emulator or physical device.

### Run Flutter (Task 2)
Prerequisites: Flutter SDK (3.24+).
```bash
cd flutter_camera_sync
flutter pub get
flutter run
```

## Repository Structure

```
PresenceLens/
├── android-attendance/     # Task 1: Native Android Geo-fenced app
├── flutter_camera_sync/    # Task 2: Flutter Camera & Resilient Sync app
├── docs/                   # Architectural decisions, matrices, and planning
└── README.md               # This file
```
