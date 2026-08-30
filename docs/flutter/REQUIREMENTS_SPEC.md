# Flutter Task — Requirements Specification

Atomic, uniquely identified, verifiable requirements for Task 2 (Advanced Camera
& Sync Engine).

**What this document is for:** it is the checklist the implementation is built
against and the submission is audited against. If a behaviour is not written
here, it is not in scope; if it is here and unverified, the task is not done.

Structured on the principles of ISO/IEC/IEEE 29148:2018 — each requirement is
atomic, uniquely identified, unambiguous, verifiable and traceable. *This is an
application of those principles, not a claim of certification or formal
compliance.*

Source authority is the assessment PDF (`../_source/assessment.pdf`). Rows
derived from the p3 screenshots are marked `[screenshot]` and are **advisory**:
the PDF labels them *"Suggested UI:"*, unlike the prescriptive Android p2
reference. See root [REQUIREMENTS_MATRIX.md](../REQUIREMENTS_MATRIX.md).

---

## Priority vocabulary

| Priority | Meaning |
| --- | --- |
| **MANDATORY** | Stated in, or directly entailed by, the assessment text. Non-delivery is a failed submission. |
| **QUALITY** | Not spelled out, but required for the mandatory behaviour to be trustworthy — process-death safety, concurrency defence, lifecycle correctness. A senior reviewer will look for these. |
| **BONUS** | Genuinely optional. Accepted only where it costs little and demonstrates judgement. Never allowed to delay or destabilise a MANDATORY row. |

## Status vocabulary

Identical to the root matrix. `TODO` / `PARTIAL` / `DONE` / `BLOCKED`. Nothing is
`DONE` until its own verification method has been executed and its evidence
recorded.

**Status as of gate F3 (2026-08-30).** The camera engine is implemented and
host-verified: camera enumeration and back-camera filtering, a generation-guarded
controller lifecycle, safe switching, one shared zoom value with a coalescing
platform pump, tap-to-focus coordinate mapping for both preview fits, an optional
exposure pairing, an application-level capture guard, and the handoff of the
plugin's temporary `XFile` into the F1 durable pipeline. **445 tests pass**
(229 at F1, +216 this gate), `flutter analyze` reports no issues, and the debug APK
builds. Two new ADRs record what the implementation forced: `ADR-F22` (Android
cannot report permanent permission denial) and `ADR-F23` (the preview seam and both
preview fits). **No production camera UI exists** — `CameraPreviewScreen`, the
reticle and the zoom controls are gate F5, and no row is marked `DONE` on the
strength of an engine API alone.

**Status as of gate F1 (2026-08-29).** The durable queue, the sync engine and the
background-worker plumbing are implemented and verified on the host: 188 tests
pass, `flutter analyze` reports no issues, and the debug APK builds. A row is
`DONE` only where its *own* stated method has actually been executed — so rows
whose method includes `DEVICE` are `PARTIAL` however complete the code is, and no
statement anywhere in this document claims physical background-worker behaviour
from a JVM test run. The camera, batch-UI and presentation rows are untouched:
they are gates F3–F5.

## Verification method vocabulary

| Code | Meaning |
| --- | --- |
| `UNIT` | Pure-Dart test, no Flutter binding, no device. |
| `DATA` | Test against the real SQLite engine via `sqflite_common_ffi` on the host. |
| `BLOC` | Cubit/Bloc state-transition test (`bloc_test`). |
| `WIDGET` | `flutter_test` widget test, including semantics assertions. |
| `BUILD` | Established by a successful build or static analysis. |
| `REVIEW` | Code or structure review against a stated, checkable criterion. |
| `DEVICE` | Requires a physical device or emulator. Deferred to hardware QA. |
| `DOC` | Verified by inspecting a delivered document or artefact. |

---

## FLT-GEN — General engineering

