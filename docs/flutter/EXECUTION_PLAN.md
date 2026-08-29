# Flutter Task — Execution Plan

**What this document is for:** it fixes the order of implementation and the exit
criteria for each gate, so that progress is measurable and so the riskiest work
happens while there is still time to react to it.

Gate numbering continues the repository scheme; Android occupied `G0`–`G3.8` and
is **frozen**. Flutter work is `F0`–`F8`.

---

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

## F1 — Data layer and queue

The highest-risk work, done first.

1. `AppDatabase` — schema v1, indices, migration hook.
2. Entities: `CaptureBatch`, `QueuedImage`, `UploadOutcome`.
3. `UploadQueueDao` — insert, enqueue transaction, **the atomic claim**, success,
   retryable failure, permanent failure, queue watch stream.
4. `FileSystemCaptureStore` — durable persist, delete, missing-file detection.
5. Pure policies: `UploadStateMachine`, `StaleClaimPolicy`, `BatchPolicy`.
6. `DATA` suite against real SQLite, including **the contended-claim test**.

**Exit:** invariants I1–I10 each have a failing-if-broken test; `flutter test`
green; analyze clean.

**Why first:** `RD-01`, `RD-02`, `RD-03` are the register's top risks and the ones
whose design would be most expensive to change later.

---

## F2 — Sync engine

1. `UploadApi` + `MockUploadApi` with all five scenarios.
2. `FailureClassifier` (pure).
3. `QueueProcessor` — the isolate-agnostic drain loop.
4. `WorkManagerSyncScheduler` — constraints, `ExistingWorkPolicy.keep`, backoff.
5. `sync_worker_entrypoint.dart` with `@pragma('vm:entry-point')` and its own
   composition root; the shared `buildDataLayer()` factory.
6. `ConnectivityPlusAdapter` — advisory only.

**Exit:** retryable-failure-then-success proven end to end through the processor
in tests; a simulated process death recovers via lease expiry; no Dart-level lock
anywhere in the path.

---

## F3 — Camera engine ✅ *visual direction approved*

1. `CameraPort` + `CameraXAdapter`.
2. Pure policies: `ZoomPolicy`, `ZoomPresetPolicy`, `FocusPointMapper`.
3. `CameraCubit` — all seven states, generation-guarded switching, capture guard.
4. `CameraPreviewScreen` — preview, lifecycle observer, gestures.
5. Controls: zoom slider, preset row, focus reticle, shutter, switch.
6. Capture → `CaptureStore` → `BatchCubit` wiring.

**Exit:** every camera state renders; reticle position asserted; zoom controls
proven to converge on one value; reduced-motion test proves the reticle still
appears.

---

## F4 — Batch management

1. `BatchCubit` and the open/close rule.
2. Current-batch count and enqueue action wiring.
3. Multi-batch persistence tests.

**Exit:** two batches captured and enqueued independently; ordering across batches
is deterministic.

---

## F5 — Upload Manager UI ✅ *visual direction approved*

1. `SyncBloc` — three event sources, debounced connectivity.
2. `UploadManagerScreen` — batch sections, item rows, all five states.
3. Empty state, reassurance line, connectivity chip.
4. Optional "Try now" accelerator in the overflow.

**Exit:** all five item states render with icon and text; semantics asserted;
empty state present.

---

## F6 — Accepted bonuses

Only after every MANDATORY row above is `DONE` (`ADR-F09`).

1. Last-capture thumbnail with count badge.
2. Post-upload file deletion, row retained.
3. Exposure point with focus.

**Exit:** each is independently revertible; no mandatory row regressed.

---

## F7 — Device QA

Requires physical hardware. Cannot be started from this host.

1. Camera checklist — `CAMERA_ENGINE.md` §8 (13 checks).
2. Sync failure-injection matrix — `SYNC_ENGINE.md` §10 (8 injections).
3. **Record `FQ-01`**: actual back-camera count and zoom ranges. Confirm the
   preset policy against real hardware.
4. Capture screenshots and the two GIFs that only motion can prove: tap-to-focus,
   and offline→online auto-retry.

**Exit:** every `DEVICE` row has recorded evidence; `FQ-01`, `FQ-02`, `FQ-04`
closed or explicitly left open with reasoning.

---

## F8 — Submission

1. Release APK (signing per [root ADR-010](../DECISIONS.md#adr-010)).
2. README sections 1–5, including the Cubit list (`DOC-04`) and the
   `ADR-F03` zoom limitation.
3. `AI_USAGE.md` finalised with representative prompts (`DOC-05`, `DOC-06`).
4. Root docs reconciled; `SUBMISSION_CHECKLIST.md` ticked.
5. **Human** makes the repository public and publishes the APK link.

**Exit:** a clean clone builds both apps from the README alone.

---

## Dependencies

```
F0 ──┬──▶ F1 ──▶ F2 ──┬──▶ F4 ──▶ F6 ──▶ F7 ──▶ F8
 ✅  │                │
     └────────────────┴──▶ F3 ──▶ F5 ──────┘
   (visual gate passed 2026-08-29)
```

The visual gate is cleared, so nothing blocks `F1`–`F6`. `F7` still cannot start
without physical hardware.

---

## Recommended next implementation sequence

The literal order to work in when `F1` starts:

1. `AppDatabase` schema + migration hook, with a creation test.
2. `UploadStateMachine` (pure) + its transition tests — legal and illegal.
3. `UploadQueueDao.insert` / `enqueueBatch` + the transaction rollback test.
4. **`UploadQueueDao.claim`** + the contended-claim test. *Write the contended test
   before the implementation* — it is the one test most likely to be quietly wrong
   otherwise.
5. `StaleClaimPolicy` + lease-expiry reclaim test.
6. Success / retryable / permanent transitions + invariant tests I6, I7, I10.
7. `FileSystemCaptureStore` + write-then-insert ordering test (I1).
8. Only then move to `F2`.

---

## Standing rules

- Formatter, analyzer, tests and a build pass before any gate is declared complete.
- `android-attendance/` is verified unchanged before every commit.
- No push. Publication is a human action (root `AGENTS.md`).
- A requirement moves to `DONE` only when its **own** stated verification method
  has been executed — a passing build is not evidence for a feature row.
- Bonuses never precede mandatory work.
