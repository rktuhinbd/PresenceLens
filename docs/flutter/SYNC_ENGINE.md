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
     ▼  user finishes the batch
  ③ batch + all its images → PENDING  (one transaction) ← FLT-BAT-005
     │      ...and only then, never before:
     ▼
  ④ one-off WorkManager task registered                 ← FLT-SYNC-002
     │      constraint: NetworkType.connected
     │      policy:     ExistingWorkPolicy.append
     │      backoff:    EXPONENTIAL, 15 s initial (Android floor: 10 s)
     ▼
  ⑤ OS runs the worker isolate, when it decides to
     │
     ▼
  ⑥ QueueProcessor.drain()                              ← bounded: 25 items
     │     ├── claim one item atomically (DATA_MODEL §4)
     │     ├── verify the durable file is still there
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
| **UX copy** | `SyncBloc` state → the Upload Manager's status chip | Worded as a hint ("Connected · uploading automatically", "Offline · captures are safe"), never as a promise, and never *immediate* or *continuous* — the OS owns the schedule. Exact strings and forbidden phrasings in [UX_SPEC.md](UX_SPEC.md) §4.1. `FLT-UX-010`, `ADR-F14`. |

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

A single fixed unique name (`presencelens.sync.drain`) for every request, entry
and continuation alike. WorkManager runs unique work for a given name **one node
at a time**, so however many requests arrive, no two drains are started in
parallel.

The conflict policy is `ExistingWorkPolicy.append`, **not** `keep`. `keep` would
collapse duplicates, but it discards a request while uncompleted work exists — and
a running worker is uncompleted, which is the liveness race described in §5 under
`ADR-F21`. Redundant requests therefore become extra nodes rather than being
dropped; each finds an empty queue and returns `idle` at once. Correctness never
depended on either: if two drains ever did overlap, the atomic claim is the
boundary.

### What is idempotent

| Operation | Behaviour on repeat |
| --- | --- |
| Registering the drain task | Appends to the one serial chain. A redundant node finds an empty queue and returns `idle`; it is never *discarded*, which is what `keep` did (`ADR-F21`). |
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

**Backoff is the OS's job.** WorkManager provides exponential backoff, clamped
to a 10-second minimum and a 5-hour maximum; this app configures a 15-second
initial delay, which is a choice above the floor rather than the floor itself
(`FR-06`). The worker's levers are its return value **and** whether it enqueues
a successor:

| Worker returns | When | Effect |
| --- | --- | --- |
| `true` (success) | Queue fully drained, or nothing was eligible | Task completes; nothing rescheduled. |
| `true` (success) | Only permanent failures happened | Those items have **left the work set**, so there is nothing to come back for. Returning retry here is how a queue ends up retried forever. |
| `false` (retry) | Items remain outstanding after this pass | WorkManager reschedules per the backoff policy. |
| `false` (retry) | The pass could not even build its data layer | Nothing was lost; ask to come back. |
| `true` (success) | The task name is not ours | Rescheduling a foreign task would only bring it back. |

"Outstanding" is read from the database at the end of the pass, not inferred from
the counters: another isolate may have added or claimed work while this one ran,
and the queue's own state is the honest answer. `FAILED_PERMANENT` is deliberately
*not* outstanding — that is the mechanism by which one unprocessable image stops
being retried (`FLT-ERR-007`).

The mapping is `runDrainTask` in `sync_worker_entrypoint.dart`, kept separate from
the plugin callback so it can be exercised on the host against a real data layer.
**That is not evidence Android ran the worker** — it is evidence of the decision
the worker makes. The former is a device check (§10).

### Backoff is for failure, not for size — `ADR-F19`

The correction the F1 audit forced. `false` means *retry with backoff*, so it has
to be reserved for work that actually failed. A worker that returns `false`
merely because it hit its own item bound tells the OS the same thing as one that
could not upload at all — and WorkManager responds identically, by waiting
longer each time:

