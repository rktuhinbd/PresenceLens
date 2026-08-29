# Flutter Task — Risk Register

**What this document is for:** it names the failures that could damage this
submission, decides in advance what is being done about each, and states how we
will know the mitigation worked. A risk with no verification column is a wish.

Scoring: probability and impact are **Low / Medium / High**. Impact is measured
against *this submission*, not against a hypothetical production deployment.

Owner of every row: the implementing engineer. `VERIF` column references the tier
in [TEST_STRATEGY.md](TEST_STRATEGY.md).

---

## 1. Hardware and platform

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RF-01` | **Android cannot identify physical lenses**, so no truthful `0.5x`/`2x` label is possible (`RESEARCH.md` `FR-04`). | **High** (confirmed) | Medium | Presets derived from the device-reported zoom range; sub-1x shown only if the device reports it; neutral labels for extra back cameras. Limitation documented in README with its evidence. | `UNIT` (`ZoomPresetPolicy`), `DEVICE` (`FQ-01`) |
| `RF-02` | Camera capabilities differ wildly across devices — zoom range, focus support, resolution. | High | Medium | Nothing hard-coded: every bound read from the controller at init. UI hides controls the device cannot support rather than showing inert ones. | `UNIT`, `DEVICE` |
| `RF-03` | **Emulator cameras are synthetic** and will not reveal real zoom/focus behaviour. | High | Medium | Emulator is explicitly *not* accepted as evidence for `FLT-CAM-003/005/008`. Those rows stay `PARTIAL` until a physical device run. | `DEVICE` |
| `RF-04` | Camera lifecycle race — disposed controller rendered, or hardware not released on background. | Medium | **High** (crash class) | Generation counter on switches; release on `paused` only; `inactive` ignored. See `CAMERA_ENGINE.md` §2–3. | `BLOC`, `DEVICE` |
| `RF-05` | Rapid camera switching leaves a dead preview. | Medium | Medium | Same generation guard; last request wins; superseded controllers disposed. | `BLOC` (explicit race case), `DEVICE` |
| `RF-06` | Device has no camera, or the app runs on hardware where init always fails. | Low | Medium | `CameraUnavailable` and `CameraFailure` are designed states; **the Upload Manager stays reachable** so the queue is not trapped. | `BLOC`, `WIDGET` |

## 2. Data and persistence

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RD-01` | **A queued image is lost** — the central requirement fails (`FLT-SYNC-003`). | ~~Medium~~ **Low** | **Critical** | File written to durable storage *before* any row exists; failure paths never delete a row or a file; only confirmed success is terminal. Invariants I1, I6. **Implemented and verified at F1**: `record_capture_test` proves no row survives a storage failure and that a failed insert compensates its own file; `queue_processor_test` proves a retryable failure keeps both row and file. Residual risk is device-only. | `UNIT`, `DATA` **PASS**; `DEVICE` pending |
| `RD-02` | **Two isolates process the same item** — sqflite's synchronisation does not span isolates (`FR-08`). | ~~High~~ **Low** | **High** | Exclusion moved into SQLite: atomic conditional `UPDATE` claim whose `WHERE` re-checks the precondition. No Dart lock is relied upon. **Verified at F1** by `upload_queue_claim_test`, racing two and then eight *independent database connections* to one file: exactly one winner every time, and the loser cannot record an outcome. What that does and does not prove is stated precisely in `TEST_STRATEGY.md` §11. | `DATA` **PASS**; parallel-isolate case is `DEVICE` |
| `RD-03` | **Orphaned `UPLOADING` rows** after process death — queue silently stops draining. | ~~High~~ **Low** | **High** | Lease model: `claimed_at` + a 10-minute expiry folded into the claim query itself, so recovery happens on every drain with no separate startup path. **Verified at F1**: a fresh lease cannot be stolen, an expired one is reclaimed exactly once, and two claimants racing a *stale* row still produce one winner. | `UNIT`, `DATA` **PASS**; `DEVICE` (force-stop) pending |
| `RD-04` | Database write failure mid-transaction leaves inconsistent state. | Low | High | All multi-row changes in a single `transaction {}`; rollback verified by a forced mid-transaction failure. **Executed at F1** — a deliberately invalid statement inside the enqueue transaction leaves batch and images alike untouched. | `DATA` **PASS** |
| `RD-05` | Local image file missing at upload time (external deletion, restore). | Medium | Medium | Classified **permanent**, item leaves the work set. Prevents an un-drainable queue. **Verified at F1**: the transport is never even called, unrelated batches still drain, and a second pass finds nothing to do. | `UNIT`, `DATA` **PASS** |
| `RD-06` | Storage full — capture cannot be written. | Low | Medium | Capture aborts and surfaces the failure; **no row is created**, so no phantom queue item. Invariant I1. | `UNIT`, `DEVICE` |
| `RD-07` | Large images accumulate on disk. | Medium | Low | Grouped per batch for cheap cleanup; optional post-upload file deletion accepted as bonus (`FLT-SYNC-016`). Disk use stated in the README. | `DATA` |
| `RD-08` | Denormalised `image_count` drifts from reality. | Low | Low | Updated only inside the same transaction as the insert; reconciliation test (I9). **Executed at F1.** | `DATA` **PASS** |

