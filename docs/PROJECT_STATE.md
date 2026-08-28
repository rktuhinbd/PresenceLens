# Project State

Resumption document. Read this first, then the active gate in
[EXECUTION_PLAN.md](EXECUTION_PLAN.md), then only the relevant rows of
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md).

Last updated: 2026-08-28
Overall status: **G3.5 COMPLETE, AWAITING HUMAN SIGN-OFF — Android Task 1 is
implemented end to end, passes all automated verification, and has been driven through
every state on an emulator. The rows whose stated verification method is a Compose UI
test remain `PARTIAL`; a manual walkthrough is not that method.**
Current gate: **G3.5 — Android UX Polish Sprint (complete)**

## Progress

| Area | State |
| --- | --- |
| Requirements extracted from the PDF | Complete — 64 requirements, 15 ambiguities |
| Architecture defined | Complete (both apps) |
| ADRs | 13 recorded — 11 `ACCEPTED`, 2 `PROPOSED` (ADR-009 technical revisit, ADR-010 deferred to G8) |
| **Android feature implementation** | **Complete and polished.** Domain rule, persistence, Fused Location layer, ViewModel + single UI state, permission/service UX, and a state-driven `AttendanceScreen` with every AND-13…AND-21 element ([ADR-013](DECISIONS.md#adr-013)). 70 unit tests pass; emulator walkthrough executed. |
| **Flutter application** | **0% — project not created** |
| README / submission artefacts | Not started |

## Verification status

| Check | Result |
| --- | --- |
| Android Gradle sync | PASS (Android Studio and PowerShell) |
| Android `clean` | PASS (PowerShell CLI, verified at G1) |
| Android `assembleDebug` | PASS — re-verified after the G3.5 UX pass, 2026-08-28 |
| Android `testDebugUnitTest` | PASS — **70 tests**, 0 failures, 2026-08-28 |
| Android `lintDebug` | PASS — **0 errors**, 11 warnings (6 dependency-version advisories, 5 `PluralsCandidate`) |
| `git diff --check` | CLEAN |
| `domain` free of Android imports | PASS — verified by grep over `domain/` |
| 50 m radius is a single constant | PASS — one literal, in `AttendanceRule` |
| No `GeofencingClient` / Maps SDK / background location | PASS — no such dependency or permission exists |
| Office-hours caption does not gate eligibility (ADR-011, ADR-013) | PASS — `availability_caption` removed; `office_hours_label` / `office_hours_value` have one reference each, both `Text` calls |
| Android emulator launch | PASS (verified at G0.1) |
| **Emulator acceptance run of Task 1** | **PASS — executed twice.** By the author before G3.5, and again by the G3.5 walkthrough on `emulator-5554` after the UX pass. See below. |
| Android `assembleRelease` | NOT RUN — would produce an **unsigned** APK (RF-09) |
| Flutter project | **NOT CREATED** |

### Unit test breakdown (70)

| Suite | Tests | Covers |
| --- | --- | --- |
| `AttendanceViewModelTest` | 19 | Permission, approximate-only, services-off, acquiring, unavailable, revoked mid-stream, office-not-set, office restored, per-emission distance, the 50 m boundary in both directions, degraded-fix behaviour, office capture + persistence, capture failure, storage failure, mark-attendance in and out of range, message lifecycle, and subscription teardown |
| `AttendanceStatusPresenterTest` | 14 | All twelve status-card conditions, the action each offers, all six blocked-button reasons, and that the success confirmation does not outlive the eligibility it confirms |
| `AttendanceRuleTest` | 5 | AND-08 at 0 / 49.9 / 50.0 / 50.1 / 120 m |
| `DistanceCalculatorTest` | 5 | Haversine identity, known distance, symmetry; bearing at the four cardinals and its normalisation |
| `DistanceFormatterTest` | 6 | Metres, the kilometre switch, rounding, and non-finite input |
| `ProximityGeometryTest` | 5 | Gauge fraction and marker placement, including the off-panel clamp |
| `GeoCoordinatesTest` | 5 | Latitude/longitude range validation |
| `LocationQualityTest` | 4 | The degraded-accuracy threshold and unreported accuracy |
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

Matrix rows whose verification method is a **Compose UI test** stay `PARTIAL` regardless —
a manual walkthrough is not that method, and inflating them would be exactly the kind of
unearned `DONE` the charter forbids.

## Active objective

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

## Next gate

**Human sign-off on Android Task 1**, then **G4 — Flutter Bootstrap.**

Flutter work has not begun and must not begin until Task 1 is signed off.

Remaining before G3/G3.5 can formally close:

- [ ] Human confirmation of the two interpretive calls in [ADR-013](DECISIONS.md#adr-013):
      the AND-05 Setup-Phase reading, and the "Office hours" relabel of the AND-21 caption.
- [ ] Side-by-side comparison against the p2 reference captured for README §5 (AND-10).
- [ ] Compose UI tests for AND-03/04/05/08/18/20 — deliberately deferred. The AND-05 test
      must assert the mandated label **in the no-office state** (ADR-013).
- [ ] Haptic on the mark-attendance path confirmed on a physical device; an emulator
      cannot show it.
- [x] Location layer, ViewModel, permission UX, and `AttendanceScreen` implemented.
- [x] State-driven UX pass (G3.5) delivered against the approved direction.
- [x] Emulator walkthrough of every state executed, in light and dark.
- [x] 70 unit tests passing; `assembleDebug` and `lintDebug` clean.
- [x] `git diff` inspected; four local commits created; nothing pushed.
- [x] ADR-013 recorded; matrix, AI_USAGE.md and this file updated.

## Blockers

| ID | Blocker | Blocks | Notes |
| --- | --- | --- | --- |
| B-01 | Release build defines no `signingConfig`; `assembleRelease` would be unsigned and non-installable. | SUB-03, at G8 only | RF-09. Signing strategy (ADR-010) **deliberately deferred to G8** by human decision. Not a blocker before then, but it is the last-mile risk to the APK deliverable. |
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
- The office-hours caption is presentation only (ADR-011, ADR-013).
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