| ID | Requirement | Source | Priority | Component | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- |
| FLT-GEN-001 | Flutter state management shall use BLoC/Cubit. | p1 GR-1 | MANDATORY | `presentation/**/cubit` | `BLOC`, `REVIEW` | PARTIAL — `CameraCubit` implemented with 109 `BLOC` tests across six suites; `BatchCubit`/`SyncBloc` are gates F4/F5. |
| FLT-GEN-002 | The app shall use a layered architecture with unidirectional data flow. | p1 GR-2 | MANDATORY | whole app | `REVIEW` (import-direction check) | **DONE** — `presentation`/`domain`/`data` in place for the data and sync half; the import-direction rule is asserted by `domain_purity_test` (5 cases), not by inspection. |
| FLT-GEN-003 | The app shall persist data locally following best practice. | p1 GR-3 | MANDATORY | `data/local` | `DATA`, `DEVICE` | PARTIAL — `DATA` **executed**: schema, transactions, reopen-and-survive, 58 DAO/schema tests pass against real SQLite. `DEVICE` kill-and-relaunch outstanding. |
| FLT-GEN-004 | The app shall handle permission and hardware failures gracefully. | p1 GR-4 | MANDATORY | `CameraCubit`, `CameraAdapter` | `BLOC`, `WIDGET`, `DEVICE` | PARTIAL — every permission and hardware failure state is implemented, classified and `BLOC`-driven (enumeration throw, no cameras, no back camera, refusal, restricted, init failure, capture/focus/zoom failure). `WIDGET` needs the F5 screen; `DEVICE` outstanding. |
| FLT-GEN-005 | Task 2 shall be implemented in Flutter. | p2 heading | MANDATORY | project | `BUILD` | PARTIAL — `flutter build apk --debug` **PASS** with the camera engine compiled in. Held short of `DONE` until the camera *screen* builds (F5). |
| FLT-GEN-006 | No business rule shall be evaluated inside a widget; widgets render state and emit intent only. | derived from GR-1/GR-2 | QUALITY | `presentation` | `REVIEW` | PARTIAL — no widget exists yet to violate it; every camera rule lives in a pure policy or the cubit. Re-checked at F5. |
| FLT-GEN-007 | The `domain` layer shall import no Flutter plugin package (`camera`, `sqflite`, `workmanager`, `connectivity_plus`, `path_provider`). | derived from GR-2 | QUALITY | `domain` | `UNIT` (automated purity test, mirroring the Android `DomainLayerPurityTest`) | **DONE** — `domain_purity_test` scans `lib/domain`, rejects Flutter, all five plugins, `dart:io`, `dart:ui` and any `data`/`presentation` import, and fails if the scan finds no sources. |

---

## FLT-CAM — Camera