## 3. Sync and connectivity

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RS-01` | **Connectivity mistaken for reachability** — the classic `if (wifi) upload()` bug, which fails on exactly the low-bandwidth case the assessment names. | ~~High~~ **Low** | **High** | Connectivity is advisory only: a WorkManager constraint, a reschedule trigger, and UX copy. The upload outcome is the sole authority (`FR-05`, `FLT-SYNC-011`). **Structurally enforced at F1**: `QueueProcessor` takes no `ConnectivityPort` at all, so it *cannot* gate on link state; the only consumers are the scheduler constraint and `ConnectivityDrainTrigger`, which requests a drain and never decides an outcome. | `REVIEW` **PASS**, `UNIT` **PASS**; `DEVICE` pending |
| `RS-02` | **Android background scheduling is nondeterministic** — Doze, App Standby, OEM battery managers can defer work substantially. | **High** (inherent) | Medium | Design depends only on *eventual* execution. Foreground drain gives immediate progress while visible. README states the caveat rather than implying instant sync. | `DEVICE` (`FQ-02`) |
| `RS-09` | **A healthy backlog is scheduled as though it had failed** — a bounded slice returning "retry" puts a queue that is draining perfectly under an escalating backoff curve. | **Certain** as originally implemented | Medium | Found by the F1 audit. `DrainOutcome.disposition` separates progress from failure; a bound-limited slice that made progress enqueues a WorkManager **continuation** and returns success, so backoff is reserved for work that genuinely could not be delivered (`ADR-F19`). | `UNIT`, `DATA` **PASS** — the seven proofs in `TEST_STRATEGY.md` §11 |
| `RS-10` | **iOS ignores the worker's return value**, so the `retryLater` branch reschedules nothing there. | Certain (platform) | Low (Android is the deliverable) | Verified in the plugin's own documentation, not assumed. Recorded as a known limitation; making it work needs an explicitly registered delayed task plus an app-side backoff notion Android does not need. Not attempted — **no iOS behaviour is claimed** (`SYNC_ENGINE.md` §8B). | Not verifiable from this host — `FQ-03` |
| `RS-11` | **A scheduling failure is invisible**, so a queue that quietly stops being drained looks like a queue with nothing to do. | Medium | Medium | `scheduleDrain`/`scheduleContinuation` return a `SchedulingOutcome` instead of `void`, and the scheduler keeps the last error. Still non-throwing: a failure never rolls back durable work. **Residual:** nothing yet *acts* on the signal at startup or resume — that is `FLT-SYNC-012`, gate F5. | `UNIT` **PASS**; reconciliation `TODO` |
| `RS-13` | **A drain request is silently discarded** because `ExistingWorkPolicy.keep` ignores it while a worker is still running — durable `PENDING` work with nothing scheduled to collect it, and every component reporting success. | **Certain** as originally implemented | **High** (defeats "retries automatically") | Found by the final F1 audit. Every registration now uses `append` → Android `APPEND_OR_REPLACE`, so a request made mid-drain becomes a successor instead of vanishing (`ADR-F21`). The exact policy is asserted by test, so it cannot regress to `keep` unnoticed. | `UNIT` **PASS**; native chain ordering is `DEVICE` |
| `RS-12` | **A flaky item is re-attempted once per slice** across a chain of healthy continuations, because the `skip` set spans only one pass. | Medium | Low | Audited rather than engineered away. Bounded twice: every attempt is separated by a slice of real upload work, and the moment healthy work runs out the pass returns `retryLater` and WorkManager's backoff takes over. The count scales with backlog size, not with time, so it cannot become a hot loop. Suppressing it would need a second app-side scheduler — `RS-04`. | `DATA` **PASS** — the bound is asserted, not assumed |
| `RS-14` | **`SQLITE_BUSY` escapes the drain** when both isolates write at once, breaking the processor's "does not throw for an ordinary failure" contract — and the foreground drain has no WorkManager to catch it. | Medium | Medium | Found while proving `RS-13`'s replacement. Contention now ends the pass with `DrainStop.databaseBusy` and the counters so far. Nothing is stranded: a lost claim never happened, and a held claim is released by its lease. Not retried in a loop, which would be `RS-04`. | `DATA` **PASS** |
| `RS-03` | Duplicate work requests accumulate. | Medium | Low | One fixed unique name, so WorkManager runs the chain **one node at a time** — redundant requests become extra idle nodes, never parallel drains. `keep` was dropped in favour of `append` because discarding a request is the worse failure (`RS-13`, `ADR-F21`); an idle node opens the database, finds nothing, and returns in milliseconds. Accumulation is bounded by asking only when durable uploadable work appears — never on capture. | `UNIT` **PASS**; chain ordering is `DEVICE` |
| `RS-04` | An app-side retry timer fights WorkManager's backoff. | ~~Medium~~ **Low** | Medium | No app-side timer exists. The worker returns `retry` and the OS owns timing (`FR-06`). **This risk materialised twice at F1, in two forms the register had not imagined.** First: a drain pass re-claiming the item it had just failed — 25 attempts in a fraction of a second (`ADR-F18`). Second, found by the audit: a bounded slice reporting healthy backlog as failure, which made the OS back off *because* the app was succeeding (`ADR-F19`). Both are now tested. The worker gets a `BackgroundSyncScheduler`, which structurally cannot register entry work — it may only ask for a continuation. | `REVIEW` **PASS**, `UNIT` **PASS** |
| `RS-05` | An item retries forever and never resolves. | Medium | Medium | Retryable vs permanent classification; permanent items leave the work set. Deliberately **no** attempt cap that silently discards an image — that would violate `FLT-SYNC-003`. **Verified at F1**: seven consecutive failures leave the capture intact and still `PENDING`, while a permanent classification makes the worker return success rather than looping. | `UNIT`, `DATA` **PASS** |
| `RS-06` | Success recorded server-side but the response is lost → duplicate upload. | Medium | Low | Client-generated UUID sent as an idempotency key. Correctly a server-side resolution; the client does its part and the README says so. | `REVIEW` |
| `RS-07` | **iOS background execution is far more restricted**, and `BGTaskScheduler` may not run for long periods. | High (inherent) | Low (Android is the deliverable) | iOS configured on a best-effort basis; **no iOS behaviour claimed as verified**. | Not verifiable — `FQ-03` |
| `RS-08` | **iOS cannot be validated from a Windows host at all.** | **Certain** | Low | Stated plainly in the README and in `PROJECT_STATE.md`. No iOS screenshot, claim or evidence will be produced. Scope declared as Android (root `AMB-12`). | N/A — declared limitation |

## 4. Requirements and interpretation

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RR-01` | **The assessment's zoom-preset sentence is truncated in the source PDF** (root `AMB-01`), so the intended preset set is unknowable. | **Certain** | Medium | Device-derived presets are correct under every plausible completion of the sentence. The gap is documented, not silently guessed. | `REVIEW`, `DOC` |
| `RR-02` | The p3 screenshots are treated as prescriptive when the PDF labels them *"Suggested UI"*. | Medium | Medium | Advisory rows are marked `[screenshot]` in `REQUIREMENTS_SPEC.md`; mandated behaviour is never displaced by a decorative element. | `REVIEW` |
| `RR-03` | A bonus feature destabilises or delays a mandatory one. | Medium | High | Only 3 bonus rows accepted, all trivially removable; the execution plan sequences them last (`DECISIONS.md` `ADR-F09`). | `REVIEW` at each gate |
| `RR-04` | "Batch" is never defined by the assessment (root `AMB-10`). | Certain | Low | Defined explicitly and documented so the reviewer sees a decision, not an accident. | `UNIT`, `DOC` |

