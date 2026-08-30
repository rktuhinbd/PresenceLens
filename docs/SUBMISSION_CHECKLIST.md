# Submission Checklist

Binary and auditable. Every line is either objectively true or it is not — no
"mostly", no "in progress". Anything not ticked is not delivered.

Walked end to end at gate G9. Each item names the requirement it discharges.

---

## 1. Repository — public GitHub

| # | Check | Req |
| --- | --- | --- |
| 1.1 | [x] Repository exists on GitHub. | SUB-01 |
| 1.2 | [x] Repository visibility is **Public**. | SUB-01 |
| 1.3 | [x] Repository URL loads **while signed out of GitHub** (verified in a private window, not assumed from the settings page). | SUB-01 |
| 1.4 | [x] Default branch contains the final submitted state. | SUB-01 |
| 1.5 | [x] Repository has a description and is not named as a throwaway. | GEN-05 |

## 2. Source code — complete and functioning

| # | Check | Req |
| --- | --- | --- |
| 2.1 | [x] Native Android application source is committed. | AND-01, SUB-01 |
| 2.2 | [x] Flutter application source is committed. | FLT-01, SUB-01 |
| 2.3 | [x] Clean clone into an empty directory succeeds. | SUB-01, DOC-07 |
| 2.4 | [x] Android `assembleDebug` passes **on the clean clone**. | SUB-01 |
| 2.5 | [x] `flutter build apk --debug` passes **on the clean clone**. | SUB-01 |
| 2.6 | [x] Android unit tests pass. | GEN-08 |
| 2.7 | [x] `flutter test` passes. | GEN-08 |
| 2.8 | [x] `flutter analyze` reports no issues. | GEN-08 |
| 2.9 | [x] Android lint/format clean. | GEN-08 |
| 2.10 | [x] No `TODO`, placeholder, or dead scaffold left in shipped code. | EXP-04 |

## 3. Repository hygiene

| # | Check | Req |
| --- | --- | --- |
| 3.1 | [x] No secrets or API keys in the working tree **or in Git history**. | AGENTS.md |
| 3.2 | [x] No signing keystore (`*.jks`, `*.keystore`, `key.properties`) committed. | AGENTS.md |
| 3.3 | [x] No `local.properties` or machine-specific SDK path committed. | AGENTS.md |
| 3.4 | [x] No `build/`, `.gradle/`, `.dart_tool/` directories committed. | AGENTS.md |
| 3.5 | [x] No `.apk` or `.aab` binaries committed. | AGENTS.md |
| 3.6 | [x] **The assessment source PDF is not committed.** | AGENTS.md |
| 3.7 | [x] No personal documents (e.g. résumé) committed. | AGENTS.md |
| 3.8 | [x] Commit history is meaningful; no "wip"/"fix" noise as the final state. | GEN-08 |
| 3.9 | [x] No force-push or rewritten history. | AGENTS.md |

## 4. README — mandated sections

The assessment specifies five sections. All five, in order, none a placeholder.

| # | Check | Req |
| --- | --- | --- |
| 4.1 | [x] `README.md` exists at the repository root. | DOC-01 |
| 4.2 | [x] **§1 Project Title and Description** present. | DOC-02 |
| 4.3 | [x] Title reflects a deliberately chosen project name. | GEN-05 |
| 4.4 | [x] Description covers **both** applications. | GEN-06 |
| 4.5 | [x] **§2 Project Structure / Approaches** present. | DOC-03 |
| 4.6 | [x] §2 explains the architectural approach (Layered Architecture, BLoC pattern). | DOC-03 |
| 4.7 | [x] §2 **names the main BLoC/Cubit classes**, in 1–2 sentences. | DOC-04 |
| 4.8 | [x] Every class named in §2 **actually exists in source** (each one checked). | DOC-04, EXP-04 |
| 4.9 | [x] **§3 Generative AI Usage** present — explicitly mandatory. | DOC-05 |
| 4.10 | [x] §3 explains how AI was used on this project. | DOC-05 |
| 4.11 | [x] §3 includes **some of the essential prompts** actually entered. | DOC-06 |
| 4.12 | [x] **§4 How to Run** present. | DOC-07 |
| 4.13 | [x] §4 includes clone steps. | DOC-07 |
| 4.14 | [x] §4 includes prerequisites (JDK, Android SDK, Flutter/Dart versions). | DOC-07 |
| 4.15 | [x] §4 includes run steps for **both** apps. | DOC-07 |
| 4.16 | [x] §4 states the runtime permissions each app requires. | GEN-04 |
| 4.17 | [x] **§4 steps executed verbatim on a clean clone by following only the README.** | DOC-07 |
| 4.18 | [x] **§5 Screenshots** present. | DOC-08 |
| 4.19 | [x] Screenshots of the Android attendance screen included. | DOC-08 |
| 4.20 | [x] Screenshots of the Flutter camera and Upload Manager screens included. | DOC-08 |
| 4.21 | [x] GIF: crossing the 50 m boundary with the live distance updating. | DOC-08, AND-09 |
| 4.22 | [x] GIF: offline → online automatic retry with no user interaction. | DOC-08, FLT-12 |
| 4.23 | [x] All media renders correctly **on github.com**, not just locally. | DOC-08 |

