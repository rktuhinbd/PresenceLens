# Project State

Resumption document. Read this first, then the active gate in
[EXECUTION_PLAN.md](EXECUTION_PLAN.md), then only the relevant rows of
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md).

Last updated: 2026-08-28
Overall status: **G2 IN PROGRESS — Android attendance domain and office-location persistence implemented and unit-tested; no GPS, permissions UI, ViewModel, or AttendanceScreen yet**
Current gate: **G2 — Android Location & Domain**

## Progress

| Area | State |
| --- | --- |
| Requirements extracted from the PDF | Complete — 64 requirements, 15 ambiguities |
| Architecture defined | Complete (both apps) |
| ADRs | 12 recorded — 10 `ACCEPTED`, 2 `PROPOSED` (ADR-009 technical revisit, ADR-010 deferred to G8) |
| **Android feature implementation** | **Domain + persistence vertical slice done (G2).** `AttendanceRule`, `DistanceCalculator`, `GeoCoordinates`, `OfficeLocationRepository`/`DataStoreOfficeLocationRepository` implemented and unit-tested. No GPS integration, permission UI, ViewModel, or `AttendanceScreen` yet. |
| **Flutter application** | **0% — project not created** |
| README / submission artefacts | Not started |

Feature progress is genuinely zero. The Android baseline builds with its new
foundation dependencies, but that is scaffold verification, not evidence for any
assessment requirement.

## Verification status

| Check | Result |
| --- | --- |
| Android Gradle sync | PASS (Android Studio and PowerShell) |
| Android `clean` | PASS (PowerShell CLI, re-verified after G1 dependency changes, 2026-08-28) |
| Android `assembleDebug` | PASS (Bash/Gradle wrapper, re-verified after G2 domain/persistence work, 2026-08-28) |
| Android `testDebugUnitTest` | PASS — 17 tests (5 `GeoCoordinates`, 3 `DistanceCalculator`, 5 `AttendanceRule` boundary, 4 `DataStoreOfficeLocationRepository`), re-verified after G2 domain/persistence work, 2026-08-28 |
| Android emulator launch | PASS (verified at G0.1; not re-run at G1) |
| Command-line build viability | **RESOLVED** — PowerShell + Gradle wrapper is the documented path (`RF-20`) |
| Android `assembleRelease` | NOT RUN — would produce an **unsigned** APK (RF-09) |
| Flutter project | **NOT CREATED** |
| Flutter build / tests | N/A |

## Active objective

**G2 — Android Location & Domain, in progress.** Completed this session (2026-08-28):

1. `domain/model`: `GeoCoordinates` (validated lat/lon range), `OfficeLocation`
   (coordinates + capture timestamp), `OfficeLocationRepository` interface.
2. `domain/attendance`: `AttendanceRule` (the mandated 50 m rule, AND-08, as a
   named `ELIGIBLE_RADIUS_METERS` constant), `DistanceCalculator` (pure
   Haversine, no `android.location.Location`), `ProximityResult`.
3. `data/local`: `DataStoreOfficeLocationRepository` (DataStore Preferences
   implementation of the domain interface, ADR-002) plus a
   `Context.officeLocationDataStore` extension as the production construction
   seam. The repository takes a `DataStore<Preferences>` directly, not a
   `Context`, so it is unit-testable on the JVM.
4. 17 unit tests added and passing: `GeoCoordinates` validation (5),
   `DistanceCalculator` identity/known-distance/symmetry (3), `AttendanceRule`
   boundary at 0/49.9/50.0/50.1/120 m (5), `DataStoreOfficeLocationRepository`
   absent/save/overwrite/clear (4) — the DataStore tests build their own
   temp-file-backed `DataStore` via `PreferenceDataStoreFactory`, no
   Robolectric.
5. One real floating-point boundary bug found and fixed by the test suite: the
   exact-50.0 m case could compute a hair above 50.0 m due to trig round-trip
   noise; `AttendanceRule` now applies a documented `1e-6` m epsilon.
6. `kotlinx-coroutines-test` added to the version catalog (test-only) to drive
   the DataStore `Flow` assertions.
7. Build re-verified: `testDebugUnitTest` (17/17 pass), `assembleDebug` both
   pass; `git diff --check` clean; diff scoped to the new domain/data files
   plus the two catalog/build edits.

**Not done at G2, deliberately:** no `FusedLocationProviderClient` integration,
no runtime permission UI, no `AttendanceViewModel`, no `AttendanceScreen`, no
Google Maps, no attendance submission/network behaviour. Those are G3+.

## Completed milestones

1. Repository governance established (AGENTS.md, CLAUDE.md).
2. Android project bootstrapped; baseline build and emulator launch verified.
3. **G0.1 documentation set authored** — requirements matrix, architecture, ADRs,
   research, execution plan, submission checklist, AI usage log.
4. Assessment PDF fully extracted, including all three embedded screenshots.
5. **G0.1 human review completed (2026-08-28).** ADR-001, ADR-002, ADR-003, ADR-011
   accepted; ADR-012 (Android visual direction) added and accepted; ADR-010 deferred
   to G8; `ER-01` and `ER-03` closed; `DA-07` resolved.
6. **G1 — Android Foundation completed (2026-08-28).** Foundation dependencies
   (Play Services Location, DataStore Preferences, lifecycle-compose,
   coroutines-android), manifest permission declarations, Hilt evaluated and
   rejected (ADR-009), `android-attendance/AGENTS.md` and `CLAUDE.md` authored.