| ID | Requirement | Source | Priority | Component | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- |
| FLT-CAM-001 | A widget named exactly `CameraPreviewScreen` shall exist. | p2 Custom Camera UI | MANDATORY | `presentation/camera` | `REVIEW`, `WIDGET` | TODO |
| FLT-CAM-002 | The screen shall render a live in-app camera preview (not a system camera intent). | p2 Custom Camera UI | MANDATORY | `CameraPreviewScreen` | `DEVICE` | TODO |
| FLT-CAM-003 | Zoom shall be adjustable by pinch gesture. | p2 Zoom | MANDATORY | `CameraPreviewScreen`, `ZoomPolicy` | `UNIT` (gesture→zoom mapping), `DEVICE` | PARTIAL — `UNIT` **executed**: `ZoomPolicy.forPinch` is anchored to the gesture start, and the compounding-drift alternative is asserted to be wrong. Cubit-level pinch proven too. `DEVICE` check 6 outstanding. |
| FLT-CAM-004 | Zoom shall be adjustable by an on-screen slider. | p2 Zoom | MANDATORY | `ZoomSlider` | `WIDGET`, `DEVICE` | TODO |
| FLT-CAM-005 | Zoom shall offer rounded preset buttons derived from the device's reported capabilities. | p2 Zoom (**text truncated — root AMB-01**) | MANDATORY | `ZoomPresetPolicy` | `UNIT`, `DEVICE` | PARTIAL — `UNIT` **executed**: `ZoomPresetPolicy`, 15 cases. Presets derive from the reported range; the row is offered only when the camera can zoom. `DEVICE` checks 2–4, 8 outstanding. |
| FLT-CAM-006 | Pinch, slider and presets shall read and write one shared zoom value; no two controls may disagree. | derived from 003–005 | QUALITY | `CameraCubit` | `BLOC` | **DONE** — `BLOC` executed: pinch, slider and preset all write one `currentZoom`; a preset is visible to the next pinch and vice versa. There is one field, so they cannot disagree. |
| FLT-CAM-007 | Zoom shall be clamped to the active camera's reported min/max; no hard-coded bounds. | derived from 003–005 | QUALITY | `ZoomPolicy` | `UNIT` | **DONE** — `UNIT` executed: clamped at both ends, against a non-1.0 minimum, and with a max below the min; no bound is hard-coded and every value is read from the controller. |
| FLT-CAM-008 | Tapping the preview shall set the camera focus point. | p3 Manual Focus | MANDATORY | `CameraCubit`, `FocusPointMapper` | `UNIT` (coordinate normalisation), `DEVICE` | PARTIAL — `UNIT` **executed**: 19 mapping cases over both fits, both aspect-ratio directions, and the exact edges. `DEVICE` checks 9–10 outstanding. |
| FLT-CAM-009 | A visual indicator shall appear at the tapped point. | p3 Manual Focus | MANDATORY | `FocusReticle` | `WIDGET` (asserts position), `DEVICE` | TODO |
| FLT-CAM-010 | The focus indicator shall have a defined lifecycle: appear at the tap, show acquisition, then dismiss. | derived from 009 | QUALITY | `FocusReticle` | `WIDGET` | TODO |
| FLT-CAM-011 | The app shall enumerate cameras and present only back-facing cameras for selection. | derived from p2 "available back cameras" | MANDATORY | `CameraAdapter` | `UNIT`, `DEVICE` | PARTIAL — `UNIT` **executed**: front and external cameras filtered, front-only and empty devices produce named states, ordinals re-stamped over back cameras only. `DEVICE` check 3 outstanding. |
| FLT-CAM-012 | The app shall own the controller lifecycle: dispose on `paused`/`inactive`, reinitialise on `resumed`. | RESEARCH `FR-02`; GR-4 | MANDATORY | `CameraPreviewScreen` | `WIDGET`, `DEVICE` | PARTIAL — `BLOC` **executed**: `paused`/`detached` release, `resumed` restores the *selected* camera, `inactive` deliberately does nothing, a failed resume is recoverable, and a pre-pause initialisation cannot overwrite the resumed state. `WIDGET` observer is F5; `DEVICE` check 14 outstanding. |
| FLT-CAM-013 | Camera switching shall be race-protected: a switch begun while another is in flight shall not leave a disposed controller attached. | derived from 012 | QUALITY | `CameraCubit` | `BLOC` | **DONE** — `BLOC` executed: A→B→C ends on C however late B completes, the late session is disposed, no state is ever emitted for a superseded camera, eight rapid switches leak nothing, and a switch landing after a release does not resurrect the camera. |
| FLT-CAM-014 | A capture in flight shall block a second capture (no double-shutter). | derived from GR-4 | QUALITY | `CameraCubit` | `BLOC` | **DONE** — `BLOC` executed: two and then five simultaneous presses produce exactly **one** platform capture and one image row; the guard releases so the next press works. Owned in the app, not read off `isTakingPicture`. |
| FLT-CAM-015 | Each capture shall be copied from the plugin's temporary `XFile` into app-owned durable storage before it is considered captured. | entailed by FLT-SYNC-003 | MANDATORY | `CaptureStorage` | `DATA`, `UNIT` | PARTIAL — the camera now has a caller: `CameraSession.takePicture()` returns a temporary path which `CaptureIntoBatch` hands to `RecordCapture`. `UNIT`/`DATA` executed end to end. `DEVICE` check 12 — a *real* plugin `XFile` — outstanding. |
| FLT-CAM-016 | Preset labels shall never assert an optical multiplier the platform did not report. | RESEARCH `FR-04` | QUALITY | `ZoomPresetPolicy` | `UNIT`, `REVIEW` | **DONE** — `UNIT` + `REVIEW` executed. No preset claims an optical identity across every range tested; an unidentified camera is labelled by ordinal and its label contains no `x`; provenance is carried on every preset so the claim is checkable rather than assumed (`ADR-F03`). |
| FLT-CAM-017 | Audio capture shall be disabled, so no microphone permission is requested. | derived from scope | QUALITY | `CameraAdapter` | `REVIEW` | **DONE** — `REVIEW`: `enableAudio: false` at the single controller construction site, so no microphone permission is ever requested. |
| FLT-CAM-018 | Tap-to-focus shall also set the exposure point where the platform supports it. | — | BONUS | `CameraAdapter` | `DEVICE` | PARTIAL — implemented and `BLOC`-tested: exposure is paired only where the platform reports support, and a failed exposure does **not** erase the successful focus. `DEVICE` check 5 outstanding. |

