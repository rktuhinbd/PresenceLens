# Flutter Task — Resilient Sync Engine

**What this document is for:** it specifies how a captured image reaches the API
and what happens at every point it can fail, so that "automatically retry without
user intervention" is a designed property rather than a hope.

Covers `FLT-SYNC-001` … `FLT-SYNC-016`, `FLT-ERR-006` … `FLT-ERR-008`.

---

## 1. The pipeline

```
  capture
     │
     ▼
  ① file written to app-owned durable storage           ← FLT-CAM-015
     │                                                     (file first, always)
     ▼
  ② queue row inserted, DRAFT                           ← FLT-SYNC-001
     │
     ▼  user enqueues the batch
  ③ batch + all its images → PENDING  (one transaction) ← FLT-BAT-005
     │
     ▼
  ④ one-off WorkManager task registered                 ← FLT-SYNC-002
     │      constraint: NetworkType.connected
     │      policy:     ExistingWorkPolicy.keep
     │      backoff:    EXPONENTIAL, 15 s
     ▼
  ⑤ OS runs the worker isolate, when it decides to
     │
     ▼
  ⑥ QueueProcessor.drain()
     │     ├── claim one item atomically (DATA_MODEL §4)
     │     ├── attempt the real upload
     │     ├── classify the outcome
     │     └── transition durably
     │
     ▼
  ⑦ success → UPLOADED, batch completed when empty
     retryable → PENDING (attempt_count + 1), file intact
     permanent → FAILED_PERMANENT
     │
     ▼
  ⑧ items still outstanding? → return retry() and let the OS reschedule
```

Steps ① and ② are ordered so that a crash between them leaves an orphan file, not
a queue row pointing at nothing (`DATA_MODEL.md` §6).

---

## 2. What is explicitly not implemented

```dart
// NOT THIS:
if (connectivity == ConnectivityResult.wifi) {
  upload();
}
```

`connectivity_plus` states outright that connection type *"does not guarantee that
there is an Internet access"* (`RESEARCH.md` `FR-05`). A captive portal, a
saturated cell link, or a router with no upstream all report a healthy link.

Worse, the low-bandwidth case in `FLT-SYNC-003` is *precisely* the case where the
link is present and the upload still fails. Gating on link type would defeat the
requirement it appears to serve.

Also not implemented: a polling loop, an app-side retry timer, or any claim of
"continuous connectivity monitoring". Nothing in this app runs while it is not
scheduled to run.

---

## 3. The three legitimate uses of connectivity

Connectivity is advisory. It is allowed to influence *when we bother trying* and
*what we tell the user*, never *whether an upload succeeded*.

| Use | Mechanism | Why it is honest |
| --- | --- | --- |
| **Scheduling constraint** | `Constraints(networkType: NetworkType.connected)` on the work request | Asks the OS not to wake the worker with no link at all. Saves wake-ups; proves nothing. |
| **Opportunistic reschedule** | `onConnectivityChanged` transition from "none" to anything, while the app is foreground → re-register the drain task | Turns a likely-useful moment into an attempt sooner. If the link is unusable, the attempt fails and re-queues; nothing breaks. |
| **UX copy** | `SyncCubit` state → the Upload Manager's status chip | Worded as a hint ("Connected · uploading automatically", "Offline · captures are safe"), never as a promise, and never *immediate* or *continuous* — the OS owns the schedule. Exact strings and forbidden phrasings in [UX_SPEC.md](UX_SPEC.md) §4.1. `FLT-UX-010`, `ADR-F14`. |

**The upload attempt and its outcome are the only authority** (`FLT-SYNC-011`).

---

## 4. Concurrency and idempotency

### Preventing two workers on one item

Fully specified in [DATA_MODEL.md](DATA_MODEL.md) §4. Summarised: the UI isolate
and the worker isolate hold **separate database connections** (`FR-08`), so
mutual exclusion is enforced by an atomic conditional `UPDATE` whose `WHERE`
clause re-checks the precondition. Two claimants race; SQLite picks one; the loser
observes zero affected rows and moves on.

