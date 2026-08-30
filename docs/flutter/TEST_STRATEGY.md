# Flutter Task — Test Strategy

**What this document is for:** it decides *what gets tested and why*, before the
code exists, so that test effort lands on the failures that would actually cost
the submission — not on whatever is easiest to assert.

Risk-based, in the spirit of ISO/IEC/IEEE 29119-1:2022. *An application of
risk-based verification concepts, not a claim of certification.*

Covers `FLT-TEST-001` … `FLT-TEST-009`.

---

## 0. FINAL EXECUTION SUMMARY (submission, F7 complete, 2026-08-30)

**521 automated tests pass; `flutter analyze` reports 0 issues; `flutter build apk
--debug` and `--release` both succeed.** Every tier described in §2 below was
executed, not just planned:

| Tier | Executed | Headline |
| --- | --- | --- |
| `UNIT` | Yes | Pure policy: zoom, focus mapping, batch rules, lease boundaries, failure classification |
| `DATA` | Yes | Real SQLite via `sqflite_common_ffi` — the atomic claim, transactions, migrations |
| `BLOC` | Yes | `CameraCubit`, `BatchCubit` state-transition coverage, including lifecycle and switch races |
| `WIDGET` | Yes | Every screen and every failure state rendered and asserted, including reduced-motion |
| `INTEGRATION` | Yes | `SyncBloc` over real SQLite, 14 cases |
| `DEVICE` | **Yes — F7, 2026-08-30** | Physical HONOR DNP-NX9 (Android 16): live preview, zoom, tap-to-focus with reticle, capture, the double-shutter guard, camera lifecycle, multi-batch, Pending Uploads, and the critical offline → capture → finish batch → background → restore connectivity → automatic drain path with no retry press. Physical pinch-to-zoom additionally user-confirmed on a Samsung Galaxy S25. |

The `DEVICE` tier — planned in §7 below as "deferred" while no hardware was
available — is the one this summary exists to close out: it is no longer
deferred, and every headline it enumerated was executed and evidenced (full
account: [PROJECT_STATE.md](../PROJECT_STATE.md), [AI_USAGE.md
§F7](../AI_USAGE.md), and the per-check tables in
[CAMERA_ENGINE.md](CAMERA_ENGINE.md) §9 and [SYNC_ENGINE.md](SYNC_ENGINE.md) §10).

**Historical planning language below this summary is preserved as written.** It
was the pre-implementation risk-based strategy that shaped what got tested, and
the gate-by-gate counts in §11 (188 → 229 → 445 → 516 → 521) are the dated record
of how that plan executed. None of it should be read as describing an open or
deferred state today.

---

## 1. Principle

**Test count is not the goal.** The Android task has 158 tests because it has 158
things worth pinning, not because a number was targeted. The same discipline
applies here: every test must name a failure it prevents.

The prioritisation question for each candidate test is: *if this breaks silently,
what does it cost?*

| Failure | Cost | Test tier |
| --- | --- | --- |
| A queued image is lost | **Catastrophic** — violates the central requirement (`FLT-SYNC-003`) | `UNIT` + `DATA` |
| Two workers upload the same item | Severe — duplicate server state, corrupt counts | `DATA` |
| An item sticks in `UPLOADING` forever | Severe — queue never drains, looks broken | `UNIT` + `DATA` |
| Retry never fires automatically | Severe — violates `FLT-SYNC-004` | `UNIT` + `DEVICE` |
| Camera controller leaks / dead preview | High — visible crash class | `BLOC` + `DEVICE` |
| Zoom controls disagree | Moderate — visible bug, not data loss | `BLOC` |
| Reticle misplaced by a few px | Low — cosmetic | `WIDGET` |

Effort is allocated top-down that table.

---

## 2. Tiers

| Tier | Runs on | Speed | Needs |
| --- | --- | --- | --- |
| `UNIT` | Dart VM | ms | Nothing |
| `DATA` | Dart VM + **real SQLite** (`sqflite_common_ffi`) | ms | Nothing |
| `BLOC` | Dart VM | ms | Nothing |
| `WIDGET` | `flutter_test` | ms | Nothing |
| `DEVICE` | Physical device | minutes | Hardware — **executed at F7, 2026-08-30 (see §0)** |