```
100 healthy items
  → slice uploads 25 → "retry"  → wait 15 s
  → slice uploads 25 → "retry"  → wait 30 s
  → slice uploads 25 → "retry"  → wait 60 s
  → slice uploads 25 → done
```

Nothing is lost, and the queue still drains — but it drains more slowly the more
successfully it uploads, which is the opposite of the intended behaviour. The
bound is a property of the *worker's execution window*, not of the queue's
health, and the platform was being told otherwise.

`DrainOutcome.disposition` now separates the two:

| Disposition | When | Worker returns |
| --- | --- | --- |
| `idle` | Nothing was eligible, nothing outstanding | `true` |
| `drained` | Everything outstanding was resolved | `true` |
| `continuationRequired` | **Progress was made** and work remains | `true`, after enqueuing a successor |
| `retryLater` | No progress was possible | `false` — backoff is correct here |

"Progress" means at least one item left the work set — an upload, or a permanent
classification. Requiring it is what keeps the continuation chain finite: every
link must actually have moved something, so the chain is bounded by the size of
the queue rather than by anything the app promises.

The residual case is worth naming: outstanding work exists, nothing failed, and
nothing was claimable — because another processor holds fresh leases. That
returns `retryLater`, and correctly so. There was nothing this pass could have
done, and backing off beats spinning; if the holder is dead, its lease lapses
within ten minutes and the next wake-up reclaims the item.

### One serial chain, `append` for everything — `ADR-F21`

Every registration, entry and continuation alike, uses the **same unique name**
with `ExistingWorkPolicy.append`.

**The race this closes.** Entry work originally used `ExistingWorkPolicy.keep`,
which reads well — "a drain is already scheduled, don't add another" — and is
wrong in one specific window. `KEEP` discards a request while *uncompleted* work
exists under that name, and a **running** worker is uncompleted:

```
  worker: ... takes its final outstanding-count reading      (sees 0)
                                    user: finishes a batch
                                    app:  images → PENDING   (committed)
                                    app:  scheduleDrain()
                                    OS:   KEEP → discarded
  worker: returns success — it never saw those rows
  ──────────────────────────────────────────────────────────
  result: durable PENDING work, and nothing scheduled to collect it
```

No data is lost. But nothing is coming back for it either, until an unrelated
trigger — a connectivity change, the next finished batch — happens along. That
is a liveness gap in "retries automatically, without user intervention", and it
has no symptom: every component reports success.

**Why `append` closes it.** It maps to Android's `APPEND_OR_REPLACE` (verified in
the resolved plugin's Kotlin, `FR-06a`). With no chain it starts one; with a
running worker it enqueues a successor. **The request cannot vanish.** It also
starts a fresh chain rather than inheriting a cancelled or failed predecessor,
which is what makes it safe to call from inside the running worker.

**What it costs.** The opposite failure: redundant requests accumulate as extra
nodes instead of collapsing into one. That is deliberately the cheaper mistake —
a redundant node finds an empty queue and returns `idle` immediately, whereas a
discarded request is a queue that silently stops draining. Accumulation is kept
small by §8C: the app asks only when durable *uploadable* work appears.

**What is preserved.** One unique name still means one **serial chain**:
WorkManager runs it a node at a time, so the scheduler never asks for two
parallel drains, and ordering is kept (`RS-03`). And correctness never depended
on this anyway — if two drains ever did overlap, the atomic claim is the
boundary, proven by two processors on independent connections draining one queue
with no image uploaded twice.

**Not a timer, not a loop.** This is WorkManager's own continuation mechanism;
the app adds no scheduler of its own.

## 8C. When the app asks for a drain

Scheduling is requested when **durable uploadable work comes into existence**,
and at no other time. There are exactly two call sites:

| Trigger | Call site | Why |
| --- | --- | --- |
| A batch is finished | `FinishBatch`, **after** the transaction commits | This is the moment `DRAFT` images become `PENDING` — the moment uploadable work exists |
| A link is regained | `ConnectivityDrainTrigger` | Turns a likely-useful moment into an attempt sooner; advisory, never a gate |