7. **G2 — Android attendance domain and office-location persistence, in
   progress (2026-08-28).** See Active objective above.

## Next gate

**G3 — Android presentation layer** (`AttendanceViewModel`, `AttendanceUiState`,
`AttendanceScreen`, permission UI, FusedLocationProvider wiring), once G2
formally closes. No approvals outstanding.

Remaining before G2 can close:

- [ ] `LocationDataSource` (streaming `callbackFlow` + one-shot current location,
      ADR-001) and `LocationServiceMonitor` — deferred to G3, since they need the
      permission/ViewModel layer to be meaningfully testable and G2's explicit
      scope excluded GPS integration.
- [x] Domain model (`GeoCoordinates`, `AttendanceRule`, `DistanceCalculator`,
      `ProximityResult`) implemented and unit-tested.
- [x] `OfficeLocationRepository` + DataStore implementation, unit-tested.
- [x] `git diff` inspected — scoped to the intended files only.
- [x] This file updated.

First actions in G3:

1. `data`: `LocationDataSource` (streaming `callbackFlow` + one-shot current
   location per ADR-001/RF-21), `LocationServiceMonitor`.
2. `presentation`: `AttendanceViewModel` combining permission status, the
   office-location `Flow`, and the device-location `Flow` into one
   `StateFlow<AttendanceUiState>`; the sealed `AttendanceUiState` hierarchy from
   ARCHITECTURE.md.
3. Runtime permission UI, then `AttendanceScreen` (AND-03/AND-04) rendering the
   p2 reference layout per ADR-012.

## Blockers

| ID | Blocker | Blocks | Notes |
| --- | --- | --- | --- |
| B-01 | Release build defines no `signingConfig`; `assembleRelease` would be unsigned and non-installable. | SUB-03, at G8 only | RF-09. Signing strategy (ADR-010) **deliberately deferred to G8** by human decision. Not a blocker before then, but must not be forgotten — it is the last-mile risk to the APK deliverable. |
| ~~B-02~~ | ~~`ER-03` unanswered (geofence minimum-radius guidance).~~ | — | **RESOLVED at G0.1 review** — `RF-18`; ADR-001 is now `ACCEPTED`. |
| B-03 | Flutter plugin viability unverified (`ER-05`, `ER-06`, `ER-07`). | G4 | Resolve before adding Flutter plugins, not after. |
| B-04 | A physical Android device is required for camera work (`DA-04`) and background-retry verification (`DA-06`). | G5, G6, G7 | Confirm availability before G5 — this is a scheduling risk, not a technical one. |

## Decisions resolved at G0.1 review (2026-08-28)

| ADR | Outcome |
| --- | --- |
| [ADR-001](DECISIONS.md#adr-001) | **ACCEPTED** — foreground, lifecycle-aware Fused Location Provider; no `GeofencingClient`. Android's recommended minimum geofence radius (~100–150 m) is far above this 50 m rule (`RF-18`). |
| [ADR-002](DECISIONS.md#adr-002) | **ACCEPTED** — DataStore for office coordinates; DataStore is for small, simple datasets, Room for complex ones (`RF-19`). |
| [ADR-003](DECISIONS.md#adr-003) | **ACCEPTED** — no Google Maps SDK. Preserve the panel's position and information role via an original dependency-free Compose/vector surface. No Maps branding, no copyrighted tiles, and no implied interactivity. |
| [ADR-011](DECISIONS.md#adr-011) | **ACCEPTED** — the availability caption is preserved as presentation detail and **must not** become an eligibility rule. The 50 m radius stays the only functional condition. |
| [ADR-012](DECISIONS.md#adr-012) | **ACCEPTED, new** — Android visual direction: reference-layout fidelity with premium native Material 3 execution. Preserve the reference information architecture; elevate execution using stable Material 3 only. Presentation authority only. |

## Decisions still open

| ADR | Status | Notes |
| --- | --- | --- |
| [ADR-010](DECISIONS.md#adr-010) | `PROPOSED` — **deferred to G8** | Release signing strategy: generated uncommitted keystore vs debug-signed release. Deliberately not chosen yet, by human decision. |
| [ADR-009](DECISIONS.md#adr-009) | `PROPOSED` | Manual DI instead of Hilt / get_it. Technical revisit only; no approval needed. Reassess if the Flutter background-worker entry point needs shared singletons (G6). |

## Constraints in force at G2

- No FusedLocationProvider/GPS integration, no runtime permission UI, no
  `AttendanceScreen`, no final ViewModel, no Google Maps, no attendance
  submission/network behaviour. Domain and persistence only.
- Dependencies added only via `libs.versions.toml` — no hard-coded coordinates.
- No Hilt or other DI framework (ADR-009 stands).
- No `GeofencingClient` (ADR-001 stands) — irrelevant at G2 since no location
  source exists yet, but binding for G3.
- No commits, no pushes (still an agent-side rule regardless of gate).

## Notes for the next session

- The assessment PDF **loses text across the p2/p3 boundary** (AMB-01, RF-03). This is
  a defect in the source document, confirmed at character level — do not re-investigate.
- The Android screenshot is **prescriptive**; the Flutter screenshots are **advisory**
  ("Suggested UI"). The matrix preserves this distinction (RF-04) — do not flatten it.
- Two release APKs are planned, not one (AMB-09) — the deliverable says "APK" singular
  but the assessment has two apps.
- Nothing may be marked `DONE` without executing its own verification method.
