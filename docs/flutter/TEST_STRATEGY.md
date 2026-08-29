# Flutter Task — Test Strategy

**What this document is for:** it decides *what gets tested and why*, before the
code exists, so that test effort lands on the failures that would actually cost
the submission — not on whatever is easiest to assert.

Risk-based, in the spirit of ISO/IEC/IEEE 29119-1:2022. *An application of
risk-based verification concepts, not a claim of certification.*

Covers `FLT-TEST-001` … `FLT-TEST-009`.

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
| `DEVICE` | Physical device | minutes | Hardware — **deferred** |

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
| `ZoomPolicy` | Clamp below min, above max, inside; pinch scale → zoom anchored at gesture start; zero/negative scale rejected. |
| `ZoomPresetPolicy` | Range `[1,1]` → only `1x`; `[0.5, 8]` → sub-1 preset uses the **reported** minimum, not `0.5` by convention; `[1, 3]` → `2x` but no `5x`; presets never exceed the range; **no preset ever asserts an optical multiplier when `lensType` is `unknown`** (`FLT-CAM-016`). |
| `FocusPointMapper` | Centre tap → `(0.5, 0.5)`; corners; letterboxed preview taller and wider than its box; tap on a letterbox band → `null`; exact boundary pixels. |
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

| Target | Cases |
| --- | --- |
| `CameraCubit` init | Success → `CameraReady` with capabilities; empty camera list → `CameraUnavailable`; permission denied → the denied state; permanent denial → its own state; other exception → `CameraFailure`. |
| `CameraCubit` zoom | Pinch, slider and preset all converge on one value; clamped at both ends; **a preset selection is reflected in the slider's state and vice versa** (`FLT-CAM-006`). |
| `CameraCubit` capture | Sets `isCapturing`; a second capture while in flight is ignored (`FLT-CAM-014`); clears the flag on both success and failure. |
| `CameraCubit` switch race | Two rapid switches → only the last camera is active; the superseded controller is disposed; no state emitted for the stale generation (`FLT-CAM-013`). |
| `CameraCubit` lifecycle | `paused` releases; `resumed` re-acquires; `inactive` changes nothing. |
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

---

## 7. `DEVICE` — deferred

Cannot be run from this host. Enumerated so the hardware session is a checklist,
not an exploration. Full lists: [CAMERA_ENGINE.md](CAMERA_ENGINE.md) §8 and
[SYNC_ENGINE.md](SYNC_ENGINE.md) §10.

Headlines:

1. Real preview, real zoom limits, real pinch and tap-focus.
2. `availableCameras()` output on a genuine multi-lens device (`FQ-01`) — this
   also validates the preset policy against real hardware.
3. Background/foreground lifecycle with a live camera.
4. **Airplane mode → enqueue → restore, with the app backgrounded.** The single
   most important device test; it is the mandated requirement.
5. Force-stop mid-upload → relaunch → lease recovery.
6. Reboot with items pending.

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
