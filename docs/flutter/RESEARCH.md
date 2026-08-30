# Flutter Task — Research Record

Primary-source research for Task 2 (Advanced Camera & Sync Engine). Every finding
below was verified this session against the published package, its API
documentation, or the resolved source in the local pub cache — not from memory.

**What this document is for:** it decides which packages we depend on, which
platform capabilities we may truthfully claim, and which limitations must be
designed around rather than papered over. Findings marked **DECISIVE** changed
the architecture.

Companion: the root [RESEARCH.md](../RESEARCH.md) holds the Android-side record
and the original PDF extraction (`RF-01` … `RF-06`).

Date of research: 2026-08-29.

---

## 1. Verified toolchain

Executed locally this session.

| Item | Value | Command |
| --- | --- | --- |
| Flutter | **3.47.2**, channel `stable`, revision `d3b14c8769` (2026-08-26) | `flutter --version` |
| Dart | **3.13.2** (stable, 2026-08-25) | `dart --version` |
| DevTools | 2.60.0 | `flutter --version` |
| JDK | **Microsoft OpenJDK 21.0.12.1 LTS** (build 21.0.12.1+1-LTS) | `java -version` |
| Gradle (Flutter module) | **8.14** | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | **8.11.1** | `android/settings.gradle.kts` |
| Kotlin (Android module) | **2.2.20** | `android/settings.gradle.kts` |

Note the deliberate asymmetry with the frozen native app, which runs AGP 9.3.2 /
Gradle 9.5.0 (root `RESEARCH.md` `RF-07`). The two Gradle builds are independent;
the Flutter module keeps the toolchain Flutter 3.47.2 generates and validates, and
there is no reason to drag it forward.

### 1.1 Flutter Doctor licence anomaly

`flutter doctor` may report *"Android license status unknown"* while
`flutter doctor --android-licenses` reports that `--licenses` is no longer
required. This is an upstream tooling mismatch between current Android
command-line tools and Flutter's detector.

**It is not treated as a project defect.** The authoritative non-device gates for
this phase are `flutter analyze`, `flutter test`, `flutter build apk --debug`, and
`git diff --check`. A successful APK build is proof the SDK and licences are
actually usable. No downgrade of the CLI tools and no Gradle bump was made to
silence a cosmetic warning.

---

## 2. Dependency findings

All versions below are the **resolved** versions from `pubspec.lock` after a
successful `flutter pub get` against the local SDK — not merely the numbers
advertised on pub.dev.

| Package | Resolved | Role | Why this one |
| --- | --- | --- | --- |
| `flutter_bloc` | **9.1.1** (on `bloc` 9.2.1) | State management | Named by the assessment (`BLoC/Cubit`). Not a choice so much as a requirement. |
| `equatable` | **2.1.0** | Value equality for states | Cubit states are compared to suppress rebuilds. Without it, `==`/`hashCode` must be hand-written on every state class — noise with a real failure mode if one field is forgotten. |
| `camera` | **0.12.0+2** | Preview, zoom, focus, capture | Official `flutter.dev` plugin. The alternatives are unmaintained or wrap the same platform APIs with less scrutiny. |
| `sqflite` | **2.4.3** | Durable queue + batch metadata | Mature, transactional, and runs the real SQLite engine in tests via `sqflite_common_ffi`. |
| `path_provider` | **2.1.6** | App-owned durable directory | The only supported way to locate a directory the OS will not clear. |
| `path` | **1.9.1** | Path joining | Dart-team package; correct separator handling. Trivial but not worth hand-rolling. |
| `workmanager` | **0.10.9** | Background worker | Named by the assessment itself ("e.g., `workmanager`"). |
| `connectivity_plus` | **7.3.1** | Advisory connectivity signal | Used for scheduling hints and UX copy only — see `FR-05`. |
| `bloc_test` | **10.0.0** (dev) | Cubit state-transition tests | Declarative `blocTest` removes most of the boilerplate that otherwise discourages writing these. |
| `mocktail` | **1.0.5** (dev) | Fakes without codegen | Chosen over `mockito` specifically to avoid a `build_runner` step; a reviewer can run `flutter test` with no generation phase. |
| `sqflite_common_ffi` | **2.4.2+1** (dev) | Real SQLite on the Dart VM | **Load-bearing for the test strategy** — lets DAO, transaction and queue-recovery tests run under `flutter test` on Windows with no device attached. |