The first four run in CI and on a Windows host with no emulator. That is
deliberate: it means the whole logical core of the sync engine — the part most
likely to be wrong — is verified without hardware.

**`sqflite_common_ffi` is the strategic choice here.** It runs the genuine SQLite
engine, so the atomic-claim tests exercise real statement semantics. A hand-written
in-memory fake would cheerfully pass a claim implementation that is not actually
atomic, which is exactly the bug that matters most.

---

## 3. `UNIT` — pure policy

No Flutter binding, no I/O.

| Target | Cases |
| --- | --- |
| `ZoomPolicy` **PASS (23)** | Clamp below min, above max, inside, and against a non-1.0 minimum; `NaN` resolves to the minimum while the infinities land on the ends; pinch anchored at gesture start; zero/negative/non-finite scale holds the baseline; **an explicit assertion that the compounding alternative drifts** — the regression the anchoring exists to prevent. |
| `ZoomPresetPolicy` **PASS (15)** | Range `[1,1]` → only `1x`; `[0.6, 4]` → the sub-1 preset uses the **reported** minimum, not a rounded `0.5`; `[1,3]` → `2x` but no `5x`; a range entirely above 1 offers its own baseline instead of an unhonourable `1x`; presets never escape the range; **no preset asserts an optical multiplier when `lensType` is `unknown`**, and an unidentified camera's label contains no `x` at all (`FLT-CAM-016`). |
| `FocusPointMapper` **PASS (19)** | Centre and corners; `contain` letterboxing in both directions with a band tap → `null` and the exact image edges inside; `cover` cropping in both directions, including that a tap at the visible left edge is **a third of the way into the image**; the same tap giving different answers under different aspect ratios; degenerate layouts and non-finite taps rejected. |
| `CameraSelectionPolicy` **PASS (16)** | Front and external cameras excluded; front-only and empty enumerations; ordinals re-stamped over back cameras only; the platform-identified wide lens wins; with no identity, a *deterministic* first-camera fallback that is explicitly not a claim; cycling wraps. |
| `BatchPolicy` | Batch opens on first capture; second capture joins the same batch; enqueue closes it; the next capture opens a new one; empty enqueue refused; only one `DRAFT` at a time. |
| `UploadStateMachine` | Every legal transition accepted; every illegal one rejected — in particular `UPLOADED → PENDING`, and `FAILED_PERMANENT → anything`. |
| `FailureClassifier` | Timeout, socket error, 5xx → retryable; 4xx → permanent; missing file → permanent; unknown exception → retryable (fails open). |
| `StaleClaimPolicy` | Lease not expired; exactly at the boundary; expired; a `claimed_at` stamped in the future is not treated as expired. |
| Domain purity | An automated scan asserting no file under `lib/domain/` imports `camera`, `sqflite`, `workmanager`, `connectivity_plus`, `path_provider` or `flutter/material` — **plus a guard that fails if the scan finds no source files** (a scan matching nothing must not read as a pass). Mirrors the Android `DomainLayerPurityTest`. |

---

## 4. `DATA` — real SQLite

The highest-value tier.

| Target | Cases |
| --- | --- |
| Schema | Create; indices present; foreign key cascade deletes images with their batch. |
| Capture insert | Row written; `image_count` incremented in the same transaction. |
| Enqueue | Batch and **all** images move together; a forced mid-transaction failure leaves *nothing* moved (invariant I2). |
| **Claim (single)** | One `PENDING` item is claimed; status `UPLOADING`; `claimed_at` set. |
| **Claim (contended)** | Two claim calls against one `PENDING` row → **exactly one** succeeds, the other returns null. This is the `FLT-SYNC-008` test. |
| **Claim (ordering)** | Across two batches, the oldest `captured_at` is claimed first (`FLT-SYNC-013`). |
| **Claim (stale reclaim)** | An `UPLOADING` row with an expired `claimed_at` is reclaimable; one within its lease is not (`FLT-SYNC-009`). |
| Success | → `UPLOADED`, `claimed_at` cleared; batch → `COMPLETED` only when the last image lands (I8). |
| **Success idempotency** | Marking `UPLOADED` twice affects 0 rows the second time and does not re-complete the batch (I7). |
| **Retryable failure preserves everything** | Row still present, status `PENDING`, `attempt_count` incremented, **file still on disk** (I6). The `FLT-SYNC-003` test. |
| Permanent failure | → `FAILED_PERMANENT`; excluded from subsequent claims. |
| Missing file | Classified permanent; does not loop (I10). |
| `image_count` reconciliation | Denormalised count matches `COUNT(*)` after a mixed sequence of operations (I9). |
| Migration | `onCreate` at v1 succeeds; the upgrade path is exercised even though it is currently empty. |