### Preventing duplicate workers

`ExistingWorkPolicy.keep` on a single fixed unique name (`presencelens.sync.drain`).
A second registration while one is pending is ignored by WorkManager itself
(`FR-07`), so the app can call "make sure a drain is scheduled" freely — on
enqueue, on connectivity improvement, on resume — without accumulating work.

### What is idempotent

| Operation | Behaviour on repeat |
| --- | --- |
| Registering the drain task | No-op (`ExistingWorkPolicy.keep`). |
| Claiming an item | Second claimant affects 0 rows. |
| Marking `UPLOADED` | Guarded by `WHERE status != 'UPLOADED'`; affects 0 rows. |
| Completing a batch | Recomputed from outstanding count; safe to re-evaluate. |
| Uploading the same image twice | Each image carries its client-generated UUID as an **idempotency key**, so a real server could deduplicate an ambiguous retry. The mock records it; a genuine backend would honour it. |

The ambiguous-failure case is worth naming: if a request succeeds server-side but
the response is lost, this app will retry and the server will see the same
idempotency key. That is the correct division of responsibility — the client
cannot resolve it alone, and pretending otherwise would be the bug.

---

## 5. Retry and backoff

Classification (`FailureClassifier`, pure Dart — `FLT-SYNC-006`):

| Outcome | Category | Result |
| --- | --- | --- |
| API reports success | `success` | → `UPLOADED` |
| Timeout | `retryable` | → `PENDING`, attempt + 1 |
| Connection/socket error | `retryable` | → `PENDING`, attempt + 1 |
| Server 5xx | `retryable` | → `PENDING`, attempt + 1 |
| Server 4xx (rejected payload) | `permanent` | → `FAILED_PERMANENT` |
| Local file missing | `permanent` | → `FAILED_PERMANENT` (`FLT-ERR-007`) |
| Unknown exception | `retryable` | → `PENDING`. Fails **open** toward retrying: keeping a file is cheaper than discarding one. |

**Backoff is the OS's job.** WorkManager provides exponential backoff with an
enforced 15-second floor (`FR-06`). The worker's only lever is its return value:

| Worker returns | When | Effect |
| --- | --- | --- |
| `Future.value(true)` (success) | Queue fully drained | Task completes; nothing rescheduled. |
| `Future.value(false)` (retry) | Items remain after this pass | WorkManager reschedules per the backoff policy. |

There is deliberately **no `attempt_count` ceiling that abandons an item.**
`attempt_count` is recorded for display (`FLT-UX-009`) and diagnosis, not as a
give-up threshold. The requirement is that images *remain queued* until they
upload (`FLT-SYNC-003`); silently dropping an image after N attempts would violate
it. Only a genuinely permanent classification removes an item from the work set.

The p3 screenshot's "ATTEMPT 3/5" is treated as advisory presentation. A
denominator is shown only if a cap is ever introduced; otherwise the attempt count
is shown alone rather than inventing a limit that does not exist.

---

## 6. Process death

The scenario the whole design is built around: the app is killed mid-upload.

| Moment of death | Durable state left behind | Recovery |
| --- | --- | --- |
| After file write, before insert | Orphan file | Invisible to the queue. Reclaimed by an optional sweep; costs disk only. |
| After insert, before enqueue | `DRAFT` batch + images | Batch reopens on next launch; the user enqueues when ready. |
| After enqueue, before the worker runs | `PENDING` items + a registered task | WorkManager persists its own queue across process death and reboot. The task runs later. |
| **Mid-upload** | Item stuck `UPLOADING` with a `claimed_at` | **The lease expires** (10 min) and the very next claim query reclaims it (`FLT-SYNC-009`). No sweep, no startup hook, no special case. |
| After upload succeeded, before the row was updated | Item still `UPLOADING`, already on the server | Reclaimed and retried; the idempotency key lets the server recognise it. |