---

## FLT-BAT — Batch management

| ID | Requirement | Source | Priority | Component | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- |
| FLT-BAT-001 | The user shall be able to capture multiple images into one batch. | p3 Batch Management | MANDATORY | `BatchCubit` | `BLOC`, `DATA` | PARTIAL — `BLOC` + `DATA` **executed**: repeated captures join one draft batch and the count is read back from the database. The batch *UI* is gate F4. |
| FLT-BAT-002 | The app shall support multiple batches. | p3 Batch Management | MANDATORY | `BatchRepository` | `DATA` | **DONE** — multiple independent batches persist, list and drain separately; ordering across them is deterministic. |
| FLT-BAT-003 | The app shall show a list of "Pending Uploads". | p3 Batch Management | MANDATORY | `UploadManagerScreen` | `WIDGET`, `DEVICE` | TODO |
| FLT-BAT-004 | A batch's open/close rule shall be explicit: a batch opens on the first capture after the previous batch was enqueued, and closes when the user enqueues it. | root AMB-10 | QUALITY | `BatchPolicy` | `UNIT`, `DOC` | PARTIAL — both halves now execute: `CaptureIntoBatch` opens the batch on the first capture and a new one after the previous is finished. The user-facing finish control is F4. |
| FLT-BAT-005 | Enqueuing a batch shall transition every image in it to `pending` in one transaction. | derived from FLT-SYNC-001 | QUALITY | `BatchRepository` | `DATA` | **DONE** — one transaction moves batch and every image together; a forced mid-transaction failure moves nothing. |
| FLT-BAT-006 | Enqueuing an empty batch shall be refused. | derived from 005 | QUALITY | `BatchPolicy` | `UNIT` | **DONE** — refused by `BatchPolicy` and by the DAO; the batch stays `DRAFT`. |
| FLT-BAT-007 | `[screenshot]` The camera screen shall show the current batch's image count. | p3 left | QUALITY | `CameraPreviewScreen` | `WIDGET` | TODO |
| FLT-BAT-008 | `[screenshot]` The camera screen shall show a thumbnail of the most recent capture. | p3 left | BONUS | `CameraPreviewScreen` | `WIDGET` | TODO |

---

## FLT-SYNC — Resilient sync engine

