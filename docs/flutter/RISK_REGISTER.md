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
| `RF-01` | **Android cannot identify physical lenses**, so no truthful `0.5x`/`2x` label is possible (`RESEARCH.md` `FR-04`). | **High** (confirmed) | Medium | Presets derived from the device-reported zoom range; sub-1x shown only if the device reports it; neutral labels for extra back cameras. **Implemented at F3**: every preset carries a `provenance`, and a test asserts that none claims an optical identity across every range tried. The adapter maps `CameraLensType.unknown` straight through rather than filling in a default. Limitation documented in README with its evidence. | `UNIT` **PASS** (15); **`DEVICE` PASS (F7)** — `FQ-01` confirmed: the HONOR DNP-NX9 reports one back camera with no `lensType`, exactly as predicted; no fabricated label produced. **Disposition: CLOSED.** |
| `RF-02` | Camera capabilities differ wildly across devices — zoom range, focus support, resolution. | High | Medium | Nothing hard-coded: min/max zoom, `focusPointSupported` and `exposurePointSupported` are all read back after `initialize()`. **Implemented at F3**, with `shouldOfferPresets` false on a camera that cannot zoom, focus reported as *unsupported* rather than failed, and exposure attempted only where the platform says it works. | `UNIT` + `BLOC` **PASS**; **`DEVICE` PASS (F7)** — min/max zoom, focus and exposure support all confirmed against the real device. **Disposition: CLOSED.** |
| `RF-03` | **Emulator cameras are synthetic** and will not reveal real zoom/focus behaviour. | High | Medium | Emulator was explicitly *not* accepted as evidence for `FLT-CAM-003/005/008`. **Resolved at F7**: a physical HONOR DNP-NX9 run supplied that evidence for all three, plus a second physical pinch confirmation on a Samsung Galaxy S25. | `DEVICE` **PASS (F7)**. **Disposition: CLOSED.** |
| `RF-04` | Camera lifecycle race — disposed controller rendered, or hardware not released on background. | ~~Medium~~ **Low** | **High** (crash class) | One `_generation` counter guarding *every* async publish, not only switches; release on `paused`/`detached`, `inactive` ignored. **Verified at F3**: a pre-pause initialisation completing after a resume publishes nothing and its session is disposed; an operation completing after `close()` neither throws nor emits. | `BLOC` **PASS** (20); **`DEVICE` PASS (F7)** — camera released and reacquired cleanly across background/resume on the physical device. **Disposition: CLOSED.** |
| `RF-05` | Rapid camera switching leaves a dead preview. | ~~Medium~~ **Low** | Medium | Same generation guard; last request wins; superseded controllers disposed. **Verified at F3** in both orderings: superseded *before* its open began, the camera is never acquired at all; superseded *after*, the late session is disposed and no state is emitted for it. Eight rapid switches leave exactly one live session. | `BLOC` **PASS** (15); **hardware-limited, not separately executed** — the test device reports exactly one back camera (`FQ-01`), so multi-camera switching could not be exercised on it; the guard remains proven only at `BLOC` level. **Disposition: ACCEPTED RESIDUAL** (device coverage limited by the hardware available, not by omission). |
| `RF-06` | Device has no camera, or the app runs on hardware where init always fails. | Low | Medium | `CameraUnavailable` distinguishes "no cameras" from "no *back* camera", and `CameraFailed` is recoverable by `retry()` without leaving the screen. **`BLOC` executed at F3; `WIDGET` executed at F5** — each failure state renders its own panel, an initialisation failure recovers in place, and **the Pending Uploads entry is asserted present in every one of them**, with the queued count named on the panel. The queue is never trapped behind a broken camera. | `BLOC` + `WIDGET` **PASS** (8) |