Recovery being a property of the *claim query* rather than of a startup routine is
the point: there is no code path that can be forgotten, and it works identically in
both isolates.

---

## 7. The mock API

No API is provided (p3 Note), so `UploadApi` is a real interface with a
deterministic implementation (`FLT-SYNC-005`, [root ADR-008](../DECISIONS.md#adr-008)).

**Deterministic, never random.** A reviewer must be able to demonstrate the
failure path on demand; a random mock makes the most important behaviour
unreproducible.

```dart
abstract interface class UploadApi {
  Future<UploadOutcome> upload(QueuedImage image);
}
```

`MockUploadApi` is driven by an explicit `MockScenario`:

| Scenario | Behaviour | Demonstrates |
| --- | --- | --- |
| `alwaysSucceed` | Every upload succeeds after a short delay | The happy path |
| `alwaysFailRetryable` | Every upload fails as a timeout | `FLT-SYNC-003` — nothing is lost |
| `failThenSucceed(n)` | First *n* attempts fail, then succeed | `FLT-SYNC-004` — automatic recovery |
| `failPermanently` | Rejected outright | `FLT-ERR-007` terminal handling |
| `offlineAware` | **Default.** Consults connectivity: fails as `retryable` when there is no link, succeeds otherwise | Makes airplane-mode → online demonstrable on a real device with no code change |

`offlineAware` is the default precisely because it makes the mandated demo
(`FLT-SYNC-004`) work naturally on a device: toggle airplane mode, watch items
queue, toggle back, watch them drain untouched. Note the direction of the
dependency — connectivity here is standing in for *the server's* reachability
inside the fake transport. It is not the app deciding whether to try.

The active scenario is selectable and documented in the README so a reviewer can
force any path.

---

## 8. Foreground behaviour

The foreground is not a second sync engine. It:

1. Renders queue state by watching the database (`SyncCubit`, `FLT-BAT-003`).
2. Re-registers the drain task on resume and on a connectivity improvement
   (`FLT-SYNC-012`) — cheap and idempotent.
3. May run `QueueProcessor.drain()` directly while visible, so a user watching the
   screen sees progress rather than waiting on OS scheduling. **This is safe
   precisely because of the atomic claim** — the foreground drain and the worker
   are just two claimants of the same queue.
4. Offers an optional manual "Retry now" that only triggers a drain. It is an
   accelerator, never the mechanism (`FLT-SYNC-014`).

---

## 9. Scheduling honesty

Android does not guarantee *when* a constrained one-off task runs. Doze, App
Standby buckets, and OEM battery managers all defer work, sometimes for a long
time. The design depends only on **eventual** execution, and the README will say
so plainly rather than implying instant background sync.

On iOS, `BGTaskScheduler` is more restrictive still and may not run for extended
periods. The identifier and background modes are configured
(`io.github.rktuhinbd.presencelens.capture.sync`), but **no iOS behaviour is
claimed as verified** — it cannot be tested from a Windows host (`FQ-03`).

---

## 10. Failure-injection matrix

The `DEVICE` verification plan for this engine (`FLT-TEST-009`).

| # | Inject | Expected |
| --- | --- | --- |
| 1 | Airplane mode on, enqueue a batch | Items rest `PENDING`, list says waiting; no data loss |
| 2 | Airplane mode off, app **backgrounded** | Queue drains with no user action — the core requirement |
| 3 | Force-stop mid-upload, relaunch | Item recovers after the lease and completes |
| 4 | Enqueue two batches while offline, then restore | Both drain, oldest capture first |
| 5 | Delete an image file externally, then drain | That item → `FAILED_PERMANENT`; others unaffected |
| 6 | `alwaysFailRetryable`, leave running | Attempt count rises; file and row persist; nothing is dropped |
| 7 | Reboot with items pending | WorkManager re-registers; queue drains |
| 8 | Fill storage, then capture | Capture fails cleanly with a message; no phantom row (`FLT-ERR-005`) |
