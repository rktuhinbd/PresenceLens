# Flutter Task — Execution Plan

**What this document is for:** it fixes the order of implementation and the exit
criteria for each gate, so that progress is measurable and so the riskiest work
happens while there is still time to react to it.

Gate numbering continues the repository scheme; Android occupied `G0`–`G3.8` and
is **frozen**. Flutter work is `F0`–`F8`.

---

## FINAL STATE — SUBMISSION COMPLETE

**Historical execution plan. All mandatory gates are complete.** F0 through F5 and F7
are done; F6 (accepted bonuses) was implemented, not skipped (see the F6 section
below); F8 (submission) is done — the repository is public, both release APKs are
published, and the README/AI-disclosure documentation is final. Earlier gate text
below records the state at that time and is retained as provenance — read the
[Stage naming](#stage-naming--authoritative) table for the final status of each gate,
not the prose beneath it, which was written progressively as each gate closed.

---

## Stage naming — authoritative

This document is the authority for gate labels, and the labels below are the ones
every other document and report must use. Recorded explicitly because F1 and F2
were delivered in a single pass, which makes off-by-one confusion easy.

| Gate | Milestone | State |
| --- | --- | --- |
| `F0` | Requirements, architecture, design, visual approval | ✅ complete |
| `F1` | Data layer and durable queue | ✅ complete |
| `F2` | Sync engine, worker, scheduler | ✅ complete — shipped with F1 |
| **`F3`** | **Camera engine** | ✅ **complete 2026-08-30 — engine only; the camera *screen* moved to `F5`** |
| `F4` | Batch management | ✅ complete 2026-08-30 — shipped with F5 |
| **`F5`** | **Camera screen and Upload Manager UI** | ✅ **complete 2026-08-30** |
| `F6` | Accepted bonuses | ✅ **implemented** — last-capture thumbnail with count badge and capability-aware exposure-with-focus are both shipped; post-upload file deletion is implemented but off by default by design (`ADR-F16`), not incomplete |
| `F7` | Device QA | ✅ **complete 2026-08-30** — physical HONOR DNP-NX9 (Android 16) full pass, plus Samsung Galaxy S25 physical pinch-to-zoom user acceptance |
| `F8` | Submission | ✅ **complete** — public repository, v1.0.0 release with both APKs, README and AI disclosure published |

**The Camera Engine milestone is `F3`.** Any instruction referring to it as "F2"
is using the pre-F0 numbering, which this plan superseded; F2 is the sync engine
and it is finished.

## Sequencing principle

**Build the queue before the camera.**

That is deliberate and worth defending. The camera is the *visible* half but the
lower-risk one: it is a well-documented plugin, and its failures are immediate and
obvious. The sync engine is the *invisible* half and carries every catastrophic
risk in the register — cross-isolate concurrency (`RD-02`), orphaned claims
(`RD-03`), image loss (`RD-01`). Those failures are silent.

Building the queue first also means the camera has somewhere real to write into on
the day it starts working, rather than a stub that gets retrofitted.

The visual approval gate that previously fenced `F3` and `F5` was **passed on
2026-08-29**, so no gate now blocks any of the sequence below.

**`F1` and `F2` are complete as of 2026-08-29.** The invisible half is built and
evidenced; what remained at that point in the plan was the visible half, its device
verification, and the submission package — **all since completed** (F3/F4/F5, F7, F8;
see the [FINAL STATE banner](#final-state--submission-complete) above).

---

## F0 — Requirements, architecture, design *(complete; visual direction approved)*

**Delivered**

- Assessment re-extracted from the source PDF and cross-checked against the root matrix.
- 84 requirements specified with IDs, priorities and verification methods.
- Package research verified against primary sources and against a real resolution.
- Architecture, data model, camera engine, sync engine, UX spec, test strategy, risk register, 12 ADRs.
- Static visual prototypes for seven screen states.
- Foundation: identity normalised, dependencies added, `INTERNET` fixed for release, strict analysis enabled.

**Exit criteria — all met**

| Criterion | Result |
| --- | --- |
| `flutter analyze` | **PASS** — no issues |
| `flutter test` | **PASS** — 2/2 |
| `flutter build apk --debug` | **PASS** — `app-debug.apk` produced |
| `git diff --check` | **CLEAN** |
| `android-attendance/` unchanged | **Verified — zero changes** |

**Gate:** ✅ **VISUAL DIRECTION APPROVED, 2026-08-29.** The prototypes were
reviewed and signed off, and the design decisions they carry (`ADR-F13`,
`ADR-F14`, plus the approved palette, density, motion and accessibility
direction) are frozen. `F3` and `F5` are unblocked. Redesigning any approved
element during implementation requires an evidenced device or usability problem,
recorded as a new ADR.

---

## F1 — Data layer and queue ✅ *complete, 2026-08-29*

The highest-risk work, done first.

1. `AppDatabase` — schema v1, indices, migration hook. ✅
2. Entities: `CaptureBatch`, `QueuedImage`, `UploadOutcome`, plus the three
   persisted enums. ✅
3. `UploadQueueDao` — insert, enqueue transaction, **the atomic claim**, success,
   retryable failure, permanent failure, queue watch stream. ✅
4. `FileSystemCaptureStore` — durable persist, delete, missing-file detection. ✅
5. Pure policies: `UploadStateMachine`, `StaleClaimPolicy`, `BatchPolicy`, plus
   `FailureClassifier` and `RetentionPolicy` brought forward from F2. ✅
6. `DATA` suite against real SQLite, including **the contended-claim test**. ✅

**Exit criteria — all met**

| Criterion | Result |
| --- | --- |
| Invariants I1–I10 each have a failing-if-broken test | **PASS** — mapping tabulated in `TEST_STRATEGY.md` §11 |
| `flutter test` | **PASS** — 188/188 |
| `flutter analyze` | **PASS** — no issues |
| `dart format` stable | **PASS** |
| `flutter build apk --debug` | **PASS** |

**Why first:** `RD-01`, `RD-02`, `RD-03` are the register's top risks and the ones
whose design would be most expensive to change later. All three are now mitigated
*and evidenced*; the register was updated with what each test actually proves.

---

## F2 — Sync engine ✅ *complete, 2026-08-29 — delivered together with F1*

Delivered in the same pass as F1 rather than as a separate gate. The reason is
`sync_worker_entrypoint.dart`: verifying that the worker isolate can rebuild its
own data layer means the whole graph has to exist, so splitting the two would have
produced an F1 whose most important claim could not be tested until F2 anyway.

1. `UploadApi` + `MockUploadApi` with all five scenarios. ✅
2. `FailureClassifier` (pure). ✅
3. `QueueProcessor` — the isolate-agnostic drain loop. ✅
4. `WorkManagerSyncScheduler` — constraints, one serial unique chain with
   `ExistingWorkPolicy.append`, backoff. ✅
5. `sync_worker_entrypoint.dart` with the `vm:entry-point` dispatcher and its own
   composition root; the shared `buildDataLayer()` factory. ✅
6. `ConnectivityPlusAdapter` — advisory only — plus `ConnectivityDrainTrigger`
   for the opportunistic reschedule. ✅

**Exit criteria — all met**

| Criterion | Result |
| --- | --- |
| Retryable-failure-then-success proven end to end through the processor | **PASS** — and again across two worker invocations |
| A simulated process death recovers via lease expiry | **PASS** — in the DAO and through the processor |
| No Dart-level lock anywhere in the path | **PASS** — exclusion is a conditional SQL `UPDATE`; verified with independent connections |

**Two defects found and fixed inside the gate, both instances of `RS-04`.**

1. The first `QueueProcessor` re-claimed the item it had just failed, because a
   retryable failure makes a row `PENDING` and therefore immediately claimable —
   25 attempts on one image in a fraction of a second. A test caught it; the fix
   excludes already-tried items from the claim (`ADR-F18`).
2. A bounded slice reported healthy backlog as a failure, so WorkManager applied
   escalating backoff to a queue that was draining perfectly — the more it
   succeeded, the slower it went. The **architecture audit** caught it; the fix
   separates progress from failure and enqueues a WorkManager continuation
   (`ADR-F19`).

Both are recorded because the register had described `RS-04` only as "an app-side
timer", and neither of these was one.

### Post-audit hardening *(same gate, amended into the same commit)*

The F1 architecture audit accepted the design and required six corrections:

| # | Finding | Resolution |
| --- | --- | --- |
| 1 | Healthy bounded backlog scheduled as a retry | `ADR-F19` — four dispositions, WorkManager continuation, plus a time budget alongside the item budget |
| 2 | 15 s described as Android's "enforced floor" | Corrected everywhere; the floor is **10 s**, read from `androidx.work:work-runtime:2.11.2`. The configured value is unchanged (`FR-06`) |
| 3 | Scheduling failure was safe but invisible | `SchedulingOutcome` returned instead of `void`; last error retained; still non-throwing |
| 4 | "One `DRAFT` batch" implied database enforcement | `ADR-F20` — declared an application workflow rule, with a test asserting the limit of the guarantee |
| 5 | Empty `onUpgrade` could silently record a version bump | Migration registry that refuses an unregistered step; `onDowngrade` refuses rather than deleting the queue |
| 6 | iOS retry semantics undocumented | `SYNC_ENGINE.md` §8B; recorded as `RS-10`, not implemented, not claimed |

Tests went from 188 to **212**.

---

## F3 — Camera engine ✅ **COMPLETE (2026-08-30)** — engine only

**Scope was deliberately narrowed to the engine.** Items 4 and 5 below are camera
*UI*, and building them in the same pass as the mechanics would have meant
debugging a state machine through a viewfinder. They move to **F5**, alongside the
Upload Manager, which is where the rest of the approved visual direction is built.

1. ✅ `CameraEngine`/`CameraSession` ports + `CameraXAdapter` + `CameraXSession`.
2. ✅ Pure policies: `ZoomPolicy`, `ZoomPresetPolicy`, `FocusPointMapper`,
   `CameraSelectionPolicy`.
3. ✅ `CameraCubit` — sealed states, generation-guarded acquisition and switching,
   capture guard, coalescing zoom pump, lifecycle orchestration.
4. → **F5** `CameraPreviewScreen` — preview, lifecycle observer, gestures.
5. → **F5** Controls: zoom slider, preset row, focus reticle, shutter, switch.
6. ✅ Capture → `CaptureIntoBatch` → `RecordCapture` → `CaptureStore` + queue row.
7. ✅ `FakeCameraEngine` with completion gates; `CameraDiagnostics` for device QA;
   an import-confinement test keeping `package:camera/` inside `lib/data/camera/`.

**Exit criteria met:** 445 tests pass (+216), `flutter analyze` clean, debug APK
builds; zoom controls proven to converge on one value; the switch race, the
double-shutter guard and the lifecycle races each driven explicitly.

**Exit criteria deferred with the UI:** every camera state *renders*; reticle
position asserted; the reduced-motion test. Those are `WIDGET` claims and there is
no widget yet.

**Found and recorded:** `ADR-F22` (Android cannot report permanent permission
denial — `FR-12`), `ADR-F23` (the preview seam; both preview fits supported).

---

## F4 — Batch management

1. `BatchCubit` and the open/close rule.
2. Current-batch count and enqueue action wiring.
3. Multi-batch persistence tests.

**Exit:** two batches captured and enqueued independently; ordering across batches
is deterministic.

---

## F5 — Camera and Upload Manager UI ✅ *visual direction approved*

Now carries the camera screen inherited from F3.

1. `CameraPreviewScreen` — `buildCameraPreview` over the live session, the
   lifecycle observer mapping `AppLifecycleState` → `CameraLifecycleSignal`, and
   the gesture handlers feeding `focusAt` / `beginPinch` / `updatePinch`.
2. Camera controls: zoom slider, preset row, focus reticle, shutter, switch — all
   reading the one `currentZoom` and the published `FocusRequest`.
3. Permission recovery: the `MethodChannel` opening
   `ACTION_APPLICATION_DETAILS_SETTINGS`, offered on escalation, never worded as a
   permanence claim (`ADR-F22`).
4. `SyncBloc` — three event sources, debounced connectivity.
5. `UploadManagerScreen` — batch sections, item rows, all five states.
6. Empty state, reassurance line, connectivity chip.
7. Optional "Try now" accelerator in the overflow.

**Exit:** every camera state renders; the reticle lands on the tap within
tolerance; the reduced-motion test proves the reticle still appears; all five item
states render with icon and text; semantics asserted; empty state present.

---

## F6 — Accepted bonuses ✅ **implemented, not skipped**

Only after every MANDATORY row above is `DONE` (`ADR-F09`) — which it was by the time
these landed alongside F4/F5.

1. **Last-capture thumbnail with count badge.** Shipped — `BatchThumbnail`
   (`FLT-BAT-007`, `FLT-BAT-008`), visible in production and in the submission
   screenshot `docs/assets/flutter/camera-active-batch.png`.
2. **Post-upload file deletion, row retained.** Implemented but **deliberately off by
   default** (`ADR-F16`) — it conflicts with the approved Upload Manager thumbnail,
   which needs the file to still exist after a successful upload. This is a recorded
   design decision, not an unfinished bonus.
3. **Exposure point with focus.** Shipped — capability-aware exposure pairing exists
   through `camera_x_adapter.dart`, `camera_cubit.dart`, and the domain
   `camera_capabilities`/`camera_geometry` entities.

**Exit:** each is independently revertible; no mandatory row regressed. **Met.**

---

## F7 — Device QA ✅ **complete, 2026-08-30**

Required physical hardware; a HONOR DNP-NX9 (Android 16) was used, plus a Samsung
Galaxy S25 for the physical pinch-to-zoom acceptance check.

1. Camera checklist — `CAMERA_ENGINE.md` §8 (13 checks). **Executed** — see
   `CAMERA_ENGINE.md` §8's final annotations for the per-check disposition.
2. Sync failure-injection matrix — `SYNC_ENGINE.md` §10 (8 injections). **Executed**
   for the critical path (offline → capture → finish batch → background → restore
   connectivity → automatic drain, no retry press); see `SYNC_ENGINE.md` §10 for the
   full per-scenario disposition, including the scenarios not separately run.
3. **`FQ-01`**: back-camera count and zoom range confirmed against the real device —
   the HONOR DNP-NX9 reports a single rear camera across 1x–8x, and the preset policy
   was confirmed against it live.
4. Screenshots were captured (five Flutter states, one Native state, all under
   `docs/assets/`). **The two GIFs were not delivered** — the assessment accepts
   screenshots **or** GIFs (DOC-08), and screenshots satisfy the requirement; the
   offline→online GIF is additionally covered by the paired
   `uploads-offline.png` / `uploads-success.png` screenshots.

**Exit:** every `DEVICE` row has recorded evidence; `FQ-01` closed. `FQ-02`/`FQ-04`
(if they concern the optional GIFs or a second physical device) are explicitly left
open with the reasoning above, not silently marked done.

---

## F8 — Submission ✅ **complete**

1. Release APK (signing per [root ADR-010](../DECISIONS.md#adr-010)). **Done** — both
   `PresenceLens-Attendance-v1.0.0.apk` and `PresenceLens-Capture-v1.0.0.apk` are
   published on the v1.0.0 GitHub release.
2. README sections 1–5, including the Cubit list (`DOC-04`) and the
   `ADR-F03` zoom limitation. **Done.**
3. `AI_USAGE.md` finalised with representative prompts (`DOC-05`, `DOC-06`). **Done.**
4. Root docs reconciled; `SUBMISSION_CHECKLIST.md` ticked. **Done** — this document
   set was reconciled to final state at the dedicated documentation-consistency pass.
5. **Human** makes the repository public and publishes the APK link. **Done** —
   [github.com/rktuhinbd/PresenceLens](https://github.com/rktuhinbd/PresenceLens) is
   public.

**Exit:** a clean clone builds both apps from the README alone. **Met** —
`SUBMISSION_CHECKLIST.md` §§2.3–2.5.

---

## Dependencies

```
F0 ──┬──▶ F1 ──▶ F2 ──┬──▶ F4 ──▶ F6 ──▶ F7 ──▶ F8
 ✅  │     ✅     ✅   │
     └────────────────┴──▶ F3 ──▶ F5 ──────┘
   (visual gate passed 2026-08-29)
```

The visual gate is cleared, the queue is built and the camera engine is done, so
nothing blocks `F4`–`F6`. `F7` still cannot start without physical hardware.

---

## Recommended next implementation sequence

*(Sequencing note, historical — written when `F1`, `F2` and `F3` had just closed.)* The next gate at that point was **`F4` — batch management**, which is itself long since complete, along with every later gate.

Both predictions made at F1 held, and are recorded as such:

1. `RecordCapture` was reused, not reimplemented. `CaptureIntoBatch` opens or joins
   the draft batch and delegates the file-then-row ordering and its compensation
   entirely to `RecordCapture`.
2. `BatchPolicy` still owns the open/close rule; `CaptureIntoBatch` executes the
   *opening* half, and `F4`'s `BatchCubit` should call the policy for the closing
   half rather than restating it.

Three things from `F3` carry into `F4` and `F5`:

3. `CameraCubit` already publishes `batchImageCount`, read back from the database
   rather than tallied locally. `F4`'s `BatchCubit` owns the *finish* action and the
   list; it should not re-derive the live count.
4. The camera screen is now part of `F5`, not `F4`. `buildCameraPreview(session)` is
   the whole preview integration; `focusAt` takes a `PreviewLayout` the widget must
   supply, including which `PreviewFit` it renders with (`ADR-F23`).
5. `ADR-F22` leaves one concrete task for `F5`: a `MethodChannel` in `MainActivity`
   for `ACTION_APPLICATION_DETAILS_SETTINGS`. Deliberately not built at `F3` —
   there was no caller, and an untested recovery path is worse than none.

*(The original F1 ordering advice is preserved below because the prediction it
made turned out to be correct.)*

The literal order worked in during `F1`:

1. `AppDatabase` schema + migration hook, with a creation test.
2. `UploadStateMachine` (pure) + its transition tests — legal and illegal.
3. `UploadQueueDao.insert` / `enqueueBatch` + the transaction rollback test.
4. **`UploadQueueDao.claim`** + the contended-claim test. *Write the contended test
   before the implementation* — it is the one test most likely to be quietly wrong
   otherwise. **This was followed, and it paid: the claim was the first thing
   proven, before anything was built on top of it.**
5. `StaleClaimPolicy` + lease-expiry reclaim test.
6. Success / retryable / permanent transitions + invariant tests I6, I7, I10.
7. `FileSystemCaptureStore` + write-then-insert ordering test (I1).

---

## Standing rules

- Formatter, analyzer, tests and a build pass before any gate is declared complete.
- `android-attendance/` is verified unchanged before every commit.
- No push. Publication is a human action (root `AGENTS.md`).
- A requirement moves to `DONE` only when its **own** stated verification method
  has been executed — a passing build is not evidence for a feature row.
- Bonuses never precede mandatory work.
