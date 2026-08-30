# PresenceLens Technical Assessment Submission

**Repository:** https://github.com/rktuhinbd/PresenceLens
**Task 1 Source:** https://github.com/rktuhinbd/PresenceLens/tree/main/android-attendance
**Task 2 Source:** https://github.com/rktuhinbd/PresenceLens/tree/main/flutter_camera_sync

**Release:** https://github.com/rktuhinbd/PresenceLens/releases/tag/v1.0.0
**Native APK:** https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Attendance-v1.0.0.apk
**Flutter APK:** https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Capture-v1.0.0.apk

---

## Implementation Overview

This submission fulfills all requirements of the Intelligent Machines technical assessment across two applications:
1. **Native Android Geo-Attendance**: High-precision location capture with firm boundary validation (50m) and offline-first persistence.
2. **Flutter Advanced Camera & Sync**: A custom capability-driven camera experience paired with an atomic, resilient background synchronization engine.

## Architecture

Both applications are built on layered architectures that keep business logic decoupled from platform implementation details.

- **Native Android**: Built around Kotlin Flow and Jetpack Compose. Heavy domain separation ensures location-boundary logic is decoupled from Android services.
- **Flutter**: Driven by strict BLoC/Cubit state isolation. The `CameraCubit` strictly coordinates the CameraX plugin, while the `SyncBloc` projects a durable SQLite queue mapped identically to the WorkManager background state.

## Verification

This project holds rigorous standards for automated verification:
- **Native Android**: 158 tests passed, 0 lint warnings.
- **Flutter**: 521 tests passed, 0 analysis issues.
- **Clean Clone**: Verified from a fresh clone with standard local SDK configuration (`./gradlew assembleRelease` and `flutter build apk --release`).

**Flutter:**
- **HONOR DNP-NX9 (Android 16)**: extensive live camera, capture, focus, zoom, offline queue, automatic background recovery, permission and lifecycle QA.
- **Samsung Galaxy S25 (Android 15)**: manual physical pinch-to-zoom acceptance after selective-rebuild optimization.

**Native Android:**
- 158 automated tests + emulator acceptance.

## Generative AI Usage

Generative AI was employed openly to structure test plans, design transactional database queries, and discover edge cases. You will find a full, transparent breakdown of prompts and strategies used in the [AI Usage Disclosure](docs/AI_USAGE.md).

## Reviewer Quick Start

The quickest way to evaluate this submission is by installing the pre-built release APKs linked above onto an Android device (via `adb install`).

To build the projects from source:
1. Clone the repository.
2. For Android: Navigate to `android-attendance/` and run `./gradlew assembleDebug`.
3. For Flutter: Navigate to `flutter_camera_sync/`, run `flutter pub get`, then `flutter run`.

## Known Platform Notes

- **HONOR Devices**: An OEM-specific HN_USER_EXPERIENCE background-launch restriction was observed on the HONOR test device; enabling manual App Launch management allowed WorkManager to execute. This is recorded as device-specific behavior, not a general Android requirement.