---

## 5. `BLOC` — Cubit and Bloc transitions

**Executed at F3 for `CameraCubit`: 109 tests across six suites, all passing.** The
enabling piece is `test/support/fake_camera.dart`, a camera the test drives
completely — configurable devices, lens types, zoom ranges and focus/exposure
support, injectable failures on every operation, and **gates that hold
initialisation, zoom, capture and disposal open until the test releases them**.
Every failure that actually costs a camera app is a matter of ordering, and ordering
cannot be provoked on demand with real hardware. It can here.

| Target | Cases | Status |
| --- | --- | --- |
| `CameraCubit` discovery | Success → `CameraReady` with capabilities read from the platform; empty list → `CameraUnavailable(noCameras)`; front-only → `CameraUnavailable(noBackCamera)`; front and external filtered out; enumeration throwing → `CameraFailed`; a non-`CameraException` still classified. | **PASS (20)** |
| `CameraCubit` identity | A reported `lensType` survives into the state; the identified wide lens is opened rather than merely the first camera; **with all lens types unknown, no preset claims an optical identity** and the fallback choice is deterministic. | **PASS** (in the 20) |
| `CameraCubit` permission | Refusal → denied state with a working retry; only a *platform* verdict sets `isPermanentPerPlatform`; repeated refusals are counted, never promoted; a restriction cannot be retried; a granted retry resets the counter (`ADR-F22`). | **PASS** (in the 20) |
| `CameraCubit` zoom | Pinch, slider and preset converge on one value; clamped at both ends and against a non-1.0 minimum; state moves before the platform call resolves; a burst of 20 requests does **not** become 20 platform calls, and the **last requested value is the one finally applied**; a rejected zoom does not tear down the camera. | **PASS (16)** |
| `CameraCubit` focus | Normalised point reaches the platform; a repeat tap at the same coordinates is still distinguishable; a tap on a letterbox band is ignored; unsupported focus is reported as unsupported, not as a failure; a focus failure leaves the camera usable; **exposure is paired only where supported, and a failed exposure does not erase the successful focus**. | **PASS (16)** |
| `CameraCubit` capture | `isCapturing` set then cleared; **two — and five — simultaneous presses produce exactly one platform capture and one row**; the temporary path goes through `RecordCapture`; repeated captures join one draft batch and a new batch opens after the previous is finished; a failed photograph writes no file and no row; a storage failure preserves its cause; **no drain is scheduled for a `DRAFT` capture**. | **PASS (22)** |
| `CameraCubit` switch race | A→B→C ends on C however late B completes; the late session is **disposed**, not attached; no state is ever emitted for a superseded camera; a supersede *before* the open began never acquires that camera at all; eight rapid switches leak nothing; a switch is refused mid-capture. | **PASS (15)** |
| `CameraCubit` lifecycle | `paused`/`detached` release; `resumed` restores the **selected** camera; `inactive` changes nothing; a failed resume is recoverable; a device with no camera is not re-enumerated on every resume; captures survive a pause; **a pre-pause initialisation cannot overwrite the resumed state**; double dispose is safe and an operation completing after `close()` emits nothing. | **PASS (20)** |
| `BatchCubit` | Append updates count; enqueue clears the open batch; enqueue with zero images refused. | F4 |
| `SyncBloc` | `QueueChanged` re-renders; `ConnectivityChanged` to online triggers a reschedule; `AppResumed` reconciles (`FLT-SYNC-012`); `RetryRequested` triggers a drain and nothing else; connectivity chatter is debounced into a single reschedule. | F5 |
| `BatchCubit` | Append updates count; enqueue clears the open batch; enqueue with zero images refused. |
| `SyncBloc` | `QueueChanged` re-renders; `ConnectivityChanged` to online triggers a reschedule; `AppResumed` reconciles (`FLT-SYNC-012`); `RetryRequested` triggers a drain and nothing else; connectivity chatter is debounced into a single reschedule. |

