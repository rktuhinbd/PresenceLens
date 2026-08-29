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
| `RD-01` | **A queued image is lost** — the central requirement fails (`FLT-SYNC-003`). | Medium | **Critical** | File written to durable storage *before* any row exists; failure paths never delete a row or a file; only confirmed success is terminal. Invariants I1, I6. | `UNIT`, `DATA`, `DEVICE` |
| `RD-02` | **Two isolates process the same item** — sqflite's synchronisation does not span isolates (`FR-08`). | **High** if naively implemented | **High** | Exclusion moved into SQLite: atomic conditional `UPDATE` claim whose `WHERE` re-checks the precondition. No Dart lock is relied upon. | `DATA` (contended-claim test) |
| `RD-03` | **Orphaned `UPLOADING` rows** after process death — queue silently stops draining. | **High** without mitigation | **High** | Lease model: `claimed_at` + a 10-minute expiry folded into the claim query itself, so recovery happens on every drain with no separate startup path. | `UNIT`, `DATA`, `DEVICE` (force-stop) |
| `RD-04` | Database write failure mid-transaction leaves inconsistent state. | Low | High | All multi-row changes in a single `transaction {}`; rollback verified by a forced mid-transaction failure. | `DATA` |
| `RD-05` | Local image file missing at upload time (external deletion, restore). | Medium | Medium | Classified **permanent**, item leaves the work set. Prevents an un-drainable queue. | `UNIT`, `DATA` |
| `RD-06` | Storage full — capture cannot be written. | Low | Medium | Capture aborts and surfaces the failure; **no row is created**, so no phantom queue item. Invariant I1. | `UNIT`, `DEVICE` |
| `RD-07` | Large images accumulate on disk. | Medium | Low | Grouped per batch for cheap cleanup; optional post-upload file deletion accepted as bonus (`FLT-SYNC-016`). Disk use stated in the README. | `DATA` |
| `RD-08` | Denormalised `image_count` drifts from reality. | Low | Low | Updated only inside the same transaction as the insert; reconciliation test (I9). | `DATA` |

## 3. Sync and connectivity

| ID | Risk | P | I | Mitigation | Verification |
| --- | --- | --- | --- | --- | --- |
| `RS-01` | **Connectivity mistaken for reachability** — the classic `if (wifi) upload()` bug, which fails on exactly the low-bandwidth case the assessment names. | **High** if naive | **High** | Connectivity is advisory only: a WorkManager constraint, a reschedule trigger, and UX copy. The upload outcome is the sole authority (`FR-05`, `FLT-SYNC-011`). | `REVIEW`, `UNIT`, `DEVICE` |
| `RS-02` | **Android background scheduling is nondeterministic** — Doze, App Standby, OEM battery managers can defer work substantially. | **High** (inherent) | Medium | Design depends only on *eventual* execution. Foreground drain gives immediate progress while visible. README states the caveat rather than implying instant sync. | `DEVICE` (`FQ-02`) |
| `RS-03` | Duplicate work requests accumulate. | Medium | Medium | One fixed unique name + `ExistingWorkPolicy.keep`; the OS ignores redundant registrations (`FR-07`). | `REVIEW`, `DEVICE` |
| `RS-04` | An app-side retry timer fights WorkManager's backoff. | Medium | Medium | No app-side timer exists. The worker returns `retry` and the OS owns timing (`FR-06`). | `REVIEW` |
| `RS-05` | An item retries forever and never resolves. | Medium | Medium | Retryable vs permanent classification; permanent items leave the work set. Deliberately **no** attempt cap that silently discards an image — that would violate `FLT-SYNC-003`. | `UNIT`, `DATA` |
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