| ID | Requirement | Source | Priority | Component | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- |
| FLT-SYNC-001 | Queued images and their metadata shall be held in a persistent local queue that survives process death. | p3 Resilient Sync Engine | MANDATORY | `UploadQueueDao`, `CaptureStorage` | `DATA`, `DEVICE` | PARTIAL — `DATA` **executed**: the queue survives a close-and-reopen with its schema version and rows intact. `DEVICE` process-death check outstanding. |
| FLT-SYNC-002 | A background worker (`workmanager`) shall drain the queue. | p3 Resilient Sync Engine (names `workmanager`) | MANDATORY | `SyncWorker` | `DEVICE` | PARTIAL — `WorkManagerSyncScheduler`, the `vm:entry-point` dispatcher and the isolate-local composition root are implemented; the finish/continue/retry mapping is host-tested, including that a healthy bounded slice enqueues a continuation rather than reporting failure (`ADR-F19`). **Whether Android actually runs it is `DEVICE` and is not claimed.** |
| FLT-SYNC-003 | When an upload fails from low bandwidth or no internet, the image file **and** its queue row shall both remain. | p3 Resilient Sync Engine | MANDATORY | `QueueProcessor` | `UNIT`, `DATA` | **DONE** — `UNIT` + `DATA` executed. A retryable failure returns the row to `PENDING`, increments the attempt count, and leaves both row and file untouched; seven consecutive failures discard nothing. |
| FLT-SYNC-004 | Upload shall retry automatically once a usable connection exists, with no user intervention. | p3 Resilient Sync Engine | MANDATORY | `SyncScheduler`, `SyncWorker` | `UNIT`, `DEVICE` | PARTIAL — `UNIT` **executed**: fail-then-succeed proven end to end through the processor and across two worker invocations, with no user action in the path. `DEVICE` airplane-mode run outstanding. |
| FLT-SYNC-005 | The API shall be a real client seam with a deterministic mock returning Success and Failed. | p3 Note | MANDATORY | `UploadApi`, `MockUploadApi` | `UNIT` | **DONE** — `UploadApi` seam with `MockUploadApi`; five deterministic scenarios, 12 tests, no randomness. |
| FLT-SYNC-006 | Failures shall be classified as retryable or permanent; only retryable failures re-queue. | derived from 003/004 | QUALITY | `FailureClassifier` | `UNIT` | **DONE** — `FailureClassifier`, pure; every category has a verdict and unknown faults fail open toward retrying. |
| FLT-SYNC-007 | Retry timing shall use WorkManager's exponential backoff rather than an app-side timer. | RESEARCH `FR-06` | QUALITY | `SyncScheduler` | `REVIEW`, `DEVICE` | PARTIAL — `REVIEW` **PASS**: no app-side timer exists, the worker cannot register entry work (`BackgroundSyncScheduler`), and the registered policy — exponential, 15 s configured initial delay, above Android's 10 s minimum — is asserted by test. A healthy bounded slice now asks for a *continuation* rather than a retry, so backoff is reserved for actual failure (`ADR-F19`). `DEVICE` timing outstanding. |
| FLT-SYNC-008 | Two workers shall not upload the same item concurrently. Exclusion shall be enforced in the database, not by an in-process lock. | RESEARCH `FR-08` | QUALITY | `UploadQueueDao.claim` | `DATA` | **DONE** — atomic conditional `UPDATE`; two and then eight *independent database connections* race one row and exactly one wins, including on a stale lease. See `TEST_STRATEGY.md` §11 for what this does and does not prove. |
| FLT-SYNC-009 | An item left `uploading` by process death shall be reclaimed automatically after a defined lease period. | derived from 001/008 | QUALITY | `StaleClaimPolicy` | `UNIT`, `DATA` | **DONE** — 10-minute lease folded into the claim query. A fresh claim cannot be stolen; an expired one is reclaimed exactly once; a contended stale row still yields one winner. |
| FLT-SYNC-010 | Marking an item or batch uploaded shall be idempotent; a repeat shall not corrupt state or double-count. | derived from 008 | QUALITY | `UploadQueueDao` | `DATA` | **DONE** — success is guarded on `UPLOADING`; a repeat affects zero rows, does not re-complete the batch, and cannot overwrite a terminal row. |
| FLT-SYNC-011 | Connectivity type shall never be treated as proof of reachability; the upload outcome is authoritative. | RESEARCH `FR-05`; root AMB-15 | QUALITY | `SyncScheduler` | `REVIEW`, `UNIT` | **DONE** — `QueueProcessor` takes no `ConnectivityPort`, so it structurally cannot gate on link state; connectivity appears only as a scheduling constraint and an opportunistic trigger. |
| FLT-SYNC-012 | Pending work shall be reconciled and rescheduled when the app returns to the foreground. | derived from 004 | QUALITY | `SyncCubit` | `BLOC` | TODO |
| FLT-SYNC-013 | Items shall be processed in a deterministic order (oldest queued first) across multiple batches. | derived from FLT-BAT-002 | QUALITY | `UploadQueueDao` | `DATA` | **DONE** — `ORDER BY captured_at ASC, id ASC`; asserted across two interleaved batches. |
| FLT-SYNC-014 | Any manual retry affordance shall be an accelerator only; automatic recovery shall never depend on it. | p3 "without user intervention" | MANDATORY | `UploadManagerScreen` | `REVIEW`, `WIDGET` | TODO |
| FLT-SYNC-015 | The release build shall hold the `INTERNET` permission. | derived from 002 | MANDATORY | `AndroidManifest.xml` | `BUILD`, `REVIEW` | **DONE** — declared in the `main` manifest this gate; Flutter's generated project declares it only for debug/profile. |
| FLT-SYNC-016 | A confirmed-uploaded image's file shall be deleted, and its row retained as history. | — | BONUS | `RetentionPolicy` | `UNIT`, `DATA` | PARTIAL — `RetentionPolicy` implemented and tested, including that a failed deletion leaves the item `UPLOADED` and causes no second upload. **Disabled by default** pending the F6 thumbnail decision (`ADR-F16`). |