---

## 6. `WIDGET`

| Target | Cases |
| --- | --- |
| `CameraPreviewScreen` states | Ready, permission denied, no camera, init failure each render their panel; **the Pending Uploads entry remains reachable in every failure state**. |
| Batch affordance | "Finish batch" absent at count 0, present and correctly counted at count > 0 (`FLT-BAT-007`); label renders without truncation at counts 1, 12 and 99. |
| Focus reticle | Appears at the tapped offset within tolerance (`FLT-CAM-009`). |
| Zoom slider | Dragging emits the expected values; reflects external changes. |
| Upload Manager | All five item states render with icon **and** text (`FLT-UX-011`, `FLT-UX-005`); attempt count shown only while retrying; empty state renders (`FLT-UX-006`); reassurance line present while anything is pending (`FLT-UX-007`). |
| Semantics | Shutter, presets, slider and queue rows expose the labels specified in `UX_SPEC.md` §6; touch targets ≥ 48 dp. |
| Reduced motion | With `disableAnimations: true`, the reticle **still appears** (`FLT-UX-004`) — the regression this guards is "we disabled the animation and disabled the feedback with it". The same test covers the signature sequence (`UX_SPEC.md` §7.1): shutter haptic retained, batch count still increments, travel animation omitted. |

### What this tier cannot do, and what was done about it — `ADR-F24`

The intention was that widget tests would drive the **real** DAO, so that "the
count came from the database" was a claim about the database. It does not work,
and the failure is a hang rather than a wrong answer: `testWidgets` runs its body
inside a fake-async zone with a controlled clock, and the FFI SQLite engine's
genuine file I/O is never completed by anything that clock advances. The first
attempt sat at `pumpAndSettle` for its full ten-minute timeout — measured, not
assumed.

So the tiers were split rather than blurred:

| Tier | Runner | Queue | What it may claim |
| --- | --- | --- | --- |
| `WIDGET` | `testWidgets` | `InMemoryUploadQueue` | Rendering, wiring, semantics, layout, motion branches |
| `INTEGRATION` | plain `test()` | the real DAO over real SQLite | Reconciliation, durability, drain outcomes reaching the screen state |

`InMemoryUploadQueue` reimplements the port's *observable* contract — one draft
batch, count advanced with the insert, enqueue moving a batch in one step, a
change announcement per mutation — plus fault switches for a refused read and a
refused transaction. It is not a stub that answers whatever the test wanted.

The cost is stated rather than hidden: **no widget test in this repository proves
a persistence rule.** That is exactly why the integration tier exists.

---

## 6B. `INTEGRATION` — the presentation layer over real SQLite

Plain `test()` cases in `test/integration/`, wiring `SyncBloc`, `BatchCubit`,
`FinishBatch`, `CaptureIntoBatch` and a real `QueueProcessor` to a real database
file. Fourteen cases, and the claims they carry:

| Case | What it proves |
| --- | --- |
| Durable pending work at launch requests a drain | The startup half of `FLT-SYNC-012`, closing `RS-11` |
| An empty queue at launch requests nothing | No worker is woken for nothing |
| A `DRAFT` capture requests nothing | `ADR-F21` still holds with a UI attached |
| A resume with pending work requests a drain | The resume half of `FLT-SYNC-012` |
| Regaining a link requests a drain — **exactly once** | The `ADR-F25` split: the F1 trigger asks the platform, the bloc does not also ask |
| Losing a link requests nothing and changes no row | Connectivity is advisory, never a gate (`FLT-SYNC-011`) |
| A refused schedule leaves three pending rows untouched, and is visible in state | A lost wake-up costs a delay, never a photograph |
| A later resume asks again | The refusal is recoverable without user action |
| Finish batch → two `PENDING` rows → visible on the screen state | `FLT-BAT-005` through to the UI, offline |
| An empty batch is refused and schedules nothing | `FLT-BAT-006` at the call site |
| A successful foreground pass leaves nothing pending and the batch synced | `ADR-F25`'s foreground drain |
| A completed batch collapses out after its hold | The screen ends in the empty *success* state |
| A retryable failure keeps row, file and attempt count | `FLT-SYNC-003` end to end |
| A cleanup failure never shows a synced item as pending again | Housekeeping is not delivery (`SYNC_ENGINE.md` §5) |