Deliberately **not** a trigger: **capturing an image**. A capture is `DRAFT` until
its batch is finished, and a `DRAFT` image is not uploadable — so a worker woken
by the shutter would find nothing to do. `RecordCapture` takes no scheduler at
all, so a twenty-photo session produces **one** drain request rather than twenty
idle nodes on the chain. This matters more under `append` than it did under
`keep`, because requests no longer collapse (`ADR-F21`).

**Added at F5, closing `RS-11`: reconciliation on startup and resume**
(`FLT-SYNC-012`). `SyncBloc` reads the queue when the app launches and on every
resume; if durable uploadable work exists, it asks for a drain again. So a
scheduling request the platform refused is retried at the next launch, resume,
regained link or finished batch, rather than waiting on chance. It is idempotent
and non-throwing, and it asks for nothing when the queue is empty — waking a
worker for no work is a battery cost with no benefit.

The same trigger also runs **one foreground drain pass** while the app is visible
(`ADR-F25`), so a user watching the Upload Manager sees progress instead of
waiting on OS scheduling. One pass, never a loop: the pass is already bounded by
an item and a time budget, and chaining passes would be an app-side schedule
competing with WorkManager's (`RS-04`). It is safe only because the claim is
atomic — the foreground and the worker are two claimants of one queue.

### Ordering rule at the call site

Durable transaction first, scheduling second, never the reverse:

* if the transaction is refused — an empty batch, an already-finished one —
  **nothing is scheduled**, because there is no work to schedule for;
* if scheduling fails, the batch stays `QUEUED` and its images stay `PENDING`.
  `FinishBatch` returns the `SchedulingOutcome` instead of throwing, so a lost
  wake-up is visible without ever being mistaken for a lost photo.

If the continuation cannot be enqueued, the worker falls back to returning
`false`. That is deliberately the safe direction: a backlog delayed by backoff is
recoverable, a backlog nobody is coming back for is not.

The **background isolate cannot request entry work at all** —
`BackgroundSyncScheduler` suppresses `scheduleDrain` and forwards only
`scheduleContinuation`. Enforcing it in a type rather than by convention means a
future caller inside the worker cannot reintroduce `RS-04` by accident.

### Two budgets, not one

A pass stops on whichever comes first:

| Budget | Value | Why |
| --- | --- | --- |
| Items | 25 | A simple, predictable slice size |
| Time | 8 minutes | Android stops a worker at roughly ten minutes. Twenty-five slow uploads can exceed that, and a worker killed mid-item reports *nothing* — the pass is cut off rather than finishing and asking for a continuation |

The time budget is checked between items, never inside one: abandoning an upload
half-way would leave a claim to expire rather than a clean result. Either stop
reports `continuationRequired` when progress was made, so neither is mistaken
for a failure.

A third stop exists for a condition rather than a budget: **`databaseBusy`**.
Two isolates competing for a write lock is the designed situation, not an error,
so a locked database ends the pass with whatever it achieved instead of throwing
out of `drain` — which promises not to throw for an ordinary condition, and
which the foreground drain will call with no WorkManager to catch anything.
Nothing is stranded: a claim that lost the race never happened, and an item
already claimed is released by its lease.

### One pass does not retry what it just tried

A retryable failure returns a row to `PENDING`, which makes it *immediately*
claimable again. The first implementation therefore re-claimed the item it had
just failed on the very next iteration and hammered it until the per-invocation
bound — one offline image, twenty-five attempts, a fraction of a second. That is
an app-side retry loop by accident, competing with the backoff above.

`drain` now keeps the ids it has returned to the queue during this pass and
excludes them from the claim (`DATA_MODEL.md` §4, `ADR-F18`). They stay `PENDING`
and are picked up by a **later** invocation, which is what "retry automatically"
was always supposed to mean.