Transitive versions that matter: `camera_android_camerax` **0.7.4+7**,
`camera_avfoundation` **0.10.3**, `workmanager_android` **0.10.8**,
`workmanager_apple` **0.9.10**, `sqlite3` **3.5.2**.

Rejected without adding: `dio`/`http` (the mock API needs no real transport
yet — see `ADR-F06`), `get_it`/`injectable` (manual wiring is sufficient at this
size, mirroring root `ADR-009`), `freezed` (would add a codegen step to save
boilerplate `equatable` already removes), `permission_handler` (the `camera`
plugin surfaces the camera permission error itself; a second permission library
for one permission is not justified).

---

## 3. Camera findings

### FR-01 — `CameraController` zoom and focus API `[VERIFIED]`

Exact signatures, from the published API docs for `camera` 0.12.0:

```dart
Future<double> getMinZoomLevel();
Future<double> getMaxZoomLevel();
Future<void>   setZoomLevel(double zoom);

Future<void>   setFocusPoint(Offset? point);
Future<void>   setFocusMode(FocusMode mode);
Future<void>   setExposurePoint(Offset? point);
Future<void>   setExposureMode(ExposureMode mode);

Future<XFile>  takePicture();
Future<void>   initialize();
Future<void>   dispose();
Future<void>   pausePreview();
Future<void>   resumePreview();
```

`setFocusPoint` takes a **normalised** offset: the documentation states the
values *"should be anywhere between (0,0) and (1,1)"*, and passing `null`
*"will reset the focus point to it's default value"*.

**Consequence:** tap coordinates must be converted from preview-widget local
pixels into that 0–1 space, accounting for the preview's aspect-ratio letterboxing.
That conversion is pure arithmetic and therefore lives in the domain layer where
it can be unit-tested without a camera (`FLT-CAM-007`).

### FR-02 — The app owns the camera lifecycle `[VERIFIED]`

The `camera` package documents that since version 0.5.0, *"lifecycle changes are
no longer handled by the plugin. This means developers are now responsible to
control camera resources when the lifecycle state is updated."*

**Consequence:** `CameraPreviewScreen` must observe `didChangeAppLifecycleState`
and dispose/reinitialise the controller itself. This is a mandated hardware-failure
path under `FLT-GEN-004`, not an optional polish item.

### FR-03 — Platform minimums `[VERIFIED]`

`camera` 0.12.0 requires **Android SDK 24+** and **iOS 13+**; `path_provider`
2.1.6 requires the same Android floor. `minSdk` is therefore pinned explicitly to
24 in `android/app/build.gradle.kts` rather than inherited from Flutter's default.

### FR-04 — **DECISIVE:** Android cannot identify a physical lens `[VERIFIED IN SOURCE]`

The platform interface *does* now carry a lens type:

```dart
enum CameraLensType { wide, telephoto, ultraWide, unknown }

const CameraDescription({
  required this.name,
  required this.lensDirection,
  required this.sensorOrientation,
  this.lensType = CameraLensType.unknown,   // <- note the default
});
```

But the two implementations diverge, and this was checked by grepping the resolved
packages in the pub cache rather than trusting documentation:

| Implementation | Populates `lensType`? | Evidence |
| --- | --- | --- |
| `camera_avfoundation` 0.10.3 (iOS) | **Yes** | `lib/src/utils.dart` maps `PlatformCameraLensType` → `CameraLensType` for all four cases. |
| `camera_android_camerax` 0.7.4+7 (Android) | **No** | No occurrence of `lensType`, `ultraWide` or `telephoto` anywhere in the package, Dart or native. Every description therefore takes the constructor default, `CameraLensType.unknown`. |

`availableCameras()` on Android enumerates CameraX's
`getAvailableCameraInfos()` and names each camera by its **Camera2 camera ID**
string (`Camera2CameraInfo.from(...).getCameraId()`), carrying only
`lensDirection` and `sensorOrientation` as semantics. This matches the open
upstream issues on physical-camera support
([flutter/flutter#173406](https://github.com/flutter/flutter/issues/173406),
[flutter/flutter#145800](https://github.com/flutter/flutter/issues/145800)).

**Consequence — this closes root `ER-05` and constrains `FLT-CAM-005`.** On
Android, the only mandated deliverable platform (root `AMB-12`), the app has **no
truthful basis for labelling a back camera "0.5x" or "2x"**. Any such label would
be fabricated.

The design therefore derives presets from values the device actually reports —
see [CAMERA_ENGINE.md](CAMERA_ENGINE.md) §4 and [DECISIONS.md](DECISIONS.md)
`ADR-F03`. On iOS the richer `lensType` is used when present. That asymmetry is
kept visible rather than abstracted away.

### FR-12 — **DECISIVE:** Android cannot report *permanent* camera denial `[VERIFIED IN SOURCE]`

Found at gate F3, while mapping permission codes for `FLT-ERR-001`/`FLT-ERR-002`.
Verified by reading the resolved plugin sources in the local pub cache, the same
method that produced `FR-04`.

The `camera` plugin's own example app branches on four permission codes:

```
CameraAccessDenied
CameraAccessDeniedWithoutPrompt
CameraAccessRestricted
AudioAccessDenied
```

But the two platform implementations do not emit the same set:

| Code | `camera_android_camerax` 0.7.4+7 | `camera_avfoundation` 0.10.3 |
| --- | --- | --- |
| `CameraAccessDenied` | **Yes** | Yes |
| `CameraAccessDeniedWithoutPrompt` | **No** | Yes |
| `CameraAccessRestricted` | **No** | Yes |
| `CameraPermissionsRequestOngoing` | Yes | — |

`android/src/main/java/io/flutter/plugins/camerax/CameraPermissionsManager.java`
declares exactly two error constants — `CAMERA_ACCESS_DENIED` and
`AUDIO_ACCESS_DENIED` — and its `onRequestPermissionsResult` constructs the
camera one for **every** refusal, including the empty-`grantResults` case. There
is no third branch. `CameraPermissionManager.swift` on iOS is where
`...WithoutPrompt` and `...Restricted` come from.

**Consequence — this constrains `FLT-ERR-002`.** On Android, the only mandated
platform (root `AMB-12`), the app **cannot distinguish "denied once, ask again"
from "denied for good, go to settings"** through the camera plugin. Android's
own `shouldShowRequestPermissionRationale` carries that signal, but the plugin
does not surface it and reaching it would mean adding `permission_handler` — a
second permission library for one permission, which `§2` already rejected.

The design therefore reports only what the platform said
(`CameraPermissionDenied.isPermanentPerPlatform`, always `false` on Android) and
separately counts consecutive refusals so the later UI can *escalate its offer*
without asserting a verdict it was never given. See
[DECISIONS.md](DECISIONS.md) `ADR-F22`.

---

## 4. Sync and persistence findings

### FR-05 — **DECISIVE:** connectivity is not reachability `[VERIFIED]`

`connectivity_plus` 7.3.1 states plainly: *"You should not rely on the current
connectivity status to decide whether you can reliably make a network request"*,
because *"Connection type availability does not guarantee that there is an
Internet access."*

API shape: `checkConnectivity()` returns `Future<List<ConnectivityResult>>` and
`onConnectivityChanged` is a `Stream<List<ConnectivityResult>>` — both **lists**,
because a device can hold several links at once.

**Consequence — this closes root `ER-07` and `AMB-15`.** "A stable connection is
detected" cannot be implemented as `if (wifi) upload()`. The only authority on
whether the network works is an actual upload attempt and its outcome.
Connectivity is demoted to three advisory uses: a WorkManager constraint, an
opportunistic reschedule trigger, and UX copy. See
[SYNC_ENGINE.md](SYNC_ENGINE.md) §3.

### FR-06 — WorkManager retry semantics `[VERIFIED — CORRECTED AT F1]`

From the Android `ListenableWorker.Result` reference: `success()`, `failure()`
(terminal, no retry) and `retry()` (reschedule per the backoff policy).
`BackoffPolicy` is `EXPONENTIAL` or `LINEAR`.

> **Correction, F1 post-audit.** This entry previously stated that WorkManager
> enforces a **15-second** minimum backoff. That is wrong. Read directly from
> the compiled `androidx.work.WorkRequest` in
> `androidx.work:work-runtime:2.11.2` — the version this project actually
> resolves, confirmed with `gradlew app:dependencies`:
>
> | Constant | Value |
> | --- | --- |
> | `MIN_BACKOFF_MILLIS` | `10000` — **10 seconds** |
> | `MAX_BACKOFF_MILLIS` | `18000000` — 5 hours |
> | `DEFAULT_BACKOFF_DELAY_MILLIS` | `30000` — 30 seconds |
>
> The app's configured 15 seconds is therefore a deliberate initial delay that
> sits above the floor, not the floor itself. The value is unchanged; only the
> claim about it is corrected. The original figure came from documentation read
> at F0 rather than from the artifact, which is why the artifact is now the
> cited source.

**Consequence:** the platform already provides exponential backoff with a floor
and a ceiling. Re-implementing a backoff timer in Dart would fight it. The Dart
worker's job is to return the right *result*; the OS owns the *when*.

**Second consequence, found at the F1 audit.** Because `false` means *retry with
backoff*, it must be reserved for work that actually failed. A worker that
returns `false` merely because its own item bound was reached puts a perfectly
healthy backlog under an escalating backoff curve — the more of the queue it
successfully uploads, the slower the rest drains. Healthy continuation is a
separate answer; see `ADR-F19` and [SYNC_ENGINE.md](SYNC_ENGINE.md) §5.

### FR-06a — `ExistingWorkPolicy.append` is `APPEND_OR_REPLACE` `[VERIFIED]`

Read from `workmanager_android` 0.10.8's own Kotlin
(`WorkManagerUtils.kt`, `toAndroidWorkPolicy()`):

```kotlin
APPEND  -> ExistingWorkPolicy.APPEND_OR_REPLACE
KEEP    -> ExistingWorkPolicy.KEEP
REPLACE -> ExistingWorkPolicy.REPLACE
UPDATE  -> ExistingWorkPolicy.APPEND_OR_REPLACE
```

Two things follow, and both matter for the continuation design.

**The plugin's Dart documentation does not describe its native behaviour.** The
Dart doc for `append` describes plain `APPEND`, and the doc for `update` says
the request "will be updated with the new specification" — which is
`ExistingPeriodicWorkPolicy.UPDATE` semantics, not what one-off work does. The
Kotlin is the authority here, and it was read rather than trusted.

**`APPEND_OR_REPLACE` is the variant we want.** Plain `APPEND` marks the new
work `CANCELLED`/`FAILED` if the existing chain is in that state;
`APPEND_OR_REPLACE` starts a fresh chain instead. A continuation enqueued from
inside a running worker therefore cannot inherit a poisoned chain.

**`KEEP` would be silently wrong for a continuation.** A worker asking for its
own successor *is* itself uncompleted work under that unique name, so `KEEP`
would discard the request and the backlog would sit until some unrelated trigger
came along. This is exactly the kind of failure that looks correct in review and
never fires in a test.

### FR-07 — `workmanager` 0.10.9 API surface `[VERIFIED]`

Now federated (`workmanager_android`, `workmanager_apple`, plus experimental web
and Linux). Relevant signatures:

```dart
Future<void> initialize(Function callbackDispatcher, {bool isInDebugMode = false});

Future<void> registerOneOffTask(
  String uniqueName,
  String taskName, {
  Map<String, dynamic>? inputData,
  Duration? initialDelay,
  Constraints? constraints,
  ExistingWorkPolicy? existingWorkPolicy,
  BackoffPolicy? backoffPolicy,
  Duration? backoffPolicyDelay,
  String? tag,
  OutOfQuotaPolicy? outOfQuotaPolicy,
  ForegroundServiceConfig? foregroundServiceConfig,
  bool expedited = false,
});

void executeTask(BackgroundTaskHandler handler, {BackgroundTaskStoppedHandler? onTaskStopped});
```

Enum values, read from
`workmanager_platform_interface-0.10.4/lib/src/pigeon/workmanager_api.g.dart`:

- `NetworkType`: `connected`, `metered`, `notRequired`, `notRoaming`, `unmetered`, `temporarilyUnmetered` (API 30+)
- `BackoffPolicy`: `exponential`, `linear`
- `ExistingWorkPolicy`: `append`, `keep`, `replace`, `update`
- `Constraints(networkType, requiresBatteryNotLow, requiresCharging, requiresDeviceIdle, requiresStorageNotLow, contentUriTriggers)`

The `callbackDispatcher` must be annotated `@pragma('vm:entry-point')` or it is
tree-shaken out of release builds.

**Consequence, as originally read:** `ExistingWorkPolicy.keep` on a single fixed
unique name is the cheapest defence against piling up duplicate drain requests —
the OS ignores a second registration while one is pending. This closes root
`ER-06`.

> **Corrected at F1 final acceptance.** "Ignores a second registration while one
> is pending" is exactly the problem, because **a running worker is pending**.
> A drain requested while a worker is mid-pass is discarded, so a batch finished
> in that window can end up durably `PENDING` with nothing scheduled to collect
> it — no data loss, no symptom, and no worker coming back.
>
> Every registration now uses `append`, which maps to `APPEND_OR_REPLACE`
> (`FR-06a`) and enqueues a successor instead of discarding. Duplicate protection
> is retained by the **single unique name**, which keeps WorkManager running the
> chain one node at a time; redundant requests become idle nodes rather than
> parallel drains. See `ADR-F21`.

### FR-08 — **DECISIVE:** sqflite cross-isolate access is not a mutual-exclusion guarantee `[VERIFIED]`

Two facts from the package's own documentation and changelog:

- *"concurrent read and write transaction are not supported. All calls are
  currently synchronized and transactions block are exclusive."* That
  synchronisation is **per database instance within one isolate**.
- Cross-isolate support is described as *"Initial support of cross isolate safe"*
  (2.2.0+3), with *"Fix concurrency issue in database worker pool"* (2.2.5).
  Historic deadlocks with background engines were iOS-specific (issue #168).

The WorkManager callback runs in a **separate Flutter isolate** with its own
plugin channels, so it opens its **own** database connection to the same file.

**Consequence — the single most important design constraint in the sync engine.**
Mutual exclusion between the UI isolate and the worker isolate must **not** rely
on an in-process Dart lock or on sqflite's internal synchronisation, because
neither spans isolates. It must be enforced *in the database itself*, by an
atomic conditional `UPDATE` that claims a row (a lease), so that the claim either
wins or loses at the SQLite level. See [SYNC_ENGINE.md](SYNC_ENGINE.md) §4 and
`ADR-F04`.

### FR-09 — Storing image bytes in SQLite is rejected `[DESIGN]`

Not a library finding but recorded here because it is a frequent mistake. Image
blobs in SQLite inflate the database, make every queue read expensive, and defeat
`sqflite`'s exclusive-transaction model under load. Images go to an app-owned
directory from `path_provider`; the database stores the path. This confirms root
[ADR-005](../DECISIONS.md#adr-005).

---

## 5. UI, motion and accessibility findings

### FR-10 — Material 3 is the correct foundation `[VERIFIED]`

Flutter's Material 3 uses **tonal elevation** (`surfaceTint` layered by
elevation) rather than heavy shadows, and colour is expressed through **roles**
derived from a seed into tonal palettes — `primary`, `onPrimary`,
`primaryContainer`, `surface`, `surfaceContainerHighest`, `outline`, and so on.
Guidance is explicit that one designs against roles, never raw hex values.

**Consequence:** the token set in [UX_SPEC.md](UX_SPEC.md) is defined as role
assignments, so light and dark are one definition rather than two hand-tuned
palettes. The camera screen is the deliberate exception — see `FR-12`.

### FR-11 — Reduced motion is readable at runtime `[VERIFIED]`

`MediaQueryData.disableAnimations` reports *"whether the platform is requesting
that animations be disabled or reduced as much as possible"*, and
`MediaQuery.disableAnimationsOf(context)` is the preferred accessor because it
rebuilds only on that attribute. `MediaQueryData.accessibleNavigation` reports
that a screen reader is driving navigation.

**Consequence:** every animation specified in [UX_SPEC.md](UX_SPEC.md) §7 has a
defined reduced-motion behaviour, and the focus reticle in particular must still
*appear* (it is required feedback under `FLT-CAM-008`) while its animation
collapses to an instant state change.

### FR-12 — Camera UI is not a Material surface problem `[DESIGN]`

A camera viewfinder is a dark, edge-to-edge content surface with floating
controls. Applying default Material container colours over a live preview
destroys it. The design keeps Material 3 as the app's foundation (`FR-10`) but
gives the camera route a **fixed dark control palette** that does not follow the
system light/dark setting, because the content behind it is always a live image.
This is stated as a decision (`ADR-F07`) rather than left as an inconsistency.

---

## 6. Research still open

Items that genuinely cannot be closed from a Windows host without hardware.

| ID | Question | Blocks | Why it cannot be closed now |
| --- | --- | --- | --- |
| `FQ-01` | How many back cameras does `availableCameras()` actually return on a representative multi-lens Android device, and what zoom range does each report? | Final labelling of the preset buttons (`FLT-CAM-005`) | Emulators expose a synthetic camera set. Only a physical device answers this. The design is built to be correct for `n = 1` and for `n > 1` (CAMERA_ENGINE.md §4). |
| `FQ-02` | Real WorkManager scheduling latency for a network-constrained one-off task on a modern OEM Android build. | Expectation-setting in the README, not correctness | OEM battery managers vary widely. The design must not depend on promptness — only on eventual execution. |
| `FQ-03` | iOS `BGTaskScheduler` behaviour for the configured identifier. | iOS parity claims only | **Cannot be validated from Windows.** iOS is configured on a best-effort basis and no iOS verification will be claimed. |
| `FQ-04` | Whether `pausePreview()`/`resumePreview()` is sufficient on Android for a brief app-switch, or whether full dispose/reinitialise is required. | `FLT-CAM-010` implementation detail | Needs a device; the safe path (full dispose on `paused`) is specified as the default. |

---

## 7. Research discipline

A finding is recorded here only if it was verified this session from the package,
its API documentation, or the resolved source in the pub cache. Version numbers
come from `pubspec.lock` after a real resolution, not from a package's landing
page. Where a claim could not be verified — every row in §6 — it is listed as
open rather than assumed, and no design in this pack depends on its optimistic
answer.