| `RF-07` | **Android cannot report *permanent* permission denial**, so the specified "Open settings" state is unreachable there (`RESEARCH.md` `FR-12`). | **Certain** (confirmed at F3) | Medium | Found by reading `CameraPermissionsManager.java` while mapping error codes. The state was split into a platform verdict (`isPermanentPerPlatform`, always false on Android) and a *count* of consecutive refusals that lets the UI escalate its **offer** without asserting a verdict (`ADR-F22`). **Built at F5**: the first refusal offers "Allow camera" only; a repeat *adds* "Open settings", which reaches a `MethodChannel` in this app’s own `MainActivity` firing `ACTION_APPLICATION_DETAILS_SETTINGS` — about fifteen lines of Kotlin, no new dependency. `permission_handler` was reconsidered and rejected a third time. | `UNIT` **PASS** (code sets); `WIDGET` **PASS** — no settings offer on the first refusal, an offer on the second, the word "permanently" absent from the copy, and the launcher actually invoked |
| `RF-08` | **The approved documents disagreed about the preview fit** — `CAMERA_ENGINE.md` specified letterboxing, `UX_SPEC.md` a full-bleed viewfinder. Implementing one would have made tap-to-focus subtly wrong under the other. | Medium | Medium | Found at F3. `FocusPointMapper` takes the fit as an input and implements both, unit-tested at the boundaries either way; the UI supplies it and the engine never guesses (`ADR-F23`). Neither approved document had to change its design. | `UNIT` **PASS** (19) |

