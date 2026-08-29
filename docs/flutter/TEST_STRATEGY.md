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
in a minute.
