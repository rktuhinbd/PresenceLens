# Project State

Resumption document. Read this first, then the active gate in
[EXECUTION_PLAN.md](EXECUTION_PLAN.md), then only the relevant rows of
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md).

Last updated: 2026-08-28
Overall status: **G1 IN PROGRESS — foundation dependencies added, feature work not started**
Current gate: **G1 — Android Foundation**

## Progress

| Area | State |
| --- | --- |
| Requirements extracted from the PDF | Complete — 64 requirements, 15 ambiguities |
| Architecture defined | Complete (both apps) |
| ADRs | 12 recorded — 10 `ACCEPTED`, 2 `PROPOSED` (ADR-009 technical revisit, ADR-010 deferred to G8) |
| **Android feature implementation** | **0% — not started.** G1 foundation work only: version catalog, manifest permissions, guidance docs. |
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
| Android `assembleDebug` | PASS (PowerShell CLI, re-verified after G1 dependency changes, 2026-08-28) |
| Android `testDebugUnitTest` | PASS — `NO-SOURCE` (template placeholder removed, no replacement tests yet; expected at this gate) |
| Android emulator launch | PASS (verified at G0.1; not re-run at G1) |
| Command-line build viability | **RESOLVED** — PowerShell + Gradle wrapper is the documented path (`RF-20`) |
| Android `assembleRelease` | NOT RUN — would produce an **unsigned** APK (RF-09) |
| Flutter project | **NOT CREATED** |
| Flutter build / tests | N/A |

## Active objective

**G1 — Android Foundation, in progress.** Completed this session (2026-08-28):

1. `ER-02` and `ER-04` resolved via live web research (`RF-21`, `RF-22`) — exact
   artifact coordinates confirmed for Play Services Location and DataStore
   Preferences.
2. Foundation dependencies added to `libs.versions.toml` and
   `app/build.gradle.kts`: `play-services-location:21.4.0`,
   `androidx-datastore-preferences:1.2.1`, `androidx-lifecycle-viewmodel-compose`
   and `androidx-lifecycle-runtime-compose` (bumped shared lifecycle version to
   `2.11.0`, including `lifecycle-runtime-ktx`), and an explicit
   `kotlinx-coroutines-android:1.11.0`. Hilt **evaluated and rejected** — see
   ADR-009; manual constructor wiring stands for this single-module, one-screen
   app.
3. `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` declared in the manifest
   (declaration only — no runtime request or tracking logic).
4. Template `ExampleUnitTest.kt` / `ExampleInstrumentedTest.kt` removed.
5. `android-attendance/AGENTS.md` and `android-attendance/CLAUDE.md` authored,
   scoping Compose-only UI, MVVM/UDF, no business logic in Composables, no
   location logic in the Activity, lifecycle-aware foreground-only location, no
   `GeofencingClient`, DataStore for office coordinates, no Google Maps SDK, the
   ADR-012 visual standard, and the ADR-011 availability-caption rule.
6. Build re-verified: `clean`, `assembleDebug`, `testDebugUnitTest` all pass.

**Not done at G1, deliberately:** no `domain`/`data`/`presentation` package
skeleton yet (no content to put in it before G2 begins), no `AttendanceScreen`,
no location/persistence/eligibility logic. G2 starts that work.

## Completed milestones

1. Repository governance established (AGENTS.md, CLAUDE.md).
2. Android project bootstrapped; baseline build and emulator launch verified.
3. **G0.1 documentation set authored** — requirements matrix, architecture, ADRs,
   research, execution plan, submission checklist, AI usage log.
4. Assessment PDF fully extracted, including all three embedded screenshots.
5. **G0.1 human review completed (2026-08-28).** ADR-001, ADR-002, ADR-003, ADR-011
   accepted; ADR-012 (Android visual direction) added and accepted; ADR-010 deferred
   to G8; `ER-01` and `ER-03` closed; `DA-07` resolved.

## Next gate

**G2 — Android Location & Domain**, once G1 formally closes. No approvals
outstanding; G1 through G3 are all unblocked by the G0.1 review.

Remaining before G1 can close:

- [ ] `domain`/`data`/`presentation` package skeleton (deferred within G1 to
      when there is real content for it — see Active objective above).
- [ ] `git diff` inspected — done this session, scoped to the intended files only.
- [ ] This file updated — done.

First actions in G2:

1. `domain`: `OfficeLocation`, `DeviceLocation`, `AttendanceRule`,
   `ProximityResult`, and the 50 m constant. Write `AttendanceRule` tests first.
2. `data`: `LocationDataSource` (streaming `callbackFlow` + one-shot current
   location per ADR-001/RF-21), `OfficeLocationRepository` on DataStore
   (ADR-002/RF-22), `LocationServiceMonitor`.
3. `presentation`: `AttendanceViewModel` and the sealed `AttendanceUiState`.

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

## Constraints in force at G1

- No `AttendanceScreen` functionality, no location tracking, no distance
  calculation, no persistence *behaviour*, no attendance eligibility logic.
  Foundation only: dependencies, manifest declarations, guidance docs.
- Dependencies added only via `libs.versions.toml` — no hard-coded coordinates.
- No Hilt or other DI framework (ADR-009 stands).
- No commits, no pushes (still an agent-side rule regardless of gate).

## Notes for the next session

- The assessment PDF **loses text across the p2/p3 boundary** (AMB-01, RF-03). This is
  a defect in the source document, confirmed at character level — do not re-investigate.
- The Android screenshot is **prescriptive**; the Flutter screenshots are **advisory**
  ("Suggested UI"). The matrix preserves this distinction (RF-04) — do not flatten it.
- Two release APKs are planned, not one (AMB-09) — the deliverable says "APK" singular
  but the assessment has two apps.
- Nothing may be marked `DONE` without executing its own verification method.