## 2. Data and persistence

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RD-01` | **A queued image is lost** — the central requirement fails (`FLT-SYNC-003`). | ~~Medium~~ **Low** | **Critical** | File written to durable storage *before* any row exists; failure paths never delete a row or a file; only confirmed success is terminal. Invariants I1, I6. **Implemented and verified at F1**: `record_capture_test` proves no row survives a storage failure and that a failed insert compensates its own file; `queue_processor_test` proves a retryable failure keeps both row and file. Residual risk was device-only, and F7 closed it: the physical device queue survived force-stop and reboot with items pending, confirmed against the live SQLite file. | `UNIT`, `DATA` **PASS**; **`DEVICE` PASS (F7). Disposition: CLOSED.** |
| `RD-02` | **Two isolates process the same item** — sqflite's synchronisation does not span isolates (`FR-08`). | ~~High~~ **Low** | **High** | Exclusion moved into SQLite: atomic conditional `UPDATE` claim whose `WHERE` re-checks the precondition. No Dart lock is relied upon. **Verified at F1** by `upload_queue_claim_test`, racing two and then eight *independent database connections* to one file: exactly one winner every time, and the loser cannot record an outcome. What that does and does not prove is stated precisely in `TEST_STRATEGY.md` §11. | `DATA` **PASS**; parallel-isolate case **confirmed on the physical device at F7** — the real WorkManager worker and the foreground drain never produced a duplicate upload. **Disposition: CLOSED.** |
| `RD-03` | **Orphaned `UPLOADING` rows** after process death — queue silently stops draining. | ~~High~~ **Low** | **High** | Lease model: `claimed_at` + a 10-minute expiry folded into the claim query itself, so recovery happens on every drain with no separate startup path. **Verified at F1**: a fresh lease cannot be stolen, an expired one is reclaimed exactly once, and two claimants racing a *stale* row still produce one winner. | `UNIT`, `DATA` **PASS**; **`DEVICE` (force-stop) PASS (F7)** — queue survived force-stop and reboot with items pending. **Disposition: CLOSED.** |
| `RD-04` | Database write failure mid-transaction leaves inconsistent state. | Low | High | All multi-row changes in a single `transaction {}`; rollback verified by a forced mid-transaction failure. **Executed at F1** — a deliberately invalid statement inside the enqueue transaction leaves batch and images alike untouched. | `DATA` **PASS** |
| `RD-05` | Local image file missing at upload time (external deletion, restore). | Medium | Medium | Classified **permanent**, item leaves the work set. Prevents an un-drainable queue. **Verified at F1**: the transport is never even called, unrelated batches still drain, and a second pass finds nothing to do. | `UNIT`, `DATA` **PASS** |
| `RD-06` | Storage full — capture cannot be written. | Low | Medium | Capture aborts and surfaces the failure; **no row is created**, so no phantom queue item. Invariant I1. | `UNIT` **PASS**; **not separately executed on device this pass — a supplemental fault-injection scenario beyond the critical path (see `SYNC_ENGINE.md` §10 #8). Disposition: ACCEPTED RESIDUAL.** |
| `RD-07` | Large images accumulate on disk. | Medium | Low | Grouped per batch for cheap cleanup; optional post-upload file deletion accepted as bonus (`FLT-SYNC-016`). Disk use stated in the README. | `DATA` |
| `RD-08` | Denormalised `image_count` drifts from reality. | Low | Low | Updated only inside the same transaction as the insert; reconciliation test (I9). **Executed at F1.** | `DATA` **PASS** |

## 3. Sync and connectivity

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RS-01` | **Connectivity mistaken for reachability** — the classic `if (wifi) upload()` bug, which fails on exactly the low-bandwidth case the assessment names. | ~~High~~ **Low** | **High** | Connectivity is advisory only: a WorkManager constraint, a reschedule trigger, and UX copy. The upload outcome is the sole authority (`FR-05`, `FLT-SYNC-011`). **Structurally enforced at F1**: `QueueProcessor` takes no `ConnectivityPort` at all, so it *cannot* gate on link state; the only consumers are the scheduler constraint and `ConnectivityDrainTrigger`, which requests a drain and never decides an outcome. | `REVIEW` **PASS**, `UNIT` **PASS**; **`DEVICE` PASS (F7)** — the airplane-mode-on/off cycle with the app backgrounded drained the queue with zero user action, proving connectivity was never gating the outcome. **Disposition: CLOSED.** |
| `RS-02` | **Android background scheduling is nondeterministic** — Doze, App Standby, OEM battery managers can defer work substantially. | **High** (inherent) | Medium | Design depends only on *eventual* execution. Foreground drain gives immediate progress while visible. The root README states the caveat rather than implying instant sync. **F7 produced a concrete instance of exactly this risk**: a Honor-proprietary `HN_USER_EXPERIENCE` job constraint withheld execution until a device Settings toggle was changed — a real-world confirmation that the risk is genuine, not a theoretical one, and that the design's only real defence (foreground drain, resume/connectivity reconciliation, no promise of *when*) is what actually carried the submission through it. | `DEVICE` (`FQ-02`) — exact latency not separately measured. **Disposition: ACCEPTED RESIDUAL / PLATFORM LIMITATION** — inherent Android/OEM scheduling uncertainty is not something this submission can close, only mitigate and document, which it does. |
| `RS-09` | **A healthy backlog is scheduled as though it had failed** — a bounded slice returning "retry" puts a queue that is draining perfectly under an escalating backoff curve. | **Certain** as originally implemented | Medium | Found by the F1 audit. `DrainOutcome.disposition` separates progress from failure; a bound-limited slice that made progress enqueues a WorkManager **continuation** and returns success, so backoff is reserved for work that genuinely could not be delivered (`ADR-F19`). | `UNIT`, `DATA` **PASS** — the seven proofs in `TEST_STRATEGY.md` §11 |
| `RS-10` | **iOS ignores the worker's return value**, so the `retryLater` branch reschedules nothing there. | Certain (platform) | Low (Android is the deliverable) | Verified in the plugin's own documentation, not assumed. Recorded as a known limitation; making it work needs an explicitly registered delayed task plus an app-side backoff notion Android does not need. Not attempted — **no iOS behaviour is claimed** (`SYNC_ENGINE.md` §8B). | Not verifiable from this host — `FQ-03` |
| `RS-11` | **A scheduling failure is invisible**, so a queue that quietly stops being drained looks like a queue with nothing to do. | ~~Medium~~ **Low** | Medium | `scheduleDrain`/`scheduleContinuation` return a `SchedulingOutcome` instead of `void`, and the scheduler keeps the last error. **Residual closed at F5**: `SyncBloc` now *acts* on it — on startup and on every resume, if durable uploadable work exists, a drain is requested again, and the outcome is carried in the state. A request the platform refuses is therefore retried by the next launch, resume, regained link or finished batch rather than waiting for chance. Still non-throwing: a refusal never rolls back durable work, and the images stay `PENDING`. | `UNIT` **PASS**; reconciliation **PASS** — 4 integration cases over real SQLite, including a refused schedule leaving three pending rows untouched and a later resume succeeding |
| `RS-13` | **A drain request is silently discarded** because `ExistingWorkPolicy.keep` ignores it while a worker is still running — durable `PENDING` work with nothing scheduled to collect it, and every component reporting success. | **Certain** as originally implemented | **High** (defeats "retries automatically") | Found by the final F1 audit. Every registration now uses `append` → Android `APPEND_OR_REPLACE`, so a request made mid-drain becomes a successor instead of vanishing (`ADR-F21`). The exact policy is asserted by test, so it cannot regress to `keep` unnoticed. | `UNIT` **PASS**; native chain ordering **confirmed at F7** — the offline-built queue drained as one coherent pass with the app backgrounded, consistent with a single serial chain rather than parallel or dropped work. **Disposition: CLOSED.** |
| `RS-12` | **A flaky item is re-attempted once per slice** across a chain of healthy continuations, because the `skip` set spans only one pass. | Medium | Low | Audited rather than engineered away. Bounded twice: every attempt is separated by a slice of real upload work, and the moment healthy work runs out the pass returns `retryLater` and WorkManager's backoff takes over. The count scales with backlog size, not with time, so it cannot become a hot loop. Suppressing it would need a second app-side scheduler — `RS-04`. | `DATA` **PASS** — the bound is asserted, not assumed |
| `RS-14` | **`SQLITE_BUSY` escapes the drain** when both isolates write at once, breaking the processor's "does not throw for an ordinary failure" contract — and the foreground drain has no WorkManager to catch it. | Medium | Medium | Found while proving `RS-13`'s replacement. Contention now ends the pass with `DrainStop.databaseBusy` and the counters so far. Nothing is stranded: a lost claim never happened, and a held claim is released by its lease. Not retried in a loop, which would be `RS-04`. | `DATA` **PASS** |
| `RS-03` | Duplicate work requests accumulate. | Medium | Low | One fixed unique name, so WorkManager runs the chain **one node at a time** — redundant requests become extra idle nodes, never parallel drains. `keep` was dropped in favour of `append` because discarding a request is the worse failure (`RS-13`, `ADR-F21`); an idle node opens the database, finds nothing, and returns in milliseconds. Accumulation is bounded by asking only when durable uploadable work appears — never on capture. | `UNIT` **PASS**; chain ordering **confirmed at F7** alongside `RS-13`. **Disposition: CLOSED.** |
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
| `RU-02` | Controls illegible over a bright scene. | Medium | Medium | Fixed dark control palette independent of system theme (`CameraPalette`), applied to every camera control; ≥ 4.5:1 against the scrim. The active zoom preset is accent-on-dark rather than the white-on-translucent-white the prototype gate rejected. **Contrast against a real bright scene is a device judgement and is not claimed from a host test.** | `WIDGET` **PASS** (the palette is applied); **not separately measured against a real bright outdoor scene with a light meter — a supplemental check beyond this submission's scope.** Camera controls were confirmed legible during the F7 physical session, which was not conducted under controlled bright-sun conditions. **Disposition: ACCEPTED RESIDUAL.** |
| `RU-03` | **Reduced motion disables required feedback** — the focus reticle stops appearing, breaking `FLT-CAM-009`. | ~~Medium~~ **Low** | **High** (breaks a mandatory row) | Reduced motion removes *animation*, never *feedback*. Every duration resolves through `AppMotion.resolve`, which collapses to zero — it never removes a widget. **Verified at F5**: with `disableAnimations` true the reticle still appears at the tap and still dismisses, the capture travel is skipped, and the batch count still increments from the committed write. | `WIDGET` **PASS** (2) |
| `RU-04` | State conveyed by colour alone. | ~~Medium~~ **Low** | Medium | Every state carries an icon **and** a word, and the words are resolved by a pure `QueueItemView` that can be asserted directly rather than through a rendered tree. **Verified at F5** in both places: 9 `UNIT` cases over the vocabulary and 8 `WIDGET` cases over the rendered list. | `UNIT` + `WIDGET` **PASS** |
| `RU-05` | Pinch-only zoom excludes users who cannot perform the gesture. | ~~Medium~~ **Low** | Medium | Slider and presets are equal-status controls, not fallbacks (`FLT-UX-013`). **Verified at F5**: both are present whenever the camera reports an adjustable range, both write the same `currentZoom`, and the slider reads out "Zoom 3.4x" rather than a percentage. | `WIDGET` **PASS** |
| `RU-06` | Large text or a small screen pushes the preset row over the preview. | Medium | Low | Camera labels capped at 1.3× via `MediaQuery.withClampedTextScaling`; the preset row scrolls horizontally rather than shrinking below 48 dp. **Verified at F5** at a 2× text scale: nothing overflows and every control is still present. Real-device text settings remain a device check. | `WIDGET` **PASS**; **real-device OS text-scale settings not separately exercised this pass — a supplemental check beyond this submission's scope, since the 2x host-simulated scale already covers the mechanism.** **Disposition: ACCEPTED RESIDUAL.** |

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