---

## FLT-ERR — Failure handling

Every row here is an instance of the mandatory `FLT-GEN-004`.

| ID | Requirement | Source | Priority | Component | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- |
| FLT-ERR-001 | Camera permission denial shall produce an explanatory state with a retry action, not a crash or blank preview. | GR-4 | MANDATORY | `CameraCubit` | `BLOC`, `WIDGET` | PARTIAL — `BLOC` **executed**: a refusal produces `CameraPermissionDenied` with a working retry, never a crash or blank preview. `WIDGET` needs the F5 screen. |
| FLT-ERR-002 | Permanent denial shall route the user to the OS app settings. | GR-4 | MANDATORY | `CameraPreviewScreen` | `DEVICE` | TODO |
| FLT-ERR-003 | A device reporting no usable camera shall produce a named state, not an exception. | GR-4 | MANDATORY | `CameraCubit` | `BLOC` | **DONE** — `BLOC` executed: no cameras and no *back* camera produce two distinct named states, and neither throws. |
| FLT-ERR-004 | Camera initialisation failure shall be recoverable without leaving the screen. | GR-4 | MANDATORY | `CameraCubit` | `BLOC` | **DONE** — `BLOC` executed: an initialisation failure becomes `CameraFailed` and `retry()` recovers to `CameraReady` without leaving the screen; the same holds for a failed switch and a failed resume. |
| FLT-ERR-005 | A failure to write a captured image to durable storage shall abort that capture and surface it; no queue row shall be created for a file that does not exist. | GR-4 | MANDATORY | `CaptureStorage` | `UNIT`, `DATA` | **DONE** — a storage failure aborts the capture and writes no row; a failed insert removes the file it just wrote, and only that file. |
| FLT-ERR-006 | A database write failure shall leave the queue in its prior consistent state. | GR-4 | QUALITY | `UploadQueueDao` | `DATA` | **DONE** — a forced failure inside the enqueue transaction leaves batch and images in their prior state. |
| FLT-ERR-007 | An item whose local file is missing at upload time shall be resolved deterministically to a permanent failure and shall not be retried forever. | derived from 005 | QUALITY | `QueueProcessor` | `UNIT`, `DATA` | **DONE** — a missing file is classified permanent without the transport being called; unrelated batches still drain and a second pass finds nothing to do. |
| FLT-ERR-008 | Upload timeouts shall classify as retryable, distinctly from a rejection by the server. | derived from FLT-SYNC-006 | QUALITY | `FailureClassifier` | `UNIT` | **DONE** — timeout is retryable, a rejection is permanent, and the two are asserted against each other. |

---

## FLT-UX — Experience and accessibility

| ID | Requirement | Source | Priority | Component | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- |
| FLT-UX-001 | The camera preview shall be the dominant surface; chrome shall not obstruct it unnecessarily. | derived; p3 left | QUALITY | `CameraPreviewScreen` | `REVIEW`, `DEVICE` | TODO |
| FLT-UX-002 | Every interactive control shall have a touch target of at least 48×48 dp. | accessibility baseline | QUALITY | `presentation` | `WIDGET` | TODO |
| FLT-UX-003 | Every control shall carry a screen-reader label describing its action and current value. | accessibility baseline | QUALITY | `presentation` | `WIDGET` (semantics) | TODO |
| FLT-UX-004 | All motion shall respect `MediaQuery.disableAnimations`; required feedback shall still occur, without animation. | RESEARCH `FR-11` | QUALITY | `presentation` | `WIDGET` | TODO |
| FLT-UX-005 | No state shall be distinguishable by colour alone; each shall carry an icon or text. | accessibility baseline | QUALITY | `UploadManagerScreen` | `WIDGET`, `REVIEW` | TODO |
| FLT-UX-006 | Pending Uploads shall have a designed empty state. | derived from FLT-BAT-003 | QUALITY | `UploadManagerScreen` | `WIDGET` | TODO |
| FLT-UX-007 | Queued-while-offline messaging shall state that the capture is safe and will retry automatically. | derived from FLT-SYNC-004 | QUALITY | `UploadManagerScreen` | `WIDGET`, `REVIEW` | TODO |
| FLT-UX-008 | Non-camera surfaces shall use Material 3 role-based colour and render correctly in light and dark. | RESEARCH `FR-10` | QUALITY | `theme` | `WIDGET`, `DEVICE` | TODO |
| FLT-UX-009 | `[screenshot]` A retrying item shall show its attempt count. | p3 right ("ATTEMPT 3/5") | QUALITY | `UploadManagerScreen` | `WIDGET` | TODO |
| FLT-UX-010 | `[screenshot]` Connectivity status shall be visible on the Upload Manager, worded as a hint rather than a guarantee. | p3 right ("STABLE LINK"); RESEARCH `FR-05` | QUALITY | `UploadManagerScreen` | `WIDGET` | TODO |
| FLT-UX-011 | `[screenshot]` Per-item states shall be distinguishable: in queue, waiting for connection, uploading, retrying, synced. | p3 right; root RF-06 | QUALITY | `UploadManagerScreen` | `WIDGET` | TODO |
| FLT-UX-012 | The camera screen shall offer a discoverable route to Pending Uploads. | derived from FLT-BAT-003 | QUALITY | `CameraPreviewScreen` | `WIDGET` | TODO |
| FLT-UX-013 | Zoom shall remain operable without gestures, via the slider and presets. | accessibility; FLT-CAM-004 | QUALITY | `CameraPreviewScreen` | `WIDGET` | TODO |