## 5. Experience and accessibility

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RU-01` | Camera chrome obscures the preview; the app looks like a form with a photo behind it. | ~~Medium~~ **Low** | Medium | Camera-first layout: gradient scrims not panels, contextual controls, nothing in the optical centre. **Closed at the visual gate, 2026-08-29** — the direction was reviewed and approved; the ambiguous close control was removed (`ADR-F13`) and the batch action relabelled (`ADR-F14`). Residual risk is device-only. | `REVIEW` **PASS**; re-checked on hardware at F7 |
| `RU-02` | Controls illegible over a bright scene. | Medium | Medium | Fixed dark control palette independent of system theme; ≥ 4.5:1 against the scrim. | `WIDGET`, `DEVICE` |
| `RU-03` | **Reduced motion disables required feedback** — the focus reticle stops appearing, breaking `FLT-CAM-009`. | Medium | **High** (breaks a mandatory row) | Reduced motion removes *animation*, never *feedback*; an explicit widget test asserts the reticle still appears. | `WIDGET` |
| `RU-04` | State conveyed by colour alone. | Medium | Medium | Every state carries an icon and a word. | `WIDGET`, `REVIEW` |
| `RU-05` | Pinch-only zoom excludes users who cannot perform the gesture. | Medium | Medium | Slider and presets are equal-status controls, not fallbacks (`FLT-UX-013`). Already mandated, which helps. | `WIDGET` |
| `RU-06` | Large text or a small screen pushes the preset row over the preview. | Medium | Low | Camera labels capped at 1.3×; preset row scrolls rather than shrinking below 48 dp. | `WIDGET` |

## 6. Toolchain and process

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RT-01` | A dependency upgrade breaks the build late in the schedule. | Low | High | `pubspec.lock` committed; versions pinned by caret and **resolved and built once at this gate**. No speculative upgrades. | `BUILD` |
| `RT-02` | Flutter Doctor's Android-licence anomaly is mistaken for a real failure and "fixed" destructively. | Medium | Medium | Recorded as a known upstream anomaly (`RESEARCH.md` §1.1). A successful APK build is the authority. No CLI downgrade, no Gradle bump. | `BUILD` |
| `RT-03` | The frozen Android app is accidentally modified. | Low | **High** | `android-attendance/` is read-only by charter; a zero-change check on it is part of every commit gate. | `git diff --stat` before each commit |
| `RT-04` | The Flutter module's Gradle/AGP diverges from the native app's and someone "harmonises" them. | Low | Medium | The two Gradle builds are independent by design (`RESEARCH.md` §1). Recorded so it is not treated as drift. | `REVIEW` |
| `RT-05` | Device QA is deferred so long that it uncovers a design problem too late. | **Medium** | **High** | Device checklists written *now* (§7 of both engine docs) so the hardware session is executable the moment a device is available; the highest-risk device findings (`FQ-01`) affect only labelling, not architecture. | Schedule — `EXECUTION_PLAN.md` |
| `RT-06` | The repository is public before it is ready, or pushed without approval. | Low | High | Repository intentionally private; agents must not push (root `AGENTS.md`). Publication is a human action. | `REVIEW` |