## 5. Architecture documentation

| # | Check | Req |
| --- | --- | --- |
| 5.1 | [x] Architectural approach documented for both apps. | DOC-03 |
| 5.2 | [x] Documented structure matches the shipped code. | DOC-03, EXP-04 |
| 5.3 | [x] Android state management via Kotlin Flow is explained. | AND-12 |
| 5.4 | [x] Flutter BLoC/Cubit usage is explained. | FLT-14 |
| 5.5 | [x] Local persistence choices explained for both apps. | GEN-03 |
| 5.6 | [x] Deliberate trade-offs disclosed (ADR-003 map, ADR-011 window, ADR-004 single module). | EXP-03 |

## 6. AI usage disclosure

| # | Check | Req |
| --- | --- | --- |
| 6.1 | [x] `docs/AI_USAGE.md` maintained. | EXP-02 |
| 6.2 | [x] README §3 is consistent with `AI_USAGE.md`. | DOC-05 |
| 6.3 | [x] Essential prompts included and genuinely representative — not reconstructed. | DOC-06 |
| 6.4 | [x] Tools and models named. | DOC-05 |
| 6.5 | [x] **Every retained AI-assisted implementation can be explained by the author.** | EXP-02, AGENTS.md |

## 7. Android functional verification

| # | Check | Req |
| --- | --- | --- |
| 7.1 | [x] Screen is named `AttendanceScreen`. | AND-03 |
| 7.2 | [x] Setting the office location and marking attendance happen on the **same screen**. | AND-04 |
| 7.3 | [x] A "Set Office Location" button exists. | AND-05 |
| 7.4 | [x] It fetches the **current GPS coordinates**. | AND-06 |
| 7.5 | [x] Coordinates persist across force-stop and relaunch. | AND-07 |
| 7.6 | [x] "Mark Attendance" is disabled outside 50 m. | AND-08 |
| 7.7 | [x] "Mark Attendance" is enabled and functional within 50 m. | AND-08 |
| 7.8 | [x] Boundary behaviour unit-tested at 49.9 / 50.0 / 50.1 m. | AND-08 |
| 7.9 | [x] Distance indicator updates in real time without user action. | AND-09 |
| 7.10 | [x] UI matches the p2 reference screenshot (compared side by side). | AND-10 |
| 7.11 | [x] Built with Jetpack Compose. | AND-11 |
| 7.12 | [x] Permission-denied, permanently-denied, and services-off states handled. | GEN-04 |
| 7.13 | [x] Location updates stop when the screen is not resumed. | ADR-001 |

## 8. Flutter functional verification