---

## FLT-TEST — Verification requirements

| ID | Requirement | Priority | Verification | Status |
| --- | --- | --- | --- | --- |
| FLT-TEST-001 | Batch and queue state transitions shall be covered by pure-Dart tests with no Flutter binding. | QUALITY | `UNIT` | **DONE** — 42 pure-Dart policy tests, no Flutter binding. |
| FLT-TEST-002 | Queue persistence, transactions and ordering shall be tested against the real SQLite engine on the host. | QUALITY | `DATA` | **DONE** — 58 tests against the real SQLite engine on the host. |
| FLT-TEST-003 | The claim/lease mechanism shall be tested for the concurrent case: two claimants, one winner. | QUALITY | `DATA` | **DONE** — four contention cases over independent connections. |
| FLT-TEST-004 | Stale-`uploading` recovery shall be tested by simulating an expired lease. | QUALITY | `DATA` | **DONE** — fresh, expired, and contended-stale cases. |
| FLT-TEST-005 | Camera, batch and sync Cubits shall have state-transition tests including every failure state. | MANDATORY (evidences FLT-GEN-001) | `BLOC` | PARTIAL — `CameraCubit` covered by 109 `BLOC` tests including every failure state. `BatchCubit` and `SyncBloc` are gates F4/F5. |
| FLT-TEST-006 | A retryable failure followed by a later success shall be tested end to end through the processor. | QUALITY | `UNIT`, `DATA` | **DONE** — proven through `QueueProcessor` and again across two worker invocations. |
| FLT-TEST-007 | Widget tests shall assert semantics and the rendering of every Upload Manager item state. | QUALITY | `WIDGET` | TODO |
| FLT-TEST-008 | The domain-layer purity rule (FLT-GEN-007) shall be asserted by an automated test, not by inspection. | QUALITY | `UNIT` | **DONE** — `domain_purity_test`, including the empty-scan guard. |
| FLT-TEST-009 | Device verification shall cover preview, zoom limits, pinch, tap-focus, capture, camera switching, lifecycle, and the offline→online drain. | MANDATORY | `DEVICE` | TODO |

---

## FLT-DEL — Deliverables

| ID | Requirement | Source | Priority | Verification | Status |
| --- | --- | --- | --- | --- | --- |
| FLT-DEL-001 | Complete functioning source in a public GitHub repository. | p3 Deliverables 1 | MANDATORY | `DOC` | TODO — repository is intentionally private until the human publishes it. |
| FLT-DEL-002 | The README shall cover the Flutter app's structure and name its Cubits in 1–2 sentences. | p4 Guidelines 2 | MANDATORY | `DOC` | TODO |
| FLT-DEL-003 | A release APK shall be built and linked. | p3 Deliverables 3 | MANDATORY | `BUILD`, `DOC` | TODO |
| FLT-DEL-004 | Screenshots/GIFs of the running Flutter app shall be included. | p4 Guidelines 5 | MANDATORY | `DOC` | TODO |
| FLT-DEL-005 | Generative AI usage and representative prompts shall be documented. | p4 Guidelines 3 | MANDATORY | `DOC` | TODO |