**HISTORICAL GATE SNAPSHOT — superseded by the final disposition in §8 below.**
Status after F1 and its post-audit hardening (2026-08-29). Items 1 and 3 are
mitigated *and evidenced*; item 2 is enforced by the shape of the code rather
than by discipline. Items 4 and 5 were unchanged at that point — both needed
hardware, which F7 has since supplied (`RF-01` closed; `RT-05`'s device QA
executed and closed).

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

## 8. Final risk disposition (submission, F7 complete, 2026-08-30)

This is the current-state answer. Every meaningful risk below is resolved to one
of four dispositions:

- **CLOSED** — the risk that was open is now directly evidenced, on the physical
  device, by name.
- **MITIGATED** — design or code prevents the failure; verification is host-level
  and was never expected to need hardware (e.g. a pure-Dart invariant).
- **ACCEPTED RESIDUAL** — a real, standing gap, disclosed rather than hidden;
  usually a supplemental check beyond what this submission's scope requires.
- **PLATFORM LIMITATION** — inherent OS/OEM/toolchain uncertainty that no amount
  of engineering on this codebase can close, only document and design around.
  **These are never marked CLOSED, regardless of how much QA is performed** —
  Android's own scheduling nondeterminism and iOS's inaccessibility from this
  Windows host are structural facts, not project defects.