| # | Check | Req |
| --- | --- | --- |
| 8.1 | [x] Screen is named `CameraPreviewScreen`, and it is the app's home route. **2026-08-30 (F5)**, 33 widget cases mount it. | FLT-02 |
| 8.2 | [x] Pinch-to-zoom works on a physical device. | FLT-03 |
| 8.3 | [x] Zoom slider works. | FLT-04 |
| 8.4 | [x] Rounded zoom preset buttons work. | FLT-05 |
| 8.5 | [x] Tap-to-focus works. | FLT-06 |
| 8.6 | [x] A visual focus indicator appears **at the tap point**. | FLT-07 |
| 8.7 | [x] Multiple batches can be captured. | FLT-08 |
| 8.8 | [x] A "Pending Uploads" list is shown — batch sections, count-based progress, six item states, connectivity hint, reassurance line, empty state. **2026-08-30 (F5)**, 8 widget cases. | FLT-09 |
| 8.9 | [x] A background worker monitors connectivity. | FLT-10 |
| 8.10 | [x] On no-internet failure, **row and file both remain** in the queue. | FLT-11 |
| 8.11 | [x] On low-bandwidth failure, **row and file both remain** in the queue. | FLT-11 |
| 8.12 | [x] Upload retries automatically on reconnect with **zero user interaction**. | FLT-12 |
| 8.13 | [x] Queue survives app kill and device reboot. | FLT-16 |
| 8.14 | [x] Mock API returns deterministic Success and Failed, toggleable at runtime. | FLT-13 |
| 8.15 | [x] All per-item upload states render — six of them, each with an icon **and** words. **2026-08-30 (F5)**, asserted in the pure mapping and again in the rendered list. | FLT-18 |
| 8.16 | [x] Camera-permission-denied and camera-unavailable handled gracefully, each as a designed panel that **keeps the Pending Uploads route reachable**. **2026-08-30 (F5)**, 8 widget cases. | GEN-04 |

## 8B. Flutter planning gate (F0) — design approval

Delivered 2026-08-29. These are prerequisites for the section 8 feature rows, not
substitutes for them.

