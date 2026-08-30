# PresenceLens

Two production-style assessment applications demonstrating Native Android location correctness and Flutter camera/offline-sync engineering.

## Assessment status

| Task | Required capability | Status | Evidence |
| --- | --- | --- | --- |
| **Task 1 — Native Android** | Geo-fenced attendance within 50 m, Compose UI, Kotlin Flow | **Done / verified** | [158 tests](#verified-quality) · [screenshot](#native-android--attendance) · [APK](https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Attendance-v1.0.0.apk) |
| **Task 2 — Flutter** | Custom camera, zoom, tap focus, batches, resilient background sync | **Done / verified** | [521 tests](#verified-quality) · [screenshots](#flutter--camera--sync) · [APK](https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Capture-v1.0.0.apk) |
| Documentation | README, architecture, BLoC/Cubit explanations | **Done** | [Architecture](#architecture) · [docs/](docs/) |
| Public repository | Publicly accessible source | **Done** | [github.com/rktuhinbd/PresenceLens](https://github.com/rktuhinbd/PresenceLens) |
| Release APKs | Installable release builds | **Done** | [v1.0.0 release](https://github.com/rktuhinbd/PresenceLens/releases/tag/v1.0.0) |
| Generative AI disclosure | How AI was used + real prompts | **Done** | [docs/AI_USAGE.md](docs/AI_USAGE.md) |
| Screenshots | Screenshots **or** GIF of both apps | **Done** (screenshots) | [Screenshots](#screenshots) |

The assessment asks for screenshots **or** a GIF. Screenshots are delivered; no GIF is provided.

## Applications

| Application | Stack | Architecture | Primary challenge | Verification | Download |
| --- | --- | --- | --- | --- | --- |
| **PresenceLens Attendance** (Task 1) | Kotlin · Jetpack Compose · Flow | Layered MVVM, Android-free domain | Deciding a 50 m rule from a noisy, drifting GPS signal | 158 automated tests · emulator acceptance · physical screenshot evidence | [APK v1.0.0](https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Attendance-v1.0.0.apk) |
| **PresenceLens Capture** (Task 2) | Flutter · Dart · BLoC/Cubit | Presentation → Application/Domain ← Data/Platform | Never losing a photograph across offline, process death, and OEM background limits | 521 automated tests · `flutter analyze` clean · physical device QA | [APK v1.0.0](https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Capture-v1.0.0.apk) |

## Download release builds

| App | Platform | Version | Download |
| --- | --- | --- | --- |
| PresenceLens Attendance | Android | 1.0.0 | [PresenceLens-Attendance-v1.0.0.apk](https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Attendance-v1.0.0.apk) |
| PresenceLens Capture | Android | 1.0.0 | [PresenceLens-Capture-v1.0.0.apk](https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Capture-v1.0.0.apk) |

Both are release-mode Android APKs. Full release page: [v1.0.0](https://github.com/rktuhinbd/PresenceLens/releases/tag/v1.0.0).

## Screenshots

All screenshots are unmodified device captures from a physical HONOR DNP-NX9 (Android 16), taken from the published v1.0.0 APKs.

### Flutter — Camera & Sync

| Camera ready | Focus + zoom | Offline queue |
| --- | --- | --- |
| <img src="docs/assets/flutter/camera-ready.png" alt="Camera ready" width="250"> | <img src="docs/assets/flutter/focus-zoom.png" alt="Focus and zoom" width="250"> | <img src="docs/assets/flutter/uploads-offline.png" alt="Offline pending uploads" width="250"> |
| Live preview, capability-derived zoom presets and slider. | Tap-to-focus reticle at the touch point, held at 2x zoom. | Batch finished while offline — five images waiting, retained on device. |

| Active batch | Synced |
| --- | --- |
| <img src="docs/assets/flutter/camera-active-batch.png" alt="Active batch" width="250"> | <img src="docs/assets/flutter/uploads-success.png" alt="Uploads synced" width="250"> |
| A live draft batch of three captures, with thumbnail and count. | The same five images after connectivity returned — drained automatically, with no manual retry. |

### Native Android — Attendance

| Attendance ready |
| --- |
| <img src="docs/assets/android/attendance-ready.png" alt="Attendance ready" width="250"> |
| Office anchor saved to DataStore, live distance to the office, and eligibility inside the 50 m radius. |

## Technology stack

**Native Android (Task 1)**

- Kotlin
- Jetpack Compose
- Kotlin Coroutines / Flow / StateFlow
- Android ViewModel + lifecycle
- Google Play Services Fused Location Provider
- DataStore Preferences
- Gradle Kotlin DSL
- JUnit
- Android Lint

**Flutter (Task 2)**

- Flutter / Dart
- `flutter_bloc`, `equatable`
- `camera` package (Android CameraX backend through the plugin)
- `sqflite`, `path_provider`
- `workmanager`, `connectivity_plus`
- `bloc_test`, `mocktail`
- `sqflite_common_ffi` for real SQLite test coverage

No backend, cloud, or Firebase services are used. Uploads target a deterministic in-app mock API, which the assessment permits.

## Requirement fulfilment

**Task 1 — Native Android**

| Requirement | Status |
| --- | --- |
| Set Office Location | Done |
| Local persistence of office location | Done |
| Mark Attendance only within 50 m | Done |
| Real-time distance display | Done |
| Jetpack Compose UI | Done |
| Kotlin Flow state management | Done |
| Permission / service failure handling | Done |

**Task 2 — Flutter**

| Requirement | Status |
| --- | --- |
| CameraPreviewScreen with live preview | Done |
| Pinch zoom | Done |
| Zoom slider | Done |
| Capability-driven rounded zoom presets | Done |
| Tap to focus | Done |
| Visual focus indicator | Done |
| Multiple captures / image batches | Done |
| Pending Uploads screen | Done |
| Persistent queue | Done |
| WorkManager background sync | Done |
| Offline retention of failed images | Done |
| Automatic retry / recovery | Done |
| Mock API | Done |
| BLoC / Cubit state management | Done |
| Layered architecture | Done |

Row-level traceability lives in [docs/REQUIREMENTS_MATRIX.md](docs/REQUIREMENTS_MATRIX.md).

## Architecture

### Native Android

Layered MVVM with unidirectional state flow. `AttendanceViewModel` projects one immutable `AttendanceUiState`; events flow up as intents, state flows down through `StateFlow`. The domain layer — the 50 m rule, the Haversine distance, and location qualification — carries no Android imports, so every business rule is testable on the JVM.

### Flutter

**Presentation → Application/Domain ← Data/Platform.** The domain holds pure Dart policies (zoom bounds, focus mapping, batch rules); the data/platform layer holds SQLite DAOs, app-owned file storage, the camera plugin, and the WorkManager isolate.

The two primary classes the assessment asks about:

- **`CameraCubit`** — orchestrates camera discovery, lifecycle, switching, zoom, focus, and capture, emitting one camera state to the UI. It holds no persistence knowledge, so a camera failure can never corrupt a batch.
- **`SyncBloc`** — projects the durable SQLite queue, connectivity, and lifecycle reconciliation into upload presentation state, while transactional correctness stays in the SQL and worker layers beneath it.

Platform access is narrowed behind **`CameraEngine` / `CameraSession`** ports, and background delivery is composed from a WorkManager continuation with backoff over the same durable queue the UI reads.

Deeper detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/DECISIONS.md](docs/DECISIONS.md).

## Beyond the brief

These are engineering enhancements beyond the minimum task requirements, not mandated deliverables. Each is implemented and evidence-backed.

**Native Android**

- Freshness-aware location qualification — a retained fix is bounded by age, not reused indefinitely.
- Accuracy-aware fail-closed behaviour: a fix too coarse to decide a 50 m rule blocks eligibility rather than guessing.
- Office-anchor quality validation — the anchor is refused when the capture fix is too coarse to be trusted.
- Provider fault retry on a capped backoff.
- Android-free domain policy, enforced by a purity test.
- Haversine implementation verified against an independent reference.
- 158 automated tests.

**Flutter**

- Durable app-owned file storage with SQLite metadata; images are never stored as SQLite BLOBs.
- Transactional "Finish batch" — a batch becomes queued atomically or not at all.
- Atomic SQL upload claims, so concurrent workers cannot double-send an image.
- Lease recovery for rows abandoned mid-`UPLOADING`.
- Bounded queue worker with a WorkManager continuation and backoff.
- Connectivity treated as advisory; the API result is authoritative.
- Deterministic mock API for reproducible verification.
- Camera lifecycle generation guards and a capture concurrency guard.
- No fabricated physical lens identity — a camera is never labelled with optics the platform did not report.
- Capability-aware focus and exposure.
- Startup retry boundary.
- Accessibility semantics and reduced-motion support.
- 521 automated tests, plus real-device offline and background QA.

## Verified quality

- **679 automated tests across both applications** — 158 Native Android, 521 Flutter.
- Native Android: Android Lint passes with 0 errors.
- Flutter: `flutter analyze` reports 0 issues.
- Clean-clone verification: cloning into an empty directory and building both apps by following this README alone succeeds ([checklist §2](docs/SUBMISSION_CHECKLIST.md)).
- Both published v1.0.0 APKs were downloaded from the release page and confirmed to install and run on a physical device — every screenshot above comes from those exact binaries.

**Device QA**

- **HONOR DNP-NX9 (Android 16)** — extensive Flutter physical QA: live preview, pinch and slider zoom, presets, tap focus, batch capture, offline batch finishing, durable pending uploads, automatic background drain, and lifecycle recovery.
- **Samsung Galaxy S25** — physical pinch-to-zoom acceptance only.
- **Native Android** — 158 automated tests plus an emulator acceptance walkthrough; the screenshot above was additionally captured on physical HONOR hardware against a live GPS fix.

## Quick start

**Native Android**

```bash
git clone https://github.com/rktuhinbd/PresenceLens.git
cd PresenceLens/android-attendance
./gradlew installDebug
```

**Flutter**

```bash
cd PresenceLens/flutter_camera_sync
flutter pub get
flutter run
```

## Platform scope

iOS project sources are retained for Flutter source compatibility. Physical iOS validation and signed IPA packaging were not performed because this assessment was built and validated from Windows; the requested release deliverable is the Android APK.

## Generative AI usage

Generative AI assisted with requirements extraction, architectural review, SQLite edge-case analysis, and test planning. Every output was verified by the author through tests, static analysis, builds, source inspection, and device QA. Full disclosure with real prompts: [docs/AI_USAGE.md](docs/AI_USAGE.md).

## Repository structure

```
PresenceLens/
├── android-attendance/     # Task 1: Native Android geo-fenced attendance
├── flutter_camera_sync/    # Task 2: Flutter camera & resilient sync
└── docs/                   # Requirements, architecture, decisions, AI disclosure
```

## Assessment documentation

- [Submission summary](SUBMISSION.md)
- [Flutter application details](flutter_camera_sync/README.md)
- [Native Android application details](android-attendance/README.md)
- [Requirements matrix](docs/REQUIREMENTS_MATRIX.md)
- [Architecture](docs/ARCHITECTURE.md) · [Decisions](docs/DECISIONS.md)
- [AI usage disclosure](docs/AI_USAGE.md)