**What that does not prevent, stated honestly (`RS-12`).** The `skip` set spans
one pass. While a healthy backlog keeps each slice making progress, each slice
also re-attempts a flaky item once — so across a chain of continuations the item
is attempted about once per slice. Two things bound it, and both are tested:
every attempt is separated by a slice of *real upload work*, and the moment the
healthy backlog runs out the next slice makes no progress and returns
`retryLater`, handing timing to WorkManager's exponential backoff. The count is
bounded by the size of the backlog, not by time, so it cannot become a hot loop.
Suppressing it further would mean a second app-side scheduler, which is exactly
what `RS-04` warns against; it is recorded as residual risk instead.

### Bounding one invocation

`drain` processes at most **25** items, or eight minutes' worth, whichever comes
first, and reports which budget ended the pass (`DrainStop`). A background
invocation has a limited execution window, so an unbounded loop over a large
queue risks being killed part-way through an item instead of finishing cleanly
and reporting honestly. Stopping at a budget hands the decision back to the OS,
which already owns scheduling — as a **continuation**, not as a failure.

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

`failThenSucceed(n)` reads the count from the image's own **persisted**
`attempt_count`, not from memory. That matters twice over: the behaviour is
identical after a process death, and identical in the worker isolate, which holds
no memory of anything the foreground did.

The mock also records the idempotency keys it is handed. A real backend would
deduplicate on them; recording them is how the tests show the client does its half
of that contract (`RS-06`). No claim is made that the client can resolve an
ambiguous failure on its own — it cannot, and pretending otherwise would be the
bug.

---

## 8. Foreground behaviour

The foreground is not a second sync engine. It:

1. Renders queue state by watching the database (`SyncBloc`, `FLT-BAT-003`).
2. Re-registers the drain task on resume and on a connectivity improvement
   (`FLT-SYNC-012`) — cheap and idempotent.
3. May run `QueueProcessor.drain()` directly while visible, so a user watching the
   screen sees progress rather than waiting on OS scheduling. **This is safe
   precisely because of the atomic claim** — the foreground drain and the worker
   are just two claimants of the same queue.
4. Offers an optional manual "Retry now" that only triggers a drain. It is an
   accelerator, never the mechanism (`FLT-SYNC-014`).

---

## 8B. Platform retry semantics — Android and iOS differ

Verified against the installed plugin, not assumed.

| | Android | iOS |
| --- | --- | --- |
| Returning `false` from the handler | WorkManager reschedules the task under the configured backoff policy | **Ignored.** `workmanager`'s own documentation for `BackgroundTaskHandler` states the return value is ignored on iOS, and that a failed attempt has to be rescheduled explicitly with `registerOneOffTask` |
| Returning `true` | The task completes | The task completes |
| A continuation via `registerOneOffTask` | `APPEND_OR_REPLACE` chains it after the current work (`FR-06a`) | `BGTaskScheduler` has no chaining concept; a submitted request is opportunistic and may not run for a long time |

**Consequence, stated as a residual risk rather than solved here.** On iOS the
`retryLater` branch currently does nothing: the worker returns `false` and
nothing reschedules it. The `continuationRequired` branch happens to be the one
that *does* survive, because it registers explicit work. Making the retry branch
work on iOS means registering a delayed one-off task instead of relying on the
return value, plus an app-side notion of backoff that Android deliberately does
not need.

That is not attempted in this gate. Android is the mandated deliverable
(`AMB-12`), the change would add a second scheduling path to the one platform
that cannot be tested from this host at all, and **no iOS background behaviour is
claimed anywhere in this repository** (`RS-07`, `RS-08`, `FQ-03`). Recorded so
the gap is a known limitation rather than an assumption that Android's semantics
carry over.

## 9. Scheduling honesty

