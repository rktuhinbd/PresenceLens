# Execution Plan

**Historical execution plan — all gates complete.** This document fixed the order
of work and the exit criteria for Android's G0.1–G3, plus the original G4–G9 gate
numbering for what became the Flutter track. G3 was the last gate this numbering
actually governed: Android continued under its own G3.5–G3.8 polish sequence
([PROJECT_STATE.md](PROJECT_STATE.md)), and Flutter was replanned and executed
under [flutter/EXECUTION_PLAN.md](flutter/EXECUTION_PLAN.md)'s F0–F8 numbering
rather than the G4–G9 sketched below. The original budget and gate planning is
kept unmodified as provenance; read it as the plan that was made, not as a live
description of what remains — nothing remains. Current state:
[PROJECT_STATE.md](PROJECT_STATE.md); current requirements:
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md); submission audit:
[SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md).

Ordered gates with binary exit criteria, sized for the 48–72 hour window (GEN-09).
A gate is closed only when **every** exit criterion is objectively true. Partial
completion means the gate stays open — that is the entire value of the structure.

## Budget

Approximately 62 working hours against a 72-hour ceiling, leaving roughly 10 hours of
slack. The slack is not spare capacity; it is the buffer for the device-validation
assumptions in [RESEARCH.md](RESEARCH.md) section 3, several of which can force
rework.