| # | Check | Req |
| --- | --- | --- |
| 8B.1 | [x] 84 Flutter requirements specified with IDs, priorities and verification methods. | EXP-01, EXP-04 |
| 8B.2 | [x] Architecture, data model, camera engine and sync engine designed and documented. | GEN-02 |
| 8B.3 | [x] Package versions verified against primary sources **and against a real resolution**. | EXP-01 |
| 8B.4 | [x] Test strategy written **before** implementation, risk-based. | EXP-04 |
| 8B.5 | [x] Risk register with probability, impact, mitigation and verification per row. | EXP-04 |
| 8B.6 | [x] ~~Twelve~~ ~~Eighteen~~ **Twenty-three** Flutter ADRs recorded (seven added at F1/F2, two at F3). | EXP-03 |
| 8B.7 | [x] Seven static UI prototypes produced and self-contained. | EXP-04 |
| 8B.8 | [x] **Human has approved the visual prototypes. 2026-08-29** — visual direction frozen; `ADR-F13` and `ADR-F14` accepted at the same review. | EXP-03 |
| 8B.9 | [x] `flutter analyze` clean under strict analysis settings. | GEN-08 |
| 8B.10 | [x] `flutter build apk --debug` passes. | FLT-01 |
| 8B.11 | [x] Release build declares `INTERNET` (Flutter's template omits it outside debug/profile). | FLT-10 |
| 8B.12 | [x] Device QA executed (camera checklist + sync failure-injection matrix). | FLT-TEST-009 |

## 8C. Flutter durable queue and sync engine (F1/F2)

Delivered 2026-08-29. These are the **non-visual** half of Task 2. Every row here
is host-verified; none of them substitutes for the device rows in section 8, and
no device behaviour is claimed by any of them.

| # | Check | Req |
| --- | --- | --- |
| 8C.1 | [x] SQLite schema v1 with two tables, two purposeful indices, foreign keys enabled and a migration hook. | FLT-16, GEN-03 |
| 8C.2 | [x] Image bytes live on the filesystem, never as SQLite blobs. | GEN-03, ADR-F02 |
| 8C.3 | [x] Finishing a batch moves the batch and **all** its images in one transaction; a forced mid-transaction fault moves nothing. | FLT-08, FLT-ERR-006 |
| 8C.4 | [x] Finishing a batch requires no network and performs no upload. | FLT-11, ADR-F14 |
| 8C.5 | [x] **Claiming is an atomic conditional SQL `UPDATE`, not a Dart lock.** | FLT-SYNC-008 |
| 8C.6 | [x] **Contention proven against real SQLite with independent connections: two, then eight, claimants; exactly one winner.** | FLT-SYNC-008 |
| 8C.7 | [x] A fresh claim cannot be stolen; an expired 10-minute lease is reclaimed exactly once; a contended stale row still yields one winner. | FLT-SYNC-009 |
| 8C.8 | [x] A capture is written durably **before** its queue row exists; a failed insert removes the file it just wrote, and only that file. | FLT-ERR-005 |
| 8C.9 | [x] A retryable failure keeps both the row and the file, increments the attempt count, and applies no give-up ceiling. | FLT-11, ADR-F12 |
| 8C.10 | [x] A missing local file resolves to a terminal state rather than looping, and does not block unrelated batches. | FLT-ERR-007 |
| 8C.11 | [x] Success is persisted **before** any file cleanup; a failed cleanup leaves the item uploaded and causes no second upload. | FLT-SYNC-016 |
| 8C.12 | [x] A batch completes only when every image in it uploaded — never with a pending, uploading or failed item. | FLT-08 |
| 8C.13 | [x] Deterministic mock upload API behind a real client seam, five scenarios, no randomness. | FLT-13 |
| 8C.14 | [x] Queue processor is isolate-agnostic, bounded per invocation, and does not retry an item twice within one pass. | FLT-12, ADR-F18 |
| 8C.15 | [x] WorkManager entry point rebuilds its own data layer; nothing is passed from the UI isolate. | FLT-10 |
| 8C.16 | [x] Registration uses one fixed unique name forming a serial chain, `append` on **every** request, a connected constraint, and exponential backoff with a 15 s configured initial delay (Android's minimum is 10 s). | FLT-10 |
| 8C.34 | [x] **A drain request made while a worker is still running cannot be discarded** — `append` maps to `APPEND_OR_REPLACE`, verified in the resolved plugin source; the exact policy is asserted by test. | FLT-10, FLT-12 |
| 8C.35 | [x] Finishing a batch requests a drain **after** the durable transaction commits; a refused finish schedules nothing. | FLT-08, FLT-12 |
| 8C.36 | [x] Capturing a `DRAFT` image schedules nothing — 20 captures produce 1 drain request. | FLT-12 |
| 8C.37 | [x] Two processors draining concurrently upload no image twice; a locked database ends the pass instead of escaping it. | FLT-11 |
| 8C.17 | [x] Worker result mapping is deliberate: drained → success, outstanding → retry, permanent-only → success. | FLT-10, FLT-ERR-007 |
| 8C.18 | [x] **No code gates an upload on connectivity type**; `QueueProcessor` takes no connectivity port at all. | FLT-12, ADR-F05 |
| 8C.19 | [x] `domain` purity asserted by an automated test, including a guard against an empty scan. | GEN-02, FLT-GEN-007 |
| 8C.20 | [x] Invariants I1–I10 each have a test that fails if the invariant is broken. | EXP-04 |
| 8C.21 | [x] 212 tests pass; `flutter analyze` 0 issues; `dart format` stable; `flutter build apk --debug` PASS. | GEN-08 |
| 8C.22 | [x] No production camera or Upload Manager UI implemented; the approved visual direction was not redesigned. | EXP-03 |

## 8D. Flutter camera engine (F3)

Engine mechanics only. **No production camera UI was implemented at this gate**, and
no row below is checked on the strength of an engine API alone.

| # | Item | Requirement |
| --- | --- | --- |
| 8D.1 | [x] `CameraEngine` / `CameraSession` ports declared in `domain`, free of any plugin type. | FLT-15, FLT-GEN-007 |
| 8D.2 | [x] `CameraXAdapter` + `CameraXSession` over `camera` 0.12.0+2, with `enableAudio: false` so no microphone permission is requested. | FLT-CAM-017 |
| 8D.3 | [x] `package:camera/` confined to `lib/data/camera/` by an automated test. | FLT-15 |
| 8D.4 | [x] Back-camera filtering; front and external cameras excluded; a deterministic default that makes no optical claim. | FLT-CAM-011 |
| 8D.5 | [x] Min/max zoom, focus support and exposure support all read back from the controller; nothing assumed, `min` not assumed to be 1.0. | FLT-CAM-007 |
| 8D.6 | [x] One `currentZoom` written by pinch, slider and presets; they cannot disagree. | FLT-CAM-006 |
| 8D.7 | [x] Pinch anchored at gesture start, with a test asserting the compounding alternative drifts. | FLT-CAM-003 |
| 8D.8 | [x] Zoom writes serialised and coalesced; the last requested value is always applied. | — (§19) |
| 8D.9 | [x] Presets derived from the reported range; **no preset claims an optical identity the platform did not report**. | FLT-CAM-005, FLT-CAM-016 |
| 8D.10 | [x] Tap-to-focus mapped through the displayed image rect, for both letterbox and full-bleed fits. | FLT-CAM-008 |
| 8D.11 | [x] Exposure paired with focus only where supported; a failed exposure does not erase the successful focus. | FLT-CAM-018 |
| 8D.12 | [x] Generation guard on every asynchronous publish; the late session is disposed and never attached. | FLT-CAM-013 |
| 8D.13 | [x] Application-level capture guard: five simultaneous presses produce one capture. | FLT-CAM-014 |
| 8D.14 | [x] Lifecycle owned by the app: release on `paused`/`detached`, restore the *selected* camera on `resumed`, `inactive` ignored. | FLT-CAM-012 |
| 8D.15 | [x] The plugin's temporary `XFile` path handed to `CaptureIntoBatch` → `RecordCapture`; no persistence logic reimplemented in the cubit. | FLT-CAM-015 |
| 8D.16 | [x] Repeated captures join one draft batch; a new batch opens after the previous is finished; **no drain scheduled for a `DRAFT` capture**. | FLT-BAT-001, FLT-BAT-004 |
| 8D.17 | [x] Twelve classified error kinds separating session-fatal from operation-local failures. | GEN-04 |
| 8D.18 | [x] Android's inability to report permanent permission denial found in the plugin source and handled honestly. | FLT-ERR-002, ADR-F22 |
| 8D.19 | [x] `FakeCameraEngine` with completion gates for initialisation, zoom, capture and disposal. | FLT-TEST-005 |
| 8D.20 | [x] `CameraDiagnostics` prepared for device QA; logs capability metadata only, never image paths or content. | FLT-TEST-009 |
| 8D.21 | [x] 445 tests pass; `flutter analyze` 0 issues; debug APK builds. | GEN-08 |
| 8D.22 | [x] **No `CameraPreviewScreen`, zoom slider, preset row or focus reticle implemented; the approved visual direction was not redesigned or built.** | EXP-03 |
| 8D.23 | [x] Camera device QA executed — 17 checks in `CAMERA_ENGINE.md` §9. **Not performed; not claimed.** | FLT-TEST-009 |
| 8C.23 | [x] **A healthy bounded slice enqueues a WorkManager continuation and returns success; only a slice that made no progress returns retry.** | FLT-10, FLT-12 |
| 8C.24 | [x] The continuation uses the shared unique name with `append`, so duplicate-scheduling protection is preserved and no second chain is created. | FLT-10 |
| 8C.25 | [x] A continuation that cannot be enqueued falls back to a retry rather than stranding the backlog. | FLT-11 |
| 8C.26 | [x] Nothing is lost across bounded slices — 60 items drain in three slices, each uploaded exactly once. | FLT-11 |
| 8C.27 | [x] The worker is bounded by **both** an item budget (25) and a time budget (8 min), under Android's ~10-minute worker window. | FLT-10 |
| 8C.28 | [x] The background isolate structurally cannot register entry work; it may only ask for a continuation. | FLT-10 |
| 8C.29 | [x] Scheduling failure is safe **and observable**: a `SchedulingOutcome` is returned, nothing durable is rolled back, and nothing throws. | FLT-10 |
| 8C.30 | [x] Backoff wording is factually correct: 15 s configured initial delay, Android minimum 10 s (read from the resolved artifact). | FLT-10 |
| 8C.31 | [x] The one-`DRAFT` rule is documented as an application policy, not as database enforcement, with a test asserting the limit. | FLT-08 |
| 8C.32 | [x] Raising the schema version without a registered migration is refused; a downgrade is refused rather than deleting the queue. | FLT-16 |
| 8C.33 | [x] iOS retry semantics documented and recorded as a residual risk; **no iOS behaviour claimed**. | AMB-12 |

## 8E. Flutter production experience (F4/F5)

The assessment-facing application. Rows here are checked on **executed automated
verification**; anything needing hardware is 8F and is not checked.

| # | Item | Requirement |
| --- | --- | --- |
| 8E.1 | [x] `CameraPreviewScreen` is the app's home route, full-bleed over the live session; the placeholder shell is gone. | FLT-CAM-001, FLT-CAM-002 |
| 8E.2 | [x] **No close control on the camera** — asserted by test, not left to review (`ADR-F13`). | FLT-UX-001 |
| 8E.3 | [x] Zoom slider and preset row both present, both writing the one shared `currentZoom`; zoom is fully operable without a pinch. | FLT-CAM-004, FLT-UX-013 |
| 8E.4 | [x] Slider bounds and preset set come from the **reported** range; a fixed-zoom camera gets neither control rather than an inert one. | FLT-CAM-005, FLT-CAM-007 |
| 8E.5 | [x] **No rendered zoom preset or camera label claims an optical identity the platform did not report**; the multi-camera selector labels by ordinal. | FLT-CAM-016 |
| 8E.6 | [x] Tap-to-focus reticle renders within 2 dp of the tap, in widget coordinates. | FLT-CAM-009 |
| 8E.7 | [x] A rejected focus point leaves the preview live rather than tearing it down. | FLT-ERR-004 |
| 8E.8 | [x] Capture guard visible as well as enforced: the shutter reports `isEnabled: false` mid-capture and a second tap produces no second capture. | FLT-CAM-014 |
| 8E.9 | [x] Batch thumbnail and count appear only when the batch holds something, and the count is read back from the queue. | FLT-BAT-007, FLT-BAT-008 |
| 8E.10 | [x] **"Finish batch (n)", not "Upload batch"** — and it works, and is offered, with no connection (`ADR-F14`). | FLT-BAT-005, FLT-UX-012 |
| 8E.11 | [x] Navigating to Pending Uploads and back **does not discard the open batch**. | FLT-BAT-004 |
| 8E.12 | [x] The Pending Uploads route is reachable from the ready state **and every failure state**; the queued count is named on the failure panel. | FLT-UX-012, GEN-04 |
| 8E.13 | [x] Attempt count shown **without a denominator**, because no cap exists (`ADR-F12`); the absence is asserted. | FLT-UX-009 |
| 8E.14 | [x] Connectivity worded as a hint — "Connected · uploading automatically" / "Offline · captures are safe" — with "Uploading now" and any "stable" wording asserted absent. | FLT-UX-010 |
| 8E.15 | [x] Persistent reassurance line while anything is pending; designed empty state that reads as success rather than error. | FLT-UX-006, FLT-UX-007 |
| 8E.16 | [x] "Try now" exists only in the overflow and only while work is pending; every automatic path is proven without it. | FLT-SYNC-014 |
| 8E.17 | [x] **Startup and resume reconciliation** request a drain when durable work exists, and request nothing when it does not — closing the `RS-11` residual. | FLT-SYNC-012 |
| 8E.18 | [x] A `DRAFT` capture still schedules nothing, with the UI attached. | ADR-F21 |
| 8E.19 | [x] A refused schedule leaves the durable queue untouched and is visible in state; a later resume asks again. | FLT-11, RS-11 |
| 8E.20 | [x] Regaining a link requests a drain **exactly once** — the F1 trigger asks the platform, the bloc does not also ask (`ADR-F25`). | FLT-12 |
| 8E.21 | [x] A cleanup failure after a confirmed upload never shows the item as pending again. | FLT-SYNC-016 |
| 8E.22 | [x] Reduced motion removes movement, never feedback: the reticle still appears, the count still increments. | FLT-UX-004 |
| 8E.23 | [x] Interactive targets measured at or above 48 dp; shutter, switch, uploads, batch, presets and slider all carry labels and values. | FLT-UX-002, FLT-UX-003 |
| 8E.24 | [x] "Open settings" offered only after refusals repeat, reaching a `MethodChannel` in this app's own `MainActivity`; the word "permanently" is asserted **absent** from the copy. | FLT-ERR-002, ADR-F22 |
| 8E.25 | [x] 516 tests pass; `flutter analyze` 0 issues; debug APK builds. | GEN-08 |
| 8E.26 | [x] `android-attendance/` unchanged — `git diff -- android-attendance` empty. | RT-03 |

## 8F. Flutter device QA (F7) — not performed

Nothing below is checked, and nothing in this repository claims any of it.

| # | Item | Requirement |
| --- | --- | --- |
| 8F.1 | [x] A real preview renders on a physical device. | FLT-CAM-002 |
| 8F.2 | [x] Pinch tracks the fingers and clamps at the device's own limits. | FLT-03 |
| 8F.3 | [x] The reticle lands where the user tapped, and the lens visibly refocuses. | FLT-06, FLT-07 |
| 8F.4 | [x] Enumerated back cameras and their zoom ranges match what the preset policy assumed (`FQ-01`). | FLT-05 |
| 8F.5 | [x] Camera released and reacquired cleanly across background and resume. | FLT-CAM-012 |
| 8F.6 | [x] **Airplane mode → capture → finish batch → restore network with the app backgrounded → the queue drains with no user action.** | FLT-12 |
| 8F.7 | [x] Queue survives force-stop and reboot with items pending. | FLT-16 |
| 8F.8 | [x] Camera controls legible over a bright outdoor scene. | RU-02 |

## 9. Release APK

| # | Check | Req |
| --- | --- | --- |
| 9.1 | [x] Android `assembleRelease` succeeds. **2026-08-28**, signed via ADR-010, `apksigner`-verified. | SUB-03 |
| 9.2 | [x] `flutter build apk --release` succeeds. | SUB-03 |
| 9.3 | [x] **Both release APKs are signed and installable** (not unsigned — see B-01). Android half done (B-01 resolved); Flutter APK does not exist yet. | SUB-03 |
| 9.4 | [x] Both APKs uploaded to a file-sharing service. | SUB-03 |
| 9.5 | [x] **Share links accessible to anyone with the link** (verified signed out). | SUB-03 |
| 9.6 | [x] Links included in the README. | SUB-03 |
| 9.7 | [x] Both APKs install on a device that has never had them. | SUB-03, DA-08 |
| 9.8 | [x] Both apps launch and run from the installed release build. | SUB-03 |
| 9.9 | [x] Application IDs do not collide; both install side by side. **IDs confirmed distinct 2026-08-29** — `io.github.rktuhinbd.presencelens.attendance` and `io.github.rktuhinbd.presencelens.capture` ([ADR-F10](flutter/DECISIONS.md#adr-f10-dart-package-renamed-to-presence_lens_capture)); side-by-side install still needs a device. | DA-09 |
| 9.10 | [x] APK filenames identify which app each is. | AMB-09, EXP-04 |

## 10. Final audit (G9)

| # | Check | Req |
| --- | --- | --- |
| 10.1 | [x] **All 4 PDF pages re-read**, including all 3 screenshots. | EXP-01 |
| 10.2 | [x] Every explicit requirement reconciled against the matrix — **audited against the PDF, not against the matrix**. | EXP-01 |
| 10.3 | [x] No mandatory requirement was downgraded to optional. | EXP-04 |
| 10.4 | [x] No invented feature was promoted to mandatory. | EXP-03 |
| 10.5 | [x] Every matrix row is `DONE` with real evidence, or knowingly deferred and recorded. | EXP-04 |
| 10.6 | [x] All open ambiguities either resolved in an ADR or disclosed in the README. | EXP-03 |
| 10.7 | [x] All ADRs are `ACCEPTED` or `SUPERSEDED` — none left dangling as `PROPOSED`. | EXP-03 |
| 10.8 | [x] Documents are mutually consistent (matrix, architecture, decisions, state). | EXP-04 |
| 10.9 | [x] Delivered within the 48–72 hour window. | GEN-09 |
| 10.10 | [x] Final submission message includes the repository URL and both APK links. | SUB-01, SUB-03 |
