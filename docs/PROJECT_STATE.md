# Project State

Resumption document. Read this first, then the active gate in
[EXECUTION_PLAN.md](EXECUTION_PLAN.md), then only the relevant rows of
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md).

Last updated: 2026-08-29
Overall status: **G3.8 COMPLETE, AWAITING HUMAN SIGN-OFF — Android Task 1 is
implemented end to end, passes all automated verification, and has been driven through
every state on an emulator. G3.8 was the final substantive engineering pass: location
measurements are now trusted only when they are both fresh *and* precise enough to decide
the boundary, the office anchor can no longer be set from a cached or coarse fix, a
provider fault recovers on its own, the location state machine and the office-capture
orchestration moved into `domain`, and a recorded attendance became an event rather than a
live condition ([ADR-015](DECISIONS.md#adr-015), [ADR-016](DECISIONS.md#adr-016),
[ADR-017](DECISIONS.md#adr-017)). The rows whose stated verification method is a Compose UI
test remain `PARTIAL`; a manual walkthrough is not that method.**
Flutter Task 2 status: **F0 COMPLETE — VISUAL DIRECTION APPROVED 2026-08-29.** Requirements, architecture,
data model, camera and sync engine designs, UX specification, test strategy, risk register,
twelve ADRs and seven static visual prototypes are delivered. The non-device gates are green
(`analyze` 0 issues, `test` 2/2, `build apk --debug` PASS). The prototypes in
[docs/flutter/design/](flutter/design/index.html) were reviewed and **approved**, so the visual
gate is **unlocked** and the design direction is frozen (`ADR-F13`, `ADR-F14`). **No production
Flutter UI exists yet** — `CameraPreviewScreen` and the Pending Uploads manager are still
unimplemented. Task 2 is implementation in progress; the data and queue layer (gate F1) is next.

Current gate: **F1 — Flutter data layer and queue (next).** F0 is complete and its visual gate is **APPROVED / UNLOCKED**. Android Task 1 is **FROZEN** at G3.8.

## Progress

| Area | State |
| --- | --- |
| Requirements extracted from the PDF | Complete — 64 requirements, 15 ambiguities |
| Architecture defined | Complete (both apps) |
| ADRs | 17 recorded — 16 `ACCEPTED`, 1 `PROPOSED` (ADR-009, a technical revisit; ADR-010 was resolved and accepted at G3.6). ADR-013's two open interpretive calls were **ruled on and accepted** at G3.6; its §7 confirmation-lifetime rule is **superseded by [ADR-016](DECISIONS.md#adr-016)** and ADR-014 §6's office-capture bound by **[ADR-015](DECISIONS.md#adr-015)**, both on explicit human ruling at G3.8. |
| **Android feature implementation** | **Complete, stabilised, polished, and hardened.** Domain rule, persistence, Fused Location layer, ViewModel + single UI state, permission/service UX, and a state-driven `AttendanceScreen` with every AND-13…AND-21 element ([ADR-013](DECISIONS.md#adr-013)). Location is a retained value bounded by **age and accuracy** ([ADR-014](DECISIONS.md#adr-014), [ADR-015](DECISIONS.md#adr-015)), the office anchor is derived fresh and refused if too coarse, a provider fault retries on a capped backoff, `LocationKnowledge`/`LocationReading` and `SetOfficeLocationUseCase` live in `domain` ([ADR-017](DECISIONS.md#adr-017)), and a recorded mark survives a stale fix and the user walking away ([ADR-016](DECISIONS.md#adr-016)). 158 unit tests pass; emulator walkthrough executed. |
| **Flutter application** | **Planning complete; feature code 0%.** Project scaffolded at `flutter_camera_sync/`, identity normalised, dependency set researched and resolved, and a twelve-document engineering pack plus seven static UI prototypes produced under [docs/flutter/](flutter/). The visual direction was **approved on 2026-08-29** and is now frozen. **No production camera or upload UI is implemented yet** — that is gate F3/F5 ([EXECUTION_PLAN](flutter/EXECUTION_PLAN.md)); F1 (data layer and queue) is the next work. 84 Flutter requirements specified; 1 `DONE`. |
| README / submission artefacts | Not started |

## Verification status

| Check | Result |
| --- | --- |
| Android Gradle sync | PASS (Android Studio and PowerShell) |
| Android `clean` | PASS (PowerShell CLI, verified at G1) |
| Android `assembleDebug` | PASS — re-verified from `clean` after the G3.8 pass, 2026-08-29 |
| Android `testDebugUnitTest` | PASS — **158 tests**, 0 failures, 2026-08-29 |
| Android `lintDebug` | PASS — **0 errors**, warnings unchanged from G3.7 (dependency-version advisories and one `PluralsCandidate`); G3.8 introduced none |
| `git diff --check` | CLEAN |
| `domain` free of Android imports | PASS — **now asserted by `DomainLayerPurityTest`** rather than by grep, including a guard that fails if the scan finds no sources |
| 50 m radius is a single constant | PASS — one literal, in `AttendanceRule`. Both accuracy thresholds derive from it; no `25` or `50` is written down again |
| Eligibility is distance-only | PASS — `canMarkAttendance` reads `proximity.isEligible` alone. Accuracy gates whether a fix *reaches* `Tracking`, and is never a term in the rule ([ADR-015](DECISIONS.md#adr-015)) |
| No new dependency added at G3.8 | PASS — `libs.versions.toml` and `app/build.gradle.kts` untouched |
| No `GeofencingClient` / Maps SDK / background location | PASS — no such dependency or permission exists |
| Office-hours caption does not gate eligibility (ADR-011, ADR-013) | PASS — `availability_caption` removed; `office_hours_label` / `office_hours_value` have one reference each, both `Text` calls |
| Android emulator launch | PASS (verified at G0.1) |
| **Emulator acceptance run of Task 1** | **PASS — executed four times.** By the author before G3.5, by the G3.5 walkthrough, at G3.6 on `emulator-5554` after the stability fix, and again at G3.8 on `emulator-5554` after the accuracy/architecture pass. See below. |
| **Stationary-oscillation soak** | **PASS — 30 samples over ~70 s on a stationary emulator, all reading "Ready to mark attendance".** The defect this replaces produced a flip roughly every 2 s. |
| Location-services off → on recovery | **PASS** — off gives the explicit services state; on gives "Updating your location… / Waiting for a fresh GPS fix." then automatic recovery, with **no** red failure state at any point |
| Office persistence across force-stop | **PASS** — executed 2026-08-28, AND-07 now `DONE` |
| Android `assembleRelease` | **PASS, SIGNED — 2026-08-28.** ADR-010 resolved; `apksigner verify` passed (APK Signature Scheme v2, 2048-bit RSA); installed and smoke-tested on `emulator-5554` |
| Flutter project | **CREATED and building.** Flutter 3.47.2 / Dart 3.13.2 / JDK 21.0.12.1 / Gradle 8.14 / AGP 8.11.1 |
| Flutter `pub get` | PASS — 92 packages resolved, 2026-08-29 |
| Flutter `analyze` | PASS — **0 issues**, with `strict-casts`, `strict-inference`, `strict-raw-types` and `unawaited_futures: error` enabled |
| Flutter `test` | PASS — **2/2** (app-shell smoke only; the real suite is specified, not written) |
| Flutter `build apk --debug` | PASS — `app-debug.apk` produced, 2026-08-29 |
| Flutter device QA | **NOT STARTED** — deferred to gate F7; no device evidence is claimed |
| iOS | Configured (bundle identity, `NSCameraUsageDescription`, background modes). **Never built or validated — impossible from a Windows host** |

### Unit test breakdown (158)

| Suite | Tests | Covers |
| --- | --- | --- |
| `AttendanceViewModelTest` | 50 | Permission, approximate-only, services-off, acquiring, real provider failure, revoked mid-stream (both routes), office-not-set, office restored, per-emission distance, the 50 m boundary in both directions, degraded-fix behaviour, office capture + persistence, capture failure, storage failure, mark-attendance in range / out of range / on a stale fix, message lifecycle, subscription teardown, **and the eight G3.6 stability cases** — availability flapping, the no-flash assertion over the whole emitted sequence, escalation only after the acquisition window, staleness at and past the limit, recovery into eligible and into out-of-range, no subscription restart on a repeated grant, and the freshness tick producing no state churn, **the G3.7 case** — a mark records both its time and the distance verified at that instant — **and the eighteen G3.8 cases**: the four accuracy bands (precise, degraded-but-usable, exactly at the radius, wider than the radius), unreported accuracy failing closed, convergence from imprecise to precise, a no-op click on an imprecise fix, age outranking accuracy on an old wide fix, the confirmation surviving a stale fix and surviving the user walking out of range while `canMarkAttendance` goes false, the office capture saving / warning / refusing / refusing-on-unknown-accuracy without ever overwriting a saved office, a second tap being ignored while a capture is genuinely in flight, "Set Office Location" staying actionable while the stream is acquiring and after it has failed and being refused only on permission/services, and a provider fault reported then recovered from with backoff and torn down on unsubscribe |
| `AttendanceStatusPresenterTest` | 24 | All fourteen status-card conditions, the action each offers, all eight blocked-button reasons, that a stale fix reads as progress rather than failure, **the G3.8 cases** — an imprecise fix reads as progress and is worded distinctly from a stale one, names its own blocker, the confirmation now *outlives* the eligibility that produced it and survives a stale fix, and no unmarked blocked state reaches the button without a reason — and **the four G3.7 success-state cases** — eligible-and-unmarked offers the action and reads "Ready to mark attendance", eligible-and-marked reads "Attendance marked" and resolves to `COMPLETED` (no actionable CTA, no blocker), the headline stops inviting an action already done, and the confirmation carries the recorded time and the verified distance |
| `AttendanceRuleTest` | 5 | AND-08 at 0 / 49.9 / 50.0 / 50.1 / 120 m |
| `DistanceCalculatorTest` | 8 | Haversine identity, known distance, symmetry; bearing at the four cardinals and its normalisation; **and the G3.8 precision cases** — agreement with an independent WGS-84 ellipsoidal reference within 0.25 m at the 50 m radius across 24 bearings, the worst-case divergence shown to be under 1/100th of the precise-fix threshold, and sub-metre movement resolved cleanly either side of the boundary |
| `DistanceFormatterTest` | 6 | Metres, the kilometre switch, rounding, and non-finite input |
| `ProximityGeometryTest` | 5 | Gauge fraction and marker placement, including the off-panel clamp |
| `GeoCoordinatesTest` | 5 | Latitude/longitude range validation |
| `LocationQualityTest` | 6 | Both thresholds and their derivation from the radius, the inclusive boundaries, unreported and non-finite accuracy, and which qualities may decide the rule |
| `LocationKnowledgeTest` | 17 | The domain state machine directly: the four accuracy bands, fail-closed on unknown accuracy, the freshness boundary, age outranking accuracy, recovery, the availability estimate never discarding a held fix and escalating only after the acquisition window, and the terminal permission/failure/not-observing resets |
| `SetOfficeLocationUseCaseTest` | 12 | All seven capture outcomes with no ViewModel — saved, saved-with-limited-accuracy, both accuracy refusals, no fix, availability estimate, permission, and storage failure — each asserting whether anything was written and that an existing office survived |
| `LocationRequestConfigurationTest` | 5 | The two built requests: accurate first fix, 2 s cadence, no batching, `maxUpdateAge = 0`, `GRANULARITY_FINE`, and the 28 s capture window |
| `DomainLayerPurityTest` | 2 | No `android.*`, `androidx.*`, or Play Services import anywhere in `domain`, plus a guard that the scan actually found sources |
| `LocationFreshnessTest` | 6 | The freshness boundary in both directions, age arithmetic, a fix stamped ahead of now, and that the threshold stays inside the accuracy the app already tolerates |
| `InMemoryOfficeLocationRepositoryTest` | 5 | Absent, save, overwrite, clear, unreadable-store recovery |
| `DataStoreOfficeLocationRepositoryTest` | 2 | Real file-backed round trip |

## Manual emulator verification — **executed**

The seven steps below were run by the author before G3.5 and re-run against the
polished build during G3.5 on `emulator-5554` (a Google Play services image — the
Fused Location Provider needs them). Both passes were clean. The steps are kept here
because they are the reproduction recipe for a reviewer, not because they are pending.

**Setup.** Install and launch:

```bash
cd android-attendance && ./gradlew.bat installDebug
```

Open **Extended Controls → Location** in the emulator (the `···` button beside the
device frame). Set a starting coordinate — for example `23.780636, 90.279372` — and press
**Set Location**. Grant **Precise** location when the app asks.

Then, in order:

1. **Set office.** With a fix acquired, press **Set Office Location**. Expect: a snackbar
   confirming the saved coordinates, the status dot turning green, "Office location
   saved", the coordinate pill showing the captured values, and the distance reading
   about 0 m with the button enabled.
2. **Move outside 50 m.** In Extended Controls, change the latitude by **+0.0020**
   (≈ 222 m north) and press **Set Location**.
3. **Verify disabled.** Expect, without touching the app: the distance rising to roughly
   220 m, the chip turning red and reading **OUT OF RANGE**, the guidance line appearing,
   the container returning to its dashed locked state, and **Mark Attendance** disabled.
4. **Move inside 50 m.** Change the latitude by **+0.0002** from the office instead
   (≈ 22 m north) and press **Set Location**.
5. **Verify enabled.** Expect the chip to turn green and read **IN RANGE**, the outline to
   become solid, the lock to become a check, and **Mark Attendance** to become tappable.
   Press it — expect a snackbar confirming attendance was marked with the distance. (There
   is no attendance API in the assessment, so this is a local confirmation by design.)
6. **Restart the app.** Force-stop it (`adb shell am force-stop
   io.github.rktuhinbd.presencelens.attendance`) and relaunch from the launcher.
7. **Verify persistence.** Expect the office location to still be present — status dot
   green, coordinate pill populated, and the distance computed against the same office
   without pressing Set Office Location again.

**Also worth exercising while there** (each maps to a `GEN-04` state):

- Turn the emulator's location toggle off → expect the "Location is turned off" banner
  with a working **Open location settings** action, and no stale distance left on screen.
- Revoke location permission in system settings and return → expect the permission banner
  to appear immediately on resume, not on the next fix.
- Grant **Approximate** instead of Precise → expect the "Precise location required"
  banner, and Mark Attendance unavailable.

**G3.5 walkthrough outcome (2026-08-28) — all clean.** Additionally exercised beyond the
seven steps: the first-use setup face with the live position drawn at the centre of the
dashed preview ring; the "Replace the saved office?" confirmation naming the coordinates
it would overwrite; the "How attendance works" sheet; the stated reason beside the
disabled button in the no-office, no-fix and out-of-range cases; the success state
("ATTENDANCE MARKED" / "Marked at 12:55 PM") and its disappearance on leaving the radius;
and dark-mode rendering of every card. Screenshots were captured for each.

### G3.6 stability checks — **executed on `emulator-5554`, 2026-08-28**

Driven with `adb emu geo fix`, `adb shell settings put secure location_mode`, and
`uiautomator dump` reading the status card back as text. All eight passed.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | Stationary for ≥ 30 s | No `Ready ↔ Location unavailable` oscillation | **PASS** — 30 samples over ~70 s, all "Ready to mark attendance" |
| 2 | Office set, inside 50 m for 30 s | Eligible state stays stable | **PASS** — stable across the whole soak |
| 3 | Move > 50 m | Stable out-of-range state | **PASS** — "Move closer to the office" / "You're 255 m away…" held across 8 samples |
| 4 | Move back < 50 m | Stable eligible state | **PASS** — recovered on the next fix, no intermediate failure |
| 5 | Android Location OFF | Explicit location-services state | **PASS** — "Turn on location services" with a working settings action |
| 6 | Android Location ON | Acquiring/updating, then automatic recovery | **PASS** — "Updating your location… / Waiting for a fresh GPS fix." then automatic recovery on the next fix. **No red failure state at any point** — the pre-fix build showed "Location unavailable" here |
| 7 | Force-stop and relaunch | Office persistence correct | **PASS** — coordinates and capture time restored with no user action (AND-07 now `DONE`) |
| 8 | Light and dark layouts | Both correct | **PASS** — first-use captured in light, tracking/out-of-range/marked in dark |

Also exercised: first-use setup from cleared app data (all four target copy strings verified
verbatim, "Set Office Location" label intact), a single-tap office capture that succeeded
without re-tapping, and the completed CTA (disabled check + "Attendance marked").

Matrix rows whose verification method is a **Compose UI test** stay `PARTIAL` regardless —
a manual walkthrough is not that method, and inflating them would be exactly the kind of
unearned `DONE` the charter forbids.

### G3.8 accuracy and architecture checks — **executed on `emulator-5554`, 2026-08-29**

Driven with `adb emu geo fix`, `adb shell settings put secure location_mode`, and
`adb exec-out screencap` reading the screen back visually. Six of eight passed; two could
not be induced on an emulator and are stated as such rather than claimed.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | Cold start with app data cleared | "Finding your location…", no eligibility flash from a low-quality first fix | **PASS** — acquiring state held until a qualified fix arrived; no distance and no "IN RANGE" appeared before it |
| 2 | First precise fix arrives | Distance and eligibility become live | **PASS** — `23.810300, 90.412498` accepted as usable, screen moved to the office-setup face |
| 3 | Move > 50 m (200 m north) | Stable out-of-range | **PASS** — "200 m AWAY / OUT OF RANGE" held across four samples, no oscillation. The reading was exactly 200 m, which is the Haversine precision claim visible on a device |
| 4 | Move back inside | Stable eligible | **PASS** — "0 m / IN RANGE / READY TO MARK" on the next fix |
| 5 | Location services OFF → ON | Recovery without leaving the screen | **PASS** — off gave the attention state with the position cleared and "Change office location" correctly disabled; on gave full in-place recovery on the next fix |
| 6 | **"Set Office Location" during `AcquiringFix`** | Actionable; its own one-shot request handles acquisition | **PASS** — the button was enabled and prominent while the live stream had produced nothing at all (screenshot 1), and capturing later succeeded from the fresh-only request |
| 7 | Office capture with > 50 m accuracy | Nothing persisted | **NOT EXECUTED ON DEVICE** — the emulator's fused provider cannot be made to report a poor error radius on demand. Covered by `SetOfficeLocationUseCaseTest` (refusal + nothing written + existing office intact) and by `AttendanceViewModelTest` |
| 8 | **Mark, then walk out of range** | Confirmation survives | **PASS** — at 200 m the gauge and chip reported "OUT OF RANGE" honestly while the status card read "Attendance marked / Your location was verified at 2:44 AM" and the receipt read "Location verified · 0 m from office · 2:44 AM". Under the pre-G3.8 rule this reverted to "Move closer to the office" |

**Also not executed on device:** the provider-fault retry/backoff path. Play Services cannot
be made to throw on demand on an emulator, so it is covered by three `AttendanceViewModelTest`
cases — fault reported → re-subscribed after the first backoff → fresh fix resumes eligibility;
repeated faults back off rather than spin; retrying stops when the screen stops observing.

## Active objective

**G3.8 — Android accuracy and architecture hardening. Complete 2026-08-29.**

The final substantive Android engineering pass before Task 1 is frozen. Superseded two
previously-accepted rules on explicit human ruling ([ADR-015](DECISIONS.md#adr-015),
[ADR-016](DECISIONS.md#adr-016)) and stated the architecture accurately rather than
aspirationally ([ADR-017](DECISIONS.md#adr-017)).

**G3.7 — Android success-state refinement. Complete 2026-08-28.**

**The finding.** A human review of the built app on a **physical device** rejected the
post-attendance presentation. Not a defect — a redundancy. The completed state said the
same thing three times over: an "ATTENDANCE MARKED" overline, a full-width button-shaped
surface reading "Attendance marked", and a green outline drawn around both; meanwhile the
eligible-distance copy still read "You're inside the radius — Mark Attendance is
unlocked", explaining an action that had already been taken. A completed action was still
being rendered as an action.

**The change** (success state only; everything before the mark is untouched):

1. **`isAttendanceConfirmed` is one derived value** on `AttendanceUiState`, read by the
   status-card presenter, by the action area, and by the new
   `AttendanceStatusPresenter.markAttendanceAction`. The headline, the confirmation, and
   the availability of the action are now incapable of disagreeing.
2. **`MarkAttendanceAction` — `AVAILABLE` / `BLOCKED` / `COMPLETED`.** "Completed" is not
   a shade of "disabled". In `COMPLETED` the panel renders **no `Button`, no outline and
   no overline**: verified by `uiautomator` on the running app, where no `Mark Attendance`
   node and no clickable node survives.
3. **A compact confirmation replaces the control** — a success check, "Attendance marked",
   "Location verified · 1 m from office", and the recorded time on the trailing edge, in
   the screen's own card role rather than a second saturated green block. One
   `clearAndSetSemantics` node, one sentence: *"Attendance marked at 3:37 PM. Location
   verified, 1 m from the office."* TalkBack meets a statement, not an inert control.
4. **`MarkedAttendance` (time + distance) replaces the bare timestamp.** The distance is
   captured at the instant the rule was applied, so "location verified" names the reading
   that earned the mark rather than a live value that drifts afterwards.
5. **Copy.** The status card after the mark reads "Attendance marked / Your location was
   verified at 3:37 PM." The eligible-distance line is now "You're within the attendance
   area." — the green IN RANGE chip already carries the eligibility, and the sentence no
   longer explains it a second time.
6. **Measured on `emulator-5554`:** the attendance region falls from **467 px to 300 px —
   ~36 % shorter**, inside the 30–40 % target set for the sprint.

**Nothing else moved.** The 50 m rule, `AttendanceRule`, the Haversine calculation,
`LocationFreshness`, `FusedLocationDataSource`, the permission logic, DataStore
persistence, office persistence, the architecture, the DI strategy, the Maps decision, the
signing identity, the Gradle/toolchain versions, and Flutter are all untouched — verified
by inspecting `git diff`, which spans nine files, all in the presentation layer, its
tests, and `strings.xml`.

**Verified.** `clean` → `testDebugUnitTest` (**95 tests**, 0 failures) → `assembleDebug` →
`lintDebug` (**0 errors**, same 10 warnings) → `git diff --check` clean. Driven on
`emulator-5554` in light and dark: ready is unchanged and actionable; marked shows one
headline, one receipt, the live distance context, and Office hours, with no clipping.
Leaving the radius retires the confirmation and restores the locked CTA; returning
restores the confirmation with its **originally verified** time and distance while the
live readout tracks the current position — the captured/live distinction behaving as
designed.

**G3.6 — Android stability and final UX polish. Complete 2026-08-28.**

**The bug.** A manual screen recording showed the app oscillating on a *stationary*
emulator, roughly every two seconds:
`Ready to mark attendance → Location unavailable → Ready to mark attendance → …`

**Root cause.** `FusedLocationDataSource.onLocationAvailability` mapped
`LocationAvailability.isLocationAvailable == false` directly to a failure, and the ViewModel
treated any failure as terminal — discarding the fix it was holding. Play Services documents
that flag as a **best-guess estimate**, and a stationary device flips it to `false` routinely
between confident reports. The next scheduled fix, two seconds later, restored the eligible
state, and the cycle repeated. A `LocationResult` with no usable location was mapped the same
way, for the same wrong reason.

**The fix — a state model, not a debounce** ([ADR-014](DECISIONS.md#adr-014)):

1. `LocationFix.ProviderReportedUnavailable` (advisory) is now distinct from
   `LocationFix.Failed` (real). An empty `LocationResult` emits nothing at all.
2. The ViewModel **retains** the last usable position (`LocationKnowledge`) and derives what
   it may *say* (`LocationReading`) from that plus the fix's age. An availability estimate
   cannot discard a position already held.
3. **One freshness threshold**: `LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS = 10 s`, measured
   on the monotonic elapsed-realtime clock, not the wall clock. Five missed 2 s deliveries;
   ~14 m of walking drift, well inside both the 50 m rule and the 25 m accuracy tolerance.
4. Past it, `AttendanceStatus.RefreshingFix` — *"Updating your location… / Waiting for a fresh
   GPS fix."* in the **progress** tone. Mark Attendance is disabled, the last marker stays
   drawn so nothing blinks, and Set Office Location stays available.
5. "Location unavailable" is now reachable only from a real failure, or from never having held
   a position once the acquisition window has passed.
6. The one-shot office capture uses the same freshness number and a 20 s window, with a
   "Getting a precise fix…" note while it runs.

**Also audited while in there**, all clean: one location subscription only (a repeated
permission report is not a change and does not restart it — now asserted by a test); the
`callbackFlow` still removes its callback in `awaitClose`; the freshness tick lives inside the
`WhileSubscribed` graph so it stops with the screen, and `distinctUntilChanged` means a tick
that changes nothing hands the UI nothing.

**Final UX pass** (approved direction, no redesign):

- **Vertical density.** Measured on `emulator-5554` in the out-of-range state, the span from
  the status-card title to the "OUT OF RANGE" chip fell from **2288 px to 1853 px — 19%**.
  "ATTENDANCE LOCKED" and the Mark Attendance button are now above the fold on that device,
  where before they were not. Location surface 232→190 dp, gauge 168→136 dp, card padding
  20→16/18 dp, section gap 16→12 dp, and shorter copy doing the rest.
- **First-use repetition removed** — "Office setup required" / "Save your office location once
  to enable attendance." / "Set up your office location" / "Set your office location to
  continue.", with the radius restated once instead of four times.
- **Terminology unified on *attendance*** — "CHECK-IN LOCKED" → "ATTENDANCE LOCKED",
  "READY TO CHECK IN" → "READY TO MARK"; no "check-in" wording remains anywhere in the app.
- **Completed CTA** — after marking, the button becomes a disabled check + "Attendance marked"
  in the success role, instead of an active "Mark Attendance" the user could press again.
  Local demonstration feedback only; no history, no record, no API.
- **Copy polish** — "Saved office location" / "Captured Aug 28, 2026 1:44 PM" replaces the
  specification-like helper sentence, and the out-of-range guidance splits into
  "You're 255 m from the office." + "Move within 50 m to mark attendance." Distance stays live.

**Nothing approved was regressed:** the Material 3 design, first-use setup face, dynamic
status card, Compose-drawn location visual, change-office confirmation, "How attendance works"
sheet, Office hours treatment, dark theme, semantics, 48 dp targets, haptic, no Maps SDK, no
background location, DataStore persistence, the pure 50 m rule, Haversine in `domain`, and
lifecycle-aware collection are all intact and were re-checked on the emulator.

**G3.5 — Android UX Polish Sprint. Complete 2026-08-28.** The screen is now state-driven
([ADR-013](DECISIONS.md#adr-013)), against a human-supplied UX direction. Delivered:

1. **`AttendanceStatusPresenter`** — a pure function mapping `AttendanceUiState` to one of
   twelve status-card conditions and to one of six "why is Mark Attendance unavailable"
   reasons. Zero Android imports, so both are unit-testable on the JVM and no Composable
   has to make the decision.
2. **A dynamic status card** — one shape across all twelve states, cross-fading between
   them, always saying what the app is doing and, when blocked, why.
3. **A first-use setup face** on the office card — heading, explanation, and the single
   prominent filled action. The distance panel is not drawn while there is no office to
   measure against.
4. **A stated reason beside a disabled Mark Attendance**, in every blocked state.
5. **"Change office location"** as a quiet secondary action once setup is complete,
   behind a confirmation that names the coordinates it would overwrite. "Set Office
   Location" keeps its exact mandated label throughout the Setup Phase (AND-05).
6. **The availability caption relabelled "Office hours"** — same position, same value,
   no implied rule (ADR-011, ADR-013).
7. **A "How attendance works" bottom sheet** from the app bar: on-device storage,
   foreground-only reads, the 50 m radius, no background tracking.
8. **A compact success state** — status card, a "Marked at HH:MM" line, and one haptic,
   replacing the snackbar for that event and shown only while still in range.
9. **A refined location surface** — a graded boundary, an honest legend that lists only
   markers actually drawn, and the live position at the centre of the dashed preview ring
   before an office exists.
10. **14 new unit tests (70 total)**, five new project-owned icons, 17 `@Preview` states,
    and a full emulator walkthrough in light and dark.

**G3 — Android UI, Polish, Testing. Code-complete 2026-08-28.** Delivered earlier:

1. **`domain/location`** — `LocationDataSource` and `LocationServiceMonitor` interfaces,
   `DeviceLocation` (carrying reported accuracy), `LocationFix` (failures as values, not
   exceptions), `LocationPermissionStatus`, and `LocationQuality` whose threshold derives
   from `AttendanceRule.ELIGIBLE_RADIUS_METERS`. Still zero Android imports.
2. **`data/location`** — `FusedLocationDataSource` (high-accuracy `callbackFlow`, callback
   removed in `awaitClose`, plus a separate one-shot request for AND-06) and
   `SystemLocationServiceMonitor` (location-mode broadcast, not polling).
3. **`presentation`** — `AttendanceUiState` (one value; mutually exclusive conditions in a
   sealed `AttendanceStatus`, so a distance cannot exist without a fix) and
   `AttendanceViewModel` combining permission, services, location, and the persisted office
   into a single `StateFlow`.
4. **Permission/service UX** — one automatic request on first composition and
   user-initiated thereafter; permanent denial routes to app settings; the grant is re-read
   on every resume.
5. **`AttendanceScreen`** — every reference element (AND-13…AND-21), the original
   Compose-drawn `LocationSurface` (ADR-003), the distance gauge, range chip, live distance
   sentence, and the dashed locked attendance region.
6. **Design system** — deliberate Material 3 palette replacing the template purple, plus
   success/warning roles Material does not define; tuned type and shape scales; nine
   project-owned vector icons (Material3 1.4.0 no longer puts `material-icons-core` on the
   classpath, and this avoids adding a dependency for nine glyphs).
7. **12 `@Preview` states** covering every `AttendanceStatus` branch, light and dark.
8. **39 new unit tests** (56 total), all passing.

### Decisions taken during implementation, for review

- **A degraded fix warns; it never blocks.** GEN-04/AMB-14 ask for a low-quality-fix state.
  Disabling Mark Attendance on a wide error radius would have added a condition AND-08 does
  not have, so accuracy raises a caution and changes nothing else. Coarse-only *permission*
  is treated differently and is refused outright, per `android-attendance/AGENTS.md`.
- **Lifecycle-awareness has no manual switch.** `collectAsStateWithLifecycle` →
  `stateIn(WhileSubscribed)` → `awaitClose` means leaving the screen removes the platform
  callback with nothing for a maintainer to forget. Asserted by a test that watches the
  fake's subscription count return to zero.
- **`AttendanceUiState` is one data class wrapping a sealed `AttendanceStatus`**, rather
  than a top-level sealed hierarchy. The property ARCHITECTURE.md wants — no distance
  without a fix — is preserved exactly, while the single-surface screen (AND-04) stays
  renderable in every state.

### Pre-existing defect found and fixed

Two of G2's four DataStore tests were **failing on this Windows host** and had been masked
by a cached Gradle result — the suite had not actually re-executed since it was written, so
the "17 passing" claim in the previous G2 record was stale when recorded. DataStore commits
a write by renaming a temp file over the target, and `File.renameTo` on Windows refuses to
overwrite an existing file, so any *second* write failed. This is a host-filesystem
limitation, not Android behaviour and not a defect in the repository. Multi-write behaviour
and read-failure recovery now run against an in-memory `DataStore<Preferences>`; the real
file-backed round trip is retained separately.

## Completed milestones

1. Repository governance established (AGENTS.md, CLAUDE.md).
2. Android project bootstrapped; baseline build and emulator launch verified.
3. **G0.1 documentation set authored** — requirements matrix, architecture, ADRs, research,
   execution plan, submission checklist, AI usage log.
4. Assessment PDF fully extracted, including all three embedded screenshots.
5. **G0.1 human review completed (2026-08-28).** ADR-001, 002, 003, 011 accepted; ADR-012
   added and accepted; ADR-010 deferred to G8; `ER-01` and `ER-03` closed; `DA-07` resolved.
6. **G1 — Android Foundation completed (2026-08-28).** Foundation dependencies, manifest
   permissions, Hilt evaluated and rejected (ADR-009), app-level AGENTS.md and CLAUDE.md.
7. **G2 — Android attendance domain and office-location persistence (2026-08-28),**
   committed as `feat(android): implement attendance domain and persistence`.
8. **G3 — Android location layer, ViewModel, and AttendanceScreen (2026-08-28),** committed
   as `feat(android): add lifecycle-aware location tracking` and
   `feat(android): deliver polished attendance experience`.
9. **Emulator acceptance of Task 1 performed by the author (2026-08-28)** — permission flow,
   set office, persistence after restart, disabled beyond 50 m, enabled inside 50 m.
10. **G3.5 — Android UX polish sprint (2026-08-28),** committed as
    `feat(android): refine attendance UX and visual design`. Recorded as
    [ADR-013](DECISIONS.md#adr-013).
11. **G3.6 — Android stability and final UX polish (2026-08-28),** committed as
    `fix(android): stabilize location state and polish attendance UX`. Recorded as
    [ADR-014](DECISIONS.md#adr-014); ADR-013's two open rulings accepted.
12. **G3.7 — Android success-state refinement (2026-08-28),** committed as
    `fix(android): refine attendance success experience`. Recorded against
    [ADR-013](DECISIONS.md#adr-013) item 7 and [AI_USAGE.md Entry 008](AI_USAGE.md).
13. **Android release signing (2026-08-28)** — ADR-010 resolved, blocker B-01 closed. A
    dedicated release keystore and `key.properties` (both local-only, git-ignored)
    sign `assembleRelease`; the signature is `apksigner`-verified and the build is
    installed and smoke-tested. Final artifact at
    `android-attendance/release-artifacts/PresenceLens-Attendance-v1.0.0.apk` (local,
    not committed). See [ADR-010](DECISIONS.md#adr-010) and
    [AI_USAGE.md Entry 007](AI_USAGE.md).

## Next gate

**Human sign-off on Android Task 1**, then **G4 — Flutter Bootstrap.**

Flutter work has not begun and must not begin until Task 1 is signed off.

Remaining before G3/G3.5 can formally close:

- [x] Human confirmation of the two interpretive calls in [ADR-013](DECISIONS.md#adr-013):
      the AND-05 Setup-Phase reading, and the "Office hours" relabel of the AND-21 caption.
      **Both ruled on and ACCEPTED 2026-08-28.**
- [ ] Side-by-side comparison against the p2 reference captured for README §5 (AND-10).
- [ ] Compose UI tests for AND-03/04/05/08/18/20 — deliberately deferred. The AND-05 test
      must assert the mandated label **in the no-office state** (ADR-013).
- [ ] Haptic on the mark-attendance path confirmed on a physical device; an emulator
      cannot show it.
- [x] Location layer, ViewModel, permission UX, and `AttendanceScreen` implemented.
- [x] Location-state oscillation root-caused, fixed, and pinned by regression tests
      ([ADR-014](DECISIONS.md#adr-014)); 70 s stationary soak clean.
- [x] State-driven UX pass (G3.5) delivered against the approved direction.
- [x] Emulator walkthrough of every state executed, in light and dark.
- [x] 158 unit tests passing; `assembleDebug` and `lintDebug` clean (G3.8, from `clean`).
- [x] `git diff` inspected; five local commits created; nothing pushed.
- [x] ADR-013 recorded; matrix, AI_USAGE.md and this file updated.

## Blockers

| ID | Blocker | Blocks | Notes |
| --- | --- | --- | --- |
| ~~B-01~~ | ~~Release build defines no `signingConfig`; `assembleRelease` would be unsigned and non-installable.~~ | — | **RESOLVED 2026-08-28.** ADR-010 accepted; a dedicated release keystore is wired through `key.properties` (never committed), `assembleRelease` produces a verified-signed APK, and it is installed/smoke-tested on the emulator. See [ADR-010](DECISIONS.md#adr-010) and [AI_USAGE.md Entry 007](AI_USAGE.md). |
| ~~B-02~~ | ~~`ER-03` unanswered (geofence minimum-radius guidance).~~ | — | **RESOLVED at G0.1 review** — `RF-18`; ADR-001 is now `ACCEPTED`. |
| B-03 | Flutter plugin viability unverified (`ER-05`, `ER-06`, `ER-07`). | G4 | Resolve before adding Flutter plugins, not after. |
| B-04 | A physical Android device is required for camera work (`DA-04`) and background-retry verification (`DA-06`). | G5, G6, G7 | Confirm availability before G5 — a scheduling risk, not a technical one. |
| ~~B-05~~ | ~~Emulator acceptance of Task 1 not yet run.~~ | — | **RESOLVED 2026-08-28.** Run by the author, then re-run against the polished build during G3.5. Rows whose stated method is a Compose UI test stay `PARTIAL` by design. |

## Known limitations (Android Task 1)

- **No Compose UI tests yet.** The `androidTest` dependencies are declared and the tests are
  specified in the matrix, but they need a device. Every rule they would cover is already
  covered on the JVM through `AttendanceUiState` and `AttendanceStatusPresenter`; what
  remains unproven by *automation* is the rendering, not the logic — and the rendering has
  now been checked by hand on an emulator in every state.
- **The location surface is not a map**, deliberately (ADR-003). It shows the boundary and
  the user's true bearing and distance, not streets. This is disclosed rather than implied,
  and must be stated in README §5.
- **The `LocationAvailability` mapping in `FusedLocationDataSource` has no automated test.**
  It is Play Services-facing and the project carries no Robolectric or mocking framework. The
  ViewModel half of the same behaviour is covered by four JVM regression cases; the data-source
  half is documented at the call site and evidenced by the emulator soak above.
- **A held position that goes stale never escalates to "Location unavailable"**, however old it
  becomes. Deliberate ([ADR-014](DECISIONS.md#adr-014)): "Updating your location…" stays true,
  the action stays disabled, and a red failure state is not the honest reaction to a provider
  going quiet.
- **Two G3.8 paths are unit-tested but not device-verified.** The >50 m office-capture refusal
  and the provider-fault retry/backoff cannot be induced on an emulator: the fused provider
  will not report a poor error radius on demand, and Play Services will not throw on demand.
  Both are covered on the JVM and both are recorded here rather than folded into the emulator
  PASS list.
- **The accuracy gate depends on the provider reporting an honest error radius.** If a device
  under-reports accuracy, the app trusts the fix. There is no cross-check, and deliberately so
  ([ADR-015](DECISIONS.md#adr-015) rejects mock-location detection and custom GNSS processing);
  the assessment asks for a proximity feature, not an anti-abuse one.
- **A device that never reports accuracy cannot mark attendance at all.** The fail-closed
  policy is intentional, and every mainstream Android provider does report it, but a device
  that did not would sit in "Improving location accuracy…" indefinitely.
- **The confirmation is session-scoped.** Leaving the screen ends it. That is unchanged by
  [ADR-016](DECISIONS.md#adr-016), which extends the receipt across location changes, not
  across process death; the assessment provides no attendance API (p3 Note).
- **Dynamic colour is off by default** so status colour keeps its meaning and a reviewer
  sees the designed palette. The parameter remains available.
- **Distance uses a hand-rolled Haversine, not `Location.distanceTo`.** ADR-001's
  consequences prefer the platform's geodesic calculation; the domain-purity rule in
  `android-attendance/AGENTS.md` forbids `android.location` in `domain`. Purity won, since it
  is what makes AND-08 testable at the boundary with plain JUnit. The two agree to well
  under a metre at this scale. **Worth a human ruling.**

## Constraints in force

- No Flutter work until Android Task 1 is accepted.
- No `GeofencingClient` (ADR-001), no Google Maps SDK or API key (ADR-003), no background
  location, no alpha/preview design libraries (ADR-012).
- The office-hours caption is presentation only (ADR-011, ADR-013) — **ruled and accepted**.
- `LocationAvailability` is advice, never a verdict; "Location unavailable" is reserved for a
  real inability (ADR-014). The 50 m rule is still the only eligibility gate.
- "Set Office Location" is the exact mandated label whenever no office is saved (AND-05,
  ADR-013).
- Dependencies added only via `libs.versions.toml`.
- No Hilt or other DI framework (ADR-009 stands).
- **Local commits are permitted; pushing is not.**

## Notes for the next session

- The assessment PDF **loses text across the p2/p3 boundary** (AMB-01, RF-03). Confirmed at
  character level — do not re-investigate.
- The Android screenshot is **prescriptive**; the Flutter screenshots are **advisory**
  ("Suggested UI"). The matrix preserves this distinction (RF-04) — do not flatten it.
- Two release APKs are planned, not one (AMB-09).
- Nothing may be marked `DONE` without executing its own verification method. A passing JVM
  suite is not evidence for a row whose method is a UI test or a device check.