| Category | Risk IDs | Disposition |
| --- | --- | --- |
| Hardware/platform | `RF-01`, `RF-02`, `RF-03`, `RF-04` | **CLOSED** — F7 physical evidence, see §1 |
| Hardware/platform | `RF-05` | **ACCEPTED RESIDUAL** — the test device has one back camera; multi-camera switching stayed proven only at `BLOC` level |
| Hardware/platform | `RF-06`, `RF-07`, `RF-08` | **MITIGATED** — host-level proof was always the correct and sufficient method; `RF-06`/`RF-07` additionally confirmed live at F7 (§1) |
| Data/persistence | `RD-01`, `RD-02`, `RD-03` | **CLOSED** — F7 physical evidence, see §2 |
| Data/persistence | `RD-04`, `RD-05`, `RD-08` | **MITIGATED** — pure transactional/DAO invariants, correctly host-verified only |
| Data/persistence | `RD-06` | **ACCEPTED RESIDUAL** — storage-full injection not separately run on device this pass; the no-phantom-row invariant is host-tested |
| Data/persistence | `RD-07` | **MITIGATED** — a design choice (grouped batches, optional cleanup), not a defect to close |
| Sync/connectivity | `RS-01`, `RS-03`, `RS-13` | **CLOSED** — F7 physical evidence, see §3 |
| Sync/connectivity | `RS-02` | **PLATFORM LIMITATION** — Android/OEM scheduling nondeterminism is inherent; F7 encountered a concrete instance of it (Honor `HN_USER_EXPERIENCE`) and documented the workaround rather than "closing" what cannot be closed |
| Sync/connectivity | `RS-04`, `RS-05`, `RS-06`, `RS-09`, `RS-11`, `RS-12`, `RS-14` | **MITIGATED** — host-tested design fixes; correctly not device-dependent |
| Sync/connectivity | `RS-07`, `RS-08`, `RS-10` | **PLATFORM LIMITATION** — iOS is explicitly out of scope (`AMB-12`); the Android APK is the assessment deliverable, and no iOS behaviour is claimed as verified anywhere in this repository |
| Requirements/interpretation | `RR-01`–`RR-04` | **MITIGATED / CLOSED** — all four are documentation and design decisions, complete since their respective gates; `RR-03`'s bonus-sequencing outcome is additionally confirmed by F6's implemented bonuses (see [EXECUTION_PLAN.md](EXECUTION_PLAN.md)) |
| Experience/accessibility | `RU-01`, `RU-03`, `RU-04`, `RU-05` | **CLOSED / MITIGATED** — reviewed and confirmed on hardware at F7 (§5) |
| Experience/accessibility | `RU-02`, `RU-06` | **ACCEPTED RESIDUAL** — bright-sun-scene and OS-text-scale device checks were not separately executed this pass; both are supplemental beyond what this submission's scope requires, and the underlying mechanism is host-tested |
| Toolchain/process | `RT-01`–`RT-04`, `RT-06` | **MITIGATED / CLOSED** — process controls that held for the whole build; `RT-06` closed by publication (`SUB-01`) |
| Toolchain/process | `RT-05` | **CLOSED** — device QA executed at F7; no design problem was uncovered late |

**iOS, stated once more for clarity:** every iOS-related risk above is
`PLATFORM LIMITATION`, not `ACCEPTED RESIDUAL` and never `CLOSED`. Physical iOS
validation and a signed IPA were not performed because this assessment was built
and validated from Windows and the requested release deliverable is the Android
APK (root `AMB-12`); this is a scope decision recorded once, not a gap reopened
by every iOS-adjacent row.