**None of these claims anything about Android's scheduler.** Every scheduling
assertion is about what the app *asked* for.

---

## 7. `DEVICE` — executed at F7 (2026-08-30)

**HISTORICAL PLANNING NOTE, superseded by §0 above.** This section was written
when hardware was not yet available; it enumerated the headlines so the eventual
session would be a checklist, not an exploration. That session happened at F7.
Full per-check results: [CAMERA_ENGINE.md](CAMERA_ENGINE.md) §9 and
[SYNC_ENGINE.md](SYNC_ENGINE.md) §10.

Headlines, and their final disposition:

1. Real preview, real zoom limits, real pinch and tap-focus. **PASS**, pinch as a manual-user check (not ADB-automated), corroborated on a Samsung Galaxy S25.
2. `availableCameras()` output on a genuine multi-lens device (`FQ-01`) — this
   also validates the preset policy against real hardware. **PASS** — one back camera reported, 1x–8x, no fabricated lens label.
3. Background/foreground lifecycle with a live camera. **PASS**.
4. **Airplane mode → enqueue → restore, with the app backgrounded.** The single
   most important device test; it is the mandated requirement. **PASS**, after clearing a Honor-specific `HN_USER_EXPERIENCE` OEM background-launch restriction in device Settings (no code-level fix exists or was needed); re-confirmed with a fresh v1.0.0 install at the documentation-reconciliation session.
5. Force-stop mid-upload → relaunch → lease recovery. **PASS**.
6. Reboot with items pending. **PASS**.

---

## 8. Non-device gates

Run before every gate exit:

```bash
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Analysis is treated as a real gate: `analysis_options.yaml` enables
`strict-casts`, `strict-inference`, `strict-raw-types`, and promotes
`unawaited_futures` to an **error** — an unawaited write in the capture or upload
path is a genuine defect class here, not a style preference.

---

## 9. What will not be tested, and why

| Not tested | Why |
| --- | --- |
| The `camera` plugin's own behaviour | It is Flutter-team code with its own suite. The app's adapter is tested; the plugin is not re-tested. |
| WorkManager's scheduler | Same reasoning, plus it is OS-controlled. What is tested is that the app returns the correct `Result` and registers the correct constraints. |
| Golden/pixel images | Brittle across platforms and Flutter versions, and they would fail on every intentional design change. Semantics and structure are asserted instead. |
| Exact animation curves | Durations are tokens; asserting easing values tests the framework. What *is* asserted is that reduced motion preserves required feedback. |
| The mock API's transport | There is no transport. Its determinism is tested; its realism is not claimed. |

---

## 10. Coverage intent

No coverage percentage target. A percentage rewards testing trivial getters and
says nothing about whether the claim query is atomic.

The stated intent instead: **every row in `DATA_MODEL.md` §5 (invariants I1–I10)
has at least one test that fails if the invariant is broken.** That is the
checkable coverage claim for this project, and it is the one a reviewer can audit
in a minute. **Discharged at F1** — the mapping is tabulated in §11.

---

## 11. What the suite actually contains after F1

**229 tests, all passing** (188 at the first F1 gate, 212 after the post-audit
hardening pass, 229 after the final scheduling-race closure). The camera, batch and presentation tiers (`BLOC`, `WIDGET`) are
not written yet — they are gates F3–F5 — so the numbers below are the data,
domain and sync half of §3–§6 only.

| File | Tests | Tier | What would break without it |
| --- | --- | --- | --- |
| `data/database/upload_queue_dao_test.dart` | 26 | `DATA` | Persistence, the finish-batch transaction and its rollback, batch completion, the retryable transition, idempotency |
| `domain/policies/policies_test.dart` | 24 | `UNIT` | Lease boundaries, failure classification, batch rules, retention |
| `data/sync/queue_processor_test.dart` | 29 | `DATA` | The drain loop, both budgets, the disposition it reports, concurrent drains, and a locked database |
| `domain/policies/upload_state_machine_test.dart` | 18 | `UNIT` | Every legal and illegal image transition |
| **`data/database/upload_queue_claim_test.dart`** | **17** | **`DATA`** | **The atomic claim, contention, and stale-lease recovery** |
| `data/sync/work_manager_sync_scheduler_test.dart` | 17 | `UNIT` | The scheduling *policy*: the exact `ExistingWorkPolicy`, the serial chain, backoff, observable failure |
| `data/storage/file_system_capture_store_test.dart` | 14 | `DATA` | Durable capture storage and its failure paths |
| `sync_worker_entrypoint_test.dart` | 14 | `DATA` | The worker's finish / continue / retry decision |
| `data/api/mock_upload_api_test.dart` | 12 | `UNIT` | Determinism of every mock scenario |
| `data/sync/connectivity_drain_trigger_test.dart` | 12 | `UNIT` | Opportunistic rescheduling, observable failure, and *not* gating on link state |
| `data/database/app_database_test.dart` | 11 | `DATA` | Schema, indices, foreign keys, reopen, and the migration scaffold's refusals |
| `domain/usecases/finish_batch_test.dart` | 10 | `DATA` | Transaction-then-schedule ordering; a refused batch scheduling nothing; a `DRAFT` capture scheduling nothing |
| `domain/usecases/record_capture_test.dart` | 7 | `DATA` | File-then-row ordering and its compensation |
| `data/composition/data_layer_test.dart` | 6 | `DATA` | The two composition roots drifting apart |
| `architecture/domain_purity_test.dart` | 5 | `UNIT` | Layering that is claimed but not real |
| `data/identity/uuid_v4_generator_test.dart` | 5 | `UNIT` | Malformed idempotency keys and file names |
| `app_shell_test.dart` | 2 | `WIDGET` | The placeholder shell (pre-existing) |

### The seven scheduling-semantics proofs (`ADR-F19`)

The audit asked for these by name; each is a real test rather than a claim.

| # | Property | Where |
| --- | --- | --- |
| 1 | A retryable upload failure asks WorkManager to retry | `sync_worker_entrypoint_test` — "a queue that will not upload returns false" |
| 2 | A completely drained queue completes successfully | — "a fully drained queue completes, and asks for nothing" |
| 3 | An idle queue completes successfully | — "an empty queue completes, and asks for nothing" |
| 4 | A healthy queue hitting the bound is **not** classified as an upload failure | — "a bound-limited healthy slice does NOT report an upload failure" |
| 5 | The healthy continuation stays scheduled | — "and it leaves a continuation scheduled" |
| 6 | Duplicate-scheduling protection is still sound | — "exactly one continuation per slice"; `work_manager_sync_scheduler_test` — `keep` for entry work, shared unique name for the continuation |
| 7 | Nothing is lost between bounded slices | — "successive slices drain the queue with nothing lost" (60 items, three slices, every item uploaded exactly once) |

Two further cases guard the edges: a continuation that cannot be enqueued falls
back to a retry rather than stranding the backlog, and a time-budget stop is
treated exactly like an item-budget stop.

### The ten scheduling-liveness proofs (`ADR-F21`)

The final audit asked for these by name.

| # | Property | Where |
| --- | --- | --- |
| A | A request with no chain in flight registers one-off work | `work_manager_sync_scheduler_test` — "registers one-off work under a single fixed unique name" |
| B | A request made while a drain may be running is **not** discarded | — "entry work uses append, never keep" (asserts the exact policy, and asserts it is *not* `keep`) |
| C | A continuation joins the same serial chain | — "appends, so it runs after the slice that asked for it"; "shares the unique name" |
| D | Repeated requests cannot create parallel processors | — "every request uses the same unique name"; "a redundant request is a wasted wake-up, never a lost one" |
| E | The atomic claim remains the final duplicate-upload protection | `queue_processor_test` — "two processors draining concurrently upload nothing twice" (two **independent connections**, 8 images, 8 attempts); "a scheduling storm cannot produce a duplicate upload" |
| F | Finishing a batch schedules **after** the transaction commits | `finish_batch_test` — "the images are already PENDING when the request is made" |
| G | A refused finish-batch schedules nothing | — three cases: empty, already finished, non-existent |
| H | Recording a `DRAFT` capture schedules nothing | — "recording captures never asks for a drain"; "a whole session produces exactly one drain request" (20 captures → 1) |
| I | Regaining a link still requests a drain | `connectivity_drain_trigger_test` — "requests a drain when a link is regained" |
| J | A scheduling failure cannot roll back durable work | `finish_batch_test` — "the batch stays queued and its images stay pending" |

The `ExistingWorkPolicy` passed to the injected registration function is asserted
directly, so the fix cannot silently regress to `keep`. **Native WorkManager
ordering itself is not proven here** — that is a device check and is not claimed.

### The retry-hammering audit (`RS-12`)

Asked for as an audit, not a redesign, and answered with a test rather than an
assertion: `queue_processor_test` — "a flaky item is attempted once per slice,
then backs off". A flaky item **is** re-attempted across chained continuations,
once per slice, because the `skip` set spans one pass. It is bounded twice over —
each attempt is separated by a slice of real upload work, and the moment the
healthy backlog runs out the pass makes no progress and returns `retryLater`,
handing timing to WorkManager's backoff. Recorded as residual risk; suppressing
it further would mean a second app-side scheduler, which is `RS-04`.

### Invariant coverage — the checkable claim from §10

Every row of `DATA_MODEL.md` §5 has at least one test that fails if the invariant
is broken.

| # | Invariant | Test |
| --- | --- | --- |
| I1 | No row without a durably written file | `record_capture_test` — "a storage failure creates no row at all" |
| I2 | Finishing a batch is all-or-nothing | `upload_queue_dao_test` — "batch and every image move together", "a failure inside the transaction moves nothing" |
| I3 | At most one draft batch | `upload_queue_dao_test` — "only one draft batch may be open at a time" |
| I4 | No item claimed twice | `upload_queue_claim_test` — the four contention cases |
| I5 | No permanently unclaimable `UPLOADING` row | `upload_queue_claim_test` — "an expired lease is reclaimed, and only once" |
| I6 | A retryable failure destroys nothing | `queue_processor_test` — "keeps the row, keeps the file, and asks to come back" |
| I7 | Marking `UPLOADED` twice is harmless | `upload_queue_dao_test` — "is idempotent — a repeat changes nothing" |
| I8 | A batch completes only when genuinely complete | `upload_queue_dao_test` — the four batch-completion cases |
| I9 | `image_count` matches reality | `upload_queue_dao_test` — "image_count matches the real row count" |
| I10 | A missing file reaches a terminal state | `queue_processor_test` — "does not loop: a second pass finds nothing to do" |

### What the contention test does and does not prove — stated precisely

The claim tests open **genuinely independent SQLite connections to one database
file** (`singleInstance: false`; see `DATA_MODEL.md` §7) and start two — and in
one case eight — claims before awaiting any of them. Exactly one wins, every time,
and the stored row is `UPLOADING` exactly once.

What that proves: the exclusion is enforced by **SQLite statement semantics**, in
the database, across separate connections — not by a Dart lock, a singleton, or a
process-local mutex, none of which could span the two isolates this app really
runs (`FR-08`, `ADR-F04`). An implementation that relied on any of those would
fail this test.

What it does not prove: OS-level parallelism. `sqflite_common_ffi` routes work
through a single background isolate, so the two statements are dispatched
concurrently and executed one after another. The property under test — that the
second `UPDATE` observes zero rows because its `WHERE` clause no longer matches —
is exercised either way, and it is the property that matters. Genuine parallel
execution across two Android isolates is a device check (`SYNC_ENGINE.md` §10,
injection 3), and no claim about it is made from a host run.

`busy_timeout = 5000` is set on every connection for the device case, where the
two isolates *are* parallel and a write can genuinely find the database locked.