**Revised at G0.1 human review (2026-08-28):** G3 increased from 9h to 11h to fund
[ADR-012](DECISIONS.md#adr-012) — premium Material 3 execution over the reference
layout is materially more UI work than a literal clone. The two hours are drawn from
slack, not from another gate.

| Gate | Scope | Est. | Cumulative |
| --- | --- | --- | --- |
| G0.1 | Requirements & architecture freeze | 3h | 3h |
| G1 | Android foundation | 4h | 7h |
| G2 | Android location & domain | 8h | 15h |
| G3 | Android UI, polish, testing | 11h | 26h |
| G4 | Flutter bootstrap | 3h | 29h |
| G5 | Flutter camera | 9h | 38h |
| G6 | Flutter durable queue & sync | 10h | 48h |
| G7 | Failure & testing validation | 6h | 54h |
| G8 | Documentation & release | 6h | 60h |
| G9 | Independent final audit | 2h | 62h |

**Sequencing note.** Android completes fully (G1–G3) before Flutter starts. Task 1 is
the smaller and better-specified of the two; finishing it outright means that if time
runs short, the shortfall lands in one place and is visible, rather than leaving two
half-built apps. G6 is the largest single risk and is deliberately not last.

---

## G0.1 — Requirements & Architecture Freeze `READY TO CLOSE`

**Objective.** Make every requirement, decision, and open question durable before any
feature code exists.

**Constraints in force:** no application features, no Android source/build changes, no
new dependencies, no commits.

**Exit criteria**

- [x] Assessment PDF read in full — all 4 pages and all 3 embedded screenshots.
- [x] Every explicit requirement extracted into REQUIREMENTS_MATRIX.md with stable IDs.
- [x] Source-document ambiguities recorded rather than silently resolved (AMB-01…AMB-15).
- [x] ARCHITECTURE.md defines both applications' layering.
- [x] ADRs cover the five mandated decisions plus those that emerged.
- [x] RESEARCH.md separates verified findings from open questions and device assumptions.
- [x] SUBMISSION_CHECKLIST.md is binary and auditable.
- [x] No Android source, build, or dependency file modified.
- [x] **Human review completed 2026-08-28.** ADR-001, ADR-002, ADR-003, and ADR-011
      accepted; ADR-012 added and accepted; ADR-010 deliberately deferred to G8;
      `ER-01`, `ER-03` closed and `DA-07` resolved.

---

## G1 — Android Foundation

**Objective.** Turn the bootstrap into a project ready for feature work, with the
build path settled.

**Requirements:** AND-01, AND-11, GEN-08 · **Research:** ER-02, ER-04 (`ER-01` closed, `DA-07` resolved at G0.1)

**Work**

1. Resolve `ER-02` and `ER-04` to get exact artifact coordinates before pinning
   anything. **Do not** add `org.jetbrains.kotlin.android` — `ER-01` is closed: AGP 9+
   provides built-in Kotlin support by default (`RF-17`), so its absence is correct.
2. Add only the dependencies G2 needs (Play Services Location, DataStore, ViewModel
   Compose, lifecycle runtime Compose) via the version catalog.
3. Adopt the verified PowerShell + Gradle wrapper CLI path (`RF-20`) as the documented
   build command for every later gate and for README §4.
4. Create the `domain` / `data` / `presentation` package skeleton.
5. Declare `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` in the manifest.
6. Remove the template `ExampleUnitTest` / `ExampleInstrumentedTest` placeholders.

**Exit criteria**

- [ ] `ER-02` and `ER-04` answered and recorded in RESEARCH.md section 1.
- [ ] The documented PowerShell build command re-verified after the dependency changes.
- [ ] `assembleDebug` passes.
- [ ] `testDebugUnitTest` runs (no failures, even if empty).
- [ ] Dependencies added only via `libs.versions.toml`; no hard-coded coordinates.
- [ ] `git diff` inspected; no unrelated changes.
- [ ] PROJECT_STATE.md updated.

---

## G2 — Android Location & Domain

**Objective.** The mandated 50 m rule, correct and provable without a device.

**Requirements:** AND-02, AND-06, AND-07, AND-08, AND-09, AND-12, GEN-03, GEN-04
**Research:** ER-02, ER-04, ER-08 (`ER-03` closed at G0.1)

**Work**

1. Implement against [ADR-001](DECISIONS.md#adr-001), now `ACCEPTED`: foreground,
   lifecycle-aware Fused Location Provider updates with high-accuracy priority, and
   direct distance computation. **No `GeofencingClient`** — Android's recommended
   minimum geofence radius (~100–150 m, `RF-18`) is far above this 50 m rule.
2. `domain`: `OfficeLocation`, `DeviceLocation`, `AttendanceRule`, `ProximityResult`,
   and the 50 m constant.
3. **Write `AttendanceRule` tests before the Android plumbing.** The rule is the one
   thing the assessment measures most directly, and it needs no device.
4. `data`: `LocationDataSource` (streaming `callbackFlow` + one-shot current location),
   `OfficeLocationRepository` on DataStore, `LocationServiceMonitor`.
5. `presentation`: `AttendanceViewModel` and the sealed `AttendanceUiState`.
6. Permission handling covering all four permission conditions.

**Exit criteria**

- [ ] No `GeofencingClient` usage anywhere in the codebase (ADR-001).
- [ ] `AttendanceRule` unit-tested at 0 / 49.9 / 50.0 / 50.1 / 120 m, all passing.
- [ ] The 50 m boundary's inclusive/exclusive behaviour is decided and asserted.
- [ ] ViewModel state-sequence tests pass using fakes only.
- [ ] Office coordinates survive force-stop and relaunch (manual, recorded).
- [ ] Permission-denied, permanently-denied, and services-off states all reachable.
- [ ] Location updates stop when the screen is not resumed (verified, not assumed).
- [ ] Lint/format clean; `assembleDebug` passes; matrix and state updated.

---

## G3 — Android UI, Polish, Testing

**Objective.** `AttendanceScreen` matching the prescriptive p2 reference.

**Requirements:** AND-03, AND-04, AND-05, AND-10, AND-13…AND-21, GEN-04
**Research:** ER-10 · **Assumptions:** DA-01, DA-02, DA-03
**Design standard:** [ADR-012](DECISIONS.md#adr-012) — reference-layout fidelity with
premium native Material 3 execution. Budgeted at 11h for this reason.

**Work**

1. `AttendanceScreen` with both stages on one screen (AND-04).
2. Reference elements: top bar, office-context card with status dot, location visual
   plus coordinate pill, outlined Set Office Location button, circular distance gauge,
   range chip, guidance copy, dashed locked container with lock icon and disabled
   button, availability caption.
3. Original dependency-free location surface per [ADR-003](DECISIONS.md#adr-003)
   (`ACCEPTED`): no Maps SDK, no API key, no Maps branding or third-party tiles, and
   no affordance implying interactivity it does not have.
4. Availability caption per [ADR-011](DECISIONS.md#adr-011) (`ACCEPTED`) —
   **presentation only; it must not gate anything.**
5. Apply the ADR-012 standard across the screen: typographic hierarchy, spacing
   rhythm, shape system, tonal surfaces, meaningful status colour, complete button
   states, and subtle purposeful motion — using **stable** Material 3 / Compose only.
6. Failure-state UI for every `AttendanceUiState` branch.
7. Compose UI tests; emulator route playback across the boundary.

**Exit criteria**

- [ ] Every AND-13…AND-21 element present; side-by-side comparison against p2 captured.
- [ ] Compose UI tests pass: button disabled out of range, enabled in range, distance
      text renders.
- [ ] Distance updates continuously during emulator movement without user action.
- [ ] Every UI state rendered and screenshotted — including the failure states.
- [ ] Location surface implemented per ADR-003: renders fully on a clean clone with
      no API key, carries no Maps branding or third-party tiles, and shows no
      interactive affordance it does not implement.
- [ ] **Code review confirms no path consults the availability window when computing
      Mark Attendance enablement** (ADR-011).
- [ ] ADR-012 standard met: stable Material 3 / Compose only — **no alpha or preview
      design libraries**; reference information architecture, ordering, controls, and
      composition all preserved.
- [ ] Accessibility verified: content descriptions present, touch targets meet the
      minimum size, contrast adequate (ADR-012).
- [ ] Every enhancement beyond the reference is traceable to ADR-012 and distorts no
      requirement.
- [ ] Lint/format clean; `assembleDebug` passes; matrix AND rows evidenced.

**Android is feature-complete here. Do not start G4 until this gate closes.**

---

## G4 — Flutter Bootstrap

**Objective.** A Flutter project ready for camera work.

**Requirements:** FLT-01, FLT-15, GEN-02 · **Research:** ER-05, ER-06, ER-07

**Work**

1. Create `flutter-camera-sync/` (Android platform only — AMB-12).
2. Resolve ER-05, ER-06, ER-07 **before** adding plugins; record any plugin choice
   that departs from the assessment's `workmanager` example as an ADR.
3. Add camera, sqlite, path-provider, connectivity, background-worker, and bloc
   dependencies with pinned versions.
4. Create the `presentation` / `domain` / `data` skeleton and the composition root.
5. Declare camera and storage permissions.

**Exit criteria**

- [ ] ER-05, ER-06, ER-07 answered and recorded.
- [ ] `flutter analyze` clean; `flutter test` runs; `flutter build apk --debug` passes.
- [ ] Layer skeleton in place with inward-only dependencies.
- [ ] Any deviation from `workmanager` recorded as an ADR.
- [ ] Root `.gitignore` covers the new project; no generated files staged.

---

## G5 — Flutter Camera

**Objective.** `CameraPreviewScreen` with zoom and manual focus.

**Requirements:** FLT-02…FLT-07, FLT-17, GEN-04 · **Assumptions:** DA-04, DA-05

**Physical device required** (DA-04).

**Work**

1. `CameraDataSource` wrapping the controller; camera-unavailable and
   permission-denied failure paths (GEN-04).
2. `CameraPreviewScreen` with the reference overlay controls.
3. Zoom: pinch, slider, and presets — all three driving one zoom state, with presets
   derived from the device's real range (FLT-05, and robust to AMB-01).
4. Tap-to-focus with an animated reticle at the tap point.
5. `CameraCubit` and its tests.

**Exit criteria**

- [ ] Widget named exactly `CameraPreviewScreen`.
- [ ] Pinch, slider, and presets verified on a physical device and mutually consistent.
- [ ] Zoom clamps to the device's reported range without error at both extremes.
- [ ] Tap-to-focus verified on device; reticle appears at the tap point.
- [ ] Camera-permission-denied and camera-unavailable handled gracefully.
- [ ] Unit tests pass for zoom mapping and focus-point normalisation.
- [ ] `flutter analyze` clean; device verification recorded in the matrix.

---

## G6 — Flutter Durable Queue & Sync

**Objective.** The resilience requirements — the technical core of Task 2.

**Requirements:** FLT-08…FLT-14, FLT-18, FLT-19, GEN-03, GEN-07
**Research:** ER-06, ER-07 · **Assumptions:** DA-06

**Highest-risk gate. Budgeted longest and placed before, not after, the buffer.**

**Work**

1. `domain`: `Batch`, `CapturedImage`, `UploadState`, `RetryPolicy`, `UploadApi`.
2. **`RetryPolicy` tests first** — pure, no plugins, no network, no clock.
3. `data`: `ImageFileStore`, `UploadQueueDao`, `MockUploadApi` (deterministic,
   runtime-selectable, with simulated latency), `ConnectivityMonitor`.
4. Batch lifecycle per the AMB-10 definition.
5. `UploadManagerScreen` rendering all five per-item states plus batch progress.
6. Background worker running the same drain routine from its own entry point —
   constructible without the UI composition root (ADR-009).
7. `SyncCubit` and `BatchCubit` with tests.

**Exit criteria**

- [ ] `RetryPolicy` unit-tested including give-up; all passing.
- [ ] **Failure keeps both the database row and the image file** — asserted explicitly,
      for low-bandwidth and no-internet independently (FLT-11).
- [ ] Queue survives app kill **and** device reboot.
- [ ] Airplane-mode on→off with the app backgrounded drains the queue with **zero**
      user interaction (FLT-12) — verified on a device, recorded as a GIF.
- [ ] A missing image file moves its row to a terminal failed state instead of
      retrying forever (ADR-005 consequence).
- [ ] Mock success/failure toggleable at runtime and documented.
- [ ] All five per-item states render; attempt counter visible (FLT-19).
- [ ] `bloc_test` transitions pass; `flutter analyze` clean; `flutter build apk --debug`
      passes.

---

## G7 — Failure & Testing Validation

**Objective.** Prove GEN-04 deliberately, rather than trusting the happy paths.

**Requirements:** GEN-04, GEN-08, and verification of every prior gate
**Assumptions:** DA-01, DA-02, DA-03, DA-06, DA-08

**Failure matrix — every cell executed and recorded**

| Failure | App | Expected |
| --- | --- | --- |
| Location permission denied once | Android | Rationale + re-request path |
| Location permission permanently denied | Android | Settings route, no dead end |
| Coarse-only permission granted | Android | Surfaced as insufficient for a 50 m decision |
| Location services off | Android | Explicit state + resolution path |
| No fix / poor accuracy | Android | Acquiring state, not a false distance |
| Mark Attendance tapped at the boundary | Android | Decision consistent with AND-08 |
| Office never set | Android | Attendance blocked with a clear reason |
| Camera permission denied | Flutter | Graceful state, no crash |
| Camera unavailable / in use | Flutter | Graceful state |
| Zoom beyond device range | Flutter | Clamped, no error |
| Upload fails — no internet | Flutter | Row + file retained |
| Upload fails — low bandwidth | Flutter | Row + file retained, distinct reason |
| Connection restored, app backgrounded | Flutter | Auto-drain, no user action |
| App killed with items queued | Flutter | Queue intact on relaunch |
| Device rebooted with items queued | Flutter | Queue intact |
| Image file deleted under a queued row | Flutter | Terminal failure, no infinite retry |
| Storage full during capture | Flutter | Graceful failure |

**Exit criteria**

- [ ] Every row executed with its outcome recorded.
- [ ] No crash in any cell.
- [ ] Any defect either fixed or explicitly recorded in PROJECT_STATE.md.
- [ ] Full test suites pass on both apps.
- [ ] Evidence captured for the matrix Verification columns.

---

## G8 — Documentation & Release

**Objective.** Everything the reviewer actually receives.

**Requirements:** DOC-01…DOC-08, SUB-01…SUB-03, GEN-05, EXP-02
**Research:** ER-09 · **Assumptions:** DA-08, DA-09

**Work**

1. Root `README.md` with the five mandated sections **in the assessment's order**.
2. §2 must name the actual Cubit/BLoC classes (DOC-04) — verify each name exists.
3. §3 AI usage plus the essential prompts, from AI_USAGE.md (DOC-05, DOC-06 —
   explicitly mandatory).
4. §4 run steps for both apps, including prerequisites and permissions.
5. §5 screenshots plus the two GIFs that prove motion-dependent behaviour.
6. Resolve ER-09 and implement ADR-010 **(needs approval)**; touching
   `app/build.gradle.kts` is permitted from this gate onward.
7. Build both release APKs; verify install from a shared link.
8. Document the ADR-003 map trade-off and the ADR-011 window choice.

**Exit criteria**

- [ ] All five README sections present, in order, none a placeholder.
- [ ] Every class named in §2 exists in source.
- [ ] Essential prompts included (DOC-06).
- [ ] Run steps executed verbatim on a clean clone and confirmed working.
- [ ] Screenshots and both GIFs render on GitHub.
- [ ] `assembleRelease` and `flutter build apk --release` both succeed.
- [ ] Both APKs install on a clean device from the shared link (DA-08).
- [ ] Application IDs do not collide (DA-09).
- [ ] No secret, keystore, SDK path, or build output committed.

---

## G9 — Independent Final Audit

**Objective.** Verify the submission as an outsider would, against the PDF and not
against this project's own notes.

**Final status: this audit ran, in substance, across the documentation-consistency
reconciliation pass and the two submission-evidence sessions that preceded it.**
The exit criteria below reflect the actual final outcome, not the plan.

**Requirements:** EXP-01, EXP-04, SUB-01…SUB-03, all rows

**Work — deliberately adversarial**

1. Re-read all 4 PDF pages, including the screenshots. Reconcile every requirement
   against the matrix. **Read the PDF, not the matrix** — auditing the matrix against
   itself proves nothing.
2. Confirm no mandatory requirement was downgraded and no invented feature was
   promoted (EXP-03 discipline).
3. Clean-clone into an empty directory; follow the README verbatim with no local
   knowledge; build both apps.
4. Install both release APKs on a device that has never had them.
5. Walk SUBMISSION_CHECKLIST.md end to end.
6. Confirm public repository visibility while signed out.
7. Confirm the APK link resolves for a third party.

**Exit criteria**

- [x] Every matrix row `DONE` with real evidence, or explicitly and knowingly deferred
      (accepted residuals and platform limitations remain named, not hidden — see
      [REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md) and
      [flutter/RISK_REGISTER.md §8](flutter/RISK_REGISTER.md)).
- [x] Clean-clone build succeeds from README steps alone
      (SUBMISSION_CHECKLIST.md §2.3–2.5).
- [x] Both APKs install and run from the published links — verified by downloading
      both fresh from the v1.0.0 GitHub release and installing them side by side on
      a physical HONOR DNP-NX9.
- [x] Repository publicly visible while signed out
      ([github.com/rktuhinbd/PresenceLens](https://github.com/rktuhinbd/PresenceLens)).
- [x] SUBMISSION_CHECKLIST.md fully ticked, except the two rows that are correctly
      and permanently unticked: the optional GIFs (DOC-08 accepts screenshots **or**
      a GIF, and screenshots are delivered).
- [x] No secrets, keys, SDK paths, binaries, or assessment source documents in
      history (SUBMISSION_CHECKLIST.md §3).

---

## Rules that hold across all gates

1. State the requirement IDs a change addresses **before** editing.
2. Never mark a requirement `DONE` without executing its own verification method.
3. Before closing any gate: format/lint, run tests, run the build, inspect `git diff`,
   update the matrix, update PROJECT_STATE.md.
4. Record AI-assisted decisions in AI_USAGE.md as they happen — reconstructing them at
   G8 produces a weaker and less honest DOC-05.
5. Never push, rewrite history, or commit secrets.
6. A blocked gate does not silently slip. Record the blocker in PROJECT_STATE.md.
7. If an ambiguity is resolved, update the matrix **and** the relevant ADR together.
