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

Both applications are built on strict Layered Architectures to guarantee that business logic remains fully decoupled from platform implementation details.

- **Native Android**: Built around Kotlin Flow and Jetpack Compose. Heavy domain separation ensures location-boundary logic is decoupled from Android services.
- **Flutter**: Driven by strict BLoC/Cubit state isolation. The `CameraCubit` strictly coordinates the CameraX plugin, while the `SyncBloc` projects a durable SQLite queue mapped identically to the WorkManager background state.

## Verification

This project holds rigorous standards for automated verification:
- **Native Android**: 158 tests passed, 0 lint warnings.
- **Flutter**: 521 tests passed, 0 analysis issues.
- **Clean Clone**: Both projects build from scratch out-of-the-box (`./gradlew assembleRelease` and `flutter build apk --release`).

## Device QA

Both tasks were extensively vetted on actual Android devices.
- **Primary**: Samsung Galaxy S25 (Android 15)
- **Secondary**: HONOR DNP-NX9 (Android 16)

Performance traits, particularly pinch-to-zoom smoothness and hardware-specific WorkManager constraints, were validated on physical hardware rather than purely in emulators.

## Generative AI Usage

Generative AI was employed openly to structure test plans, design transactional database queries, and discover edge cases. You will find a full, transparent breakdown of prompts and strategies used in the [AI Usage Disclosure](docs/AI_USAGE.md).

## Reviewer Quick Start

The quickest way to evaluate this submission is by installing the pre-built, signed APKs linked above onto an Android device (via `adb install`). 

To build the projects from source:
1. Clone the repository.
2. For Android: Navigate to `android-attendance/` and run `./gradlew assembleDebug`.
3. For Flutter: Navigate to `flutter_camera_sync/`, run `flutter pub get`, then `flutter run`.

## Known Platform Notes

- **HONOR Devices**: Some devices impose an aggressive OEM background restriction (`HN_USER_EXPERIENCE`). For the background queue to drain automatically without the UI present, "Manage manually" must be enabled in App Launch settings. This is standard for apps running background jobs on Honor platforms.