Android does not guarantee *when* a constrained one-off task runs. Doze, App
Standby buckets, and OEM battery managers all defer work, sometimes for a long
time. The design depends only on **eventual** execution, and the root
[README.md](../../README.md) states this plainly ("WorkManager schedules
constrained background drains; connectivity regain and lifecycle reconciliation
opportunistically schedule further work") rather than implying instant background
sync. F7 produced a concrete instance of exactly this class of deferral: a
Honor-proprietary `HN_USER_EXPERIENCE` job constraint withheld execution
indefinitely until a device Settings toggle was changed — documented as a
device-specific platform condition, not a code defect, in
[PROJECT_STATE.md](../PROJECT_STATE.md) and [AI_USAGE.md §F7](../AI_USAGE.md).

On iOS, `BGTaskScheduler` is more restrictive still and may not run for extended
periods. The identifier and background modes are configured
(`io.github.rktuhinbd.presencelens.capture.sync`), but **no iOS behaviour is
claimed as verified** — it cannot be tested from a Windows host (`FQ-03`).

---

## 10. Failure-injection matrix

The `DEVICE` verification plan for this engine (`FLT-TEST-009`). **Executed at
gate F7 (2026-08-30) on a physical HONOR DNP-NX9 (Android 16)**, and the critical
scenario (#1 + #2 combined) was **re-executed at the documentation-reconciliation
session** with a fresh install of the published v1.0.0 APK, so the evidence below
comes from the exact binary a reviewer downloads.

**The critical physical path — offline → capture → finish batch offline → app
backgrounded → connectivity restored → automatic drain with no retry press — is
`PASS` on HONOR.** It required first clearing the Honor-specific
`HN_USER_EXPERIENCE` OEM background-launch restriction in device Settings
(App launch → "Manage manually", all three sub-toggles on); this is documented as
a **device-specific platform condition**, not a code defect — no manifest or
code-level fix exists, and `adb shell am force-stop` reverts the manual grant back
to "automatic," so it has to be reapplied after every force-stop during a testing
session (see [PROJECT_STATE.md](../PROJECT_STATE.md) and
[AI_USAGE.md §F7](../AI_USAGE.md)).

| # | Inject | Expected | Final evidence / Result |
| --- | --- | --- | --- |
| 1 | Airplane mode on, enqueue a batch | Items rest `PENDING`, list says waiting; no data loss | **PASS** — five images captured offline, finished into a batch, and shown "Waiting for connection" per item with no fabricated progress |
| 2 | Airplane mode off, app **backgrounded** | Queue drains with no user action — the core requirement | **PASS** — all five items drained to `Synced` automatically once the HONOR OEM constraint above was cleared; re-confirmed at the documentation-reconciliation session |
| 3 | Force-stop mid-upload, relaunch | Item recovers after the lease and completes | **PASS** — force-stop/relaunch preserved correct durable state, confirmed against the live SQLite file |
| 4 | Enqueue two batches while offline, then restore | Both drain, oldest capture first | **Not separately executed this pass.** Multiple batches were captured and enqueued independently and confirmed to drain (scenario 2), but the specific two-batch, oldest-first ordering claim was not itemised on device this gate; ordering determinism is `DATA`/`UNIT`-tested on the host |
| 5 | Delete an image file externally, then drain | That item → `FAILED_PERMANENT`; others unaffected | **Not separately executed this pass** — a supplemental fault-injection scenario beyond the critical path; the transition itself is `UNIT`/`DATA`-tested on the host |
| 6 | `alwaysFailRetryable`, leave running | Attempt count rises; file and row persist; nothing is dropped | **HOST VERIFIED only** — proven by `UNIT`/`DATA` tests (seven consecutive failures discard nothing); not separately re-run against the deterministic mock API on device this pass |
| 7 | Reboot with items pending | WorkManager re-registers; queue drains | **PASS** — queue survived force-stop and reboot with items pending, confirmed on the physical device |
| 8 | Fill storage, then capture | Capture fails cleanly with a message; no phantom row (`FLT-ERR-005`) | **Not separately executed this pass** — a supplemental fault-injection scenario; the no-phantom-row invariant is `UNIT`/`DATA`-tested on the host |