---

## Counts

### Counts by priority

| Category | MANDATORY | QUALITY | BONUS | Total |
| --- | --- | --- | --- | --- |
| FLT-GEN | 5 | 2 | 0 | 7 |
| FLT-CAM | 10 | 7 | 1 | 18 |
| FLT-BAT | 3 | 4 | 1 | 8 |
| FLT-SYNC | 7 | 8 | 1 | 16 |
| FLT-ERR | 5 | 3 | 0 | 8 |
| FLT-UX | 0 | 13 | 0 | 13 |
| FLT-TEST | 2 | 7 | 0 | 9 |
| FLT-DEL | 5 | 0 | 0 | 5 |
| **Total** | **37** | **44** | **3** | **84** |

### Counts by status, after F3

| Status | Count | Notes |
| --- | --- | --- |
| `DONE` | 32 | Own verification method executed and evidenced |
| `PARTIAL` | 21 | Implemented and host-verified; a `DEVICE` or later-gate step remains |
| `TODO` | 31 | Batch UI (F4), camera + Upload Manager screens (F5), bonuses (F6), device QA (F7), submission (F8) |
| **Total** | **84** | |

Eight rows moved to `DONE` at F3 — `FLT-CAM-006`, `-007`, `-013`, `-014`, `-016`,
`-017`, `FLT-ERR-003` and `-004`. Every one is a rule the engine owns completely,
with no rendering left to do. **Nothing that needs a screen or a device moved.**

Twelve more became `PARTIAL`: implemented and host-verified, waiting on the F5
screen, on hardware, or on both. `FLT-CAM-005` and `-008` are the two where the code
is finished and only `DEVICE` evidence is missing.

Per category after F3: GEN 2/5/0, CAM 6/7/5, BAT 3/2/3, SYNC 9/5/2, ERR 6/1/1,
UX 0/0/13, TEST 6/1/2, DEL 0/0/5 (`DONE`/`PARTIAL`/`TODO`).

The F1 `DONE` rows are the queue's correctness core: `FLT-GEN-002`, `-007`;
`FLT-BAT-002`, `-005`, `-006`; `FLT-SYNC-003`, `-005`, `-006`, `-008`, `-009`,
`-010`, `-011`, `-013`, `-015`; `FLT-ERR-005`, `-006`, `-007`, `-008`;
`FLT-TEST-001`, `-002`, `-003`, `-004`, `-006`, `-008`. Twenty-three of them moved
at F1; `FLT-SYNC-015` was already `DONE` at F0.

The nine `PARTIAL` rows are `FLT-GEN-003`, `FLT-GEN-005`, `FLT-CAM-015`,
`FLT-BAT-004`, `FLT-SYNC-001`, `-002`, `-004`, `-007` and `-016`. Six of those are
waiting on hardware alone.

The QUALITY count exceeds the MANDATORY count, which is expected and deliberate:
the assessment states *what* must happen, and most of the engineering effort is in
making it survive process death, concurrency and hardware failure. Every QUALITY
row traces to a MANDATORY row it protects — see
[TRACEABILITY_MATRIX.md](TRACEABILITY_MATRIX.md).

## Requirements not carried forward

Recorded so their absence is a decision rather than an oversight.

| Item | p3 screenshot shows | Why it is not a requirement |
| --- | --- | --- |
| "PAUSE ALL" control | A button pausing all uploads | Nothing in the text requires it, and a user-pausable queue is in tension with `FLT-SYNC-004`'s "without user intervention". Rejected as a bonus — see [DECISIONS.md](DECISIONS.md) `ADR-F09`. |
| Non-image queue entries (`.dat`, `.zip`, `.csv`) at gigabyte sizes | A generic file-transfer list | The text says *images*. Root `AMB-11` already resolves this: text wins, the screenshot is illustration. |
| Flash and settings controls | Camera overlay icons | Advisory decoration; no sentence requires either. May be added only if it costs nothing after mandatory work is complete. |
| Batch percentage progress | "42%" batch progress bar | A single mock upload has no meaningful byte-level progress. Item-level state is honest; a fabricated percentage is not. Aggregate *count* progress is delivered instead (`FLT-UX-011`). |