---

## 7. Top five, by exposure

**Status after F1 and its post-audit hardening (2026-08-29).** Items 1 and 3 are
mitigated *and evidenced*; item 2 is enforced by the shape of the code rather
than by discipline. Items 4 and 5 are unchanged — both need hardware.

The register's own lesson from this gate: `RS-04` was scored Medium and described
as "an app-side timer", and it then materialised **twice** in forms the wording
did not cover — a self-re-claiming drain loop (`ADR-F18`, found by a test) and a
healthy backlog scheduled as a failure (`ADR-F19`, found by the audit). A risk
described by its *mechanism* rather than its *effect* is a risk that will be
missed when it arrives wearing something else.


1. **`RD-02` / `RD-03` — cross-isolate concurrency and orphaned claims.** The
   most likely way this app silently stops working, and the least likely to be
   noticed without a targeted test. Mitigated by moving exclusion into SQLite and
   folding lease recovery into the claim itself.
2. **`RS-01` — connectivity mistaken for reachability.** The single most common
   implementation of this feature is wrong in exactly the case the assessment
   names.
3. **`RD-01` — image loss.** Catastrophic if it happens once. Every failure path
   is designed to preserve both row and file.
4. **`RF-01` — dishonest zoom labels.** Low technical impact, high credibility
   impact: fabricating hardware capability is precisely what a detail-oriented
   reviewer would catch.
5. **`RT-05` — deferred device QA.** The schedule risk, mitigated by writing the
   device checklists before the hardware is available.
