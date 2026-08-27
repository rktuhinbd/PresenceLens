# AI Usage Log

Source record for README §3, which the assessment makes **mandatory** (DOC-05, DOC-06).

Recorded as work happens, not reconstructed at the end. Per AGENTS.md, AI output is
assistance, not authority: nothing is retained that the author cannot explain.

## How to read this

Each entry names the tool, model, purpose, a summary of the prompt (not its full
text), what came back, and whether a human has verified it. The **Human verification**
column is the one that matters — an unverified entry is a liability, not a
contribution.

---

## Entry 001 — Requirements extraction and planning-system authoring

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | G0.1 — Requirements & Architecture Freeze |
| **Purpose** | Extract every explicit requirement from the assessment PDF and build the durable planning/compliance system before any feature code exists. |

**Prompt summary.** Read the governing documents and the assessment PDF; extract all
explicit requirements into a traceable matrix with stable IDs, planned implementation,
and a verification method per row; propose the smallest senior-level architecture for
both applications; record ADRs for five named decisions; separate verified research
from open questions; produce a gated execution plan and a binary submission checklist.
Explicit constraints: no feature implementation, no Android source or build changes,
no new dependencies, no commits, and do not reconstruct requirements from assumptions
if the PDF cannot be read.

**Method.** The PDF was extracted three independent ways — `pdftotext -layout`,
`pdftotext -raw`, and `pdfplumber` word-level positions — and the results
cross-checked. All three embedded screenshots were rendered at 8x and read visually,
since two assessment requirements (AND-10, FLT-17/18) point at screenshots rather than
at sentences.

**Result.**

- 64 requirements extracted across six ID groups; 15 ambiguities recorded.
- 11 ADRs proposed at authoring time (a twelfth, ADR-012, was added at human review).
- Eight planning documents authored under `docs/`.

Four findings came out of the extraction that materially change the plan:

1. **The PDF loses text across the page 2/3 boundary.** Page 2 ends mid-sentence at
   `buttons (0.5x, 1x, ..` and page 3 resumes at `available back cameras).`
   Character-level inspection confirmed no hidden text — the content is missing from
   the source document. Rather than guess the zoom presets, the design derives them
   from the device's reported range, which is correct under any completion of the
   sentence (AMB-01, FLT-05).
2. **The two UI screenshots carry different authority.** Android is "Please refer to
   the following screenshot for building the UI" (prescriptive); Flutter is "Suggested
   UI" (advisory). The matrix preserves the distinction instead of treating both the
   same way (RF-04).
3. **The Android reference shows "AVAILABLE 09:00 AM - 10:30 AM"**, which no sentence
   in the assessment requires. Enforcing it would contradict the explicit 50 m rule;
   dropping it would lose a detail from a prescriptive screenshot. Escalated as
   ADR-011 rather than decided silently.
4. **The release build has no signing config**, so `assembleRelease` would produce an
   unsigned, non-installable APK — a direct threat to the APK deliverable that would
   otherwise have surfaced at the very end (RF-09, B-01, ADR-010).

**Human verification.** COMPLETE — 2026-08-28 (see Entry 002).

- [x] The extracted requirement text matches the PDF.
- [x] No requirement was invented, and none was downgraded.
- [x] The ambiguities are real, not artefacts of extraction.
- [x] The proposed architecture is one the author can defend in an interview.
- [x] ADR-003, ADR-010, and ADR-011 adjudicated.

**Limitation at authoring time.** No web research was performed, so no ADR resting on
an external technical claim was marked `ACCEPTED`. That limitation was the correct
call: the human subsequently supplied the missing verifications from official Android
Developers documentation, and three ADRs moved to `ACCEPTED` on evidence rather than
on the agent's recollection.

---

## Candidate prompts for README §3

DOC-06 requires "some of the essential prompts". These are the load-bearing ones so
far — prompts that changed the shape of the work, not routine requests. To be
finalised at G8.

1. *Requirements freeze* — "Read the assessment PDF and extract every explicit
   requirement into a matrix with stable IDs, planned implementation, and a
   verification method per row. If you cannot read the PDF, stop and say so — do not
   reconstruct requirements from assumptions."
   **Why it mattered:** the refusal-to-guess clause is what forced the page-boundary
   text loss (AMB-01) to be reported as a source defect instead of quietly invented.

2. *Decision discipline* — "If a decision requires external technical verification,
   mark it PROPOSED rather than pretending certainty."
   **Why it mattered:** kept ADR-001 honest. Its geofence-radius justification was
   left unverified rather than asserted — and the human then confirmed it from
   official documentation, which is exactly the intended workflow.

3. *Scope containment* — "Do not implement application features. Do not modify Android
   source or build files. Do not add dependencies."
   **Why it mattered:** made planning a real gate rather than a preamble that gets
   overtaken by code.

4. *Anti-theatre constraint* — "Propose the smallest senior-level architecture that
   satisfies the assessment. Avoid architecture theater."
   **Why it mattered:** produced ADR-004 (single module) and ADR-009 (no DI framework)
   as reasoned restraint rather than defaults.

---

## Logging rules

1. One entry per meaningful AI-assisted decision or implementation. Routine
   autocomplete is not logged.
2. Summarise prompts; do not paste whole sessions.
3. **Human verification is required before any AI-assisted work is treated as
   complete.** An entry with a pending verification column is not done.
4. Anything the author cannot explain is removed, not shipped (AGENTS.md).
5. Log entries as work happens — reconstructing them at G8 yields a weaker and less
   truthful README §3.

---

## Entry 002 — G0.1 human review and documentation correction pass

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | G0.1 — Requirements & Architecture Freeze (closing) |
| **Purpose** | Apply the human's review decisions to the documentation set. Documentation-only; no application, build, or dependency files touched. |

**Prompt summary.** The human returned adjudicated decisions: accept ADR-001, ADR-002,
ADR-003 (with explicit design intent), and ADR-011; keep ADR-010 `PROPOSED` and defer
it to the release gate; close `ER-01` and resolve the CLI-build assumption using
externally verified findings; and add a new accepted ADR for Android visual direction
— *reference-layout fidelity with premium native Material 3 execution*. Update only
the affected documents, without unnecessary rewriting.

**Human-supplied verified findings** (official Android Developers documentation,
verified by the reviewer — recorded as `RF-17` to `RF-19`):

- AGP 9+ provides built-in Kotlin support enabled by default, so the missing
  `org.jetbrains.kotlin.android` plugin is expected, not a defect.
- Android recommends roughly 100–150 m minimum geofence radii for best results, which
  is what makes `GeofencingClient` the wrong tool for a 50 m on-screen rule.
- DataStore targets small, simple datasets; Room is for complex datasets, partial
  updates, or referential integrity.

The reviewer also verified command-line builds directly from PowerShell — sync, clean,
`assembleDebug`, and emulator launch all pass (`RF-20`), removing the last open build
assumption.

**Result.** ADR count 11 → 12; `ACCEPTED` 6 → 10; `PROPOSED` 5 → 2. Two research
questions closed, one narrowed, one device assumption resolved. G3's budget increased
from 9h to 11h to fund ADR-012, drawn from schedule slack rather than another gate.

**Judgement applied — worth noting.** ADR-012's quality bar is a presentation standard
with no behavioural authority. It is recorded explicitly as unable to alter AND-08 or
to license the availability caption to gate anything, so a later session cannot use
"make it better" to justify a requirement change.

**Human verification.** PENDING — the author should confirm the ADR-012 wording
matches their design intent, and that no mandated requirement shifted during the pass.

**Not done, deliberately.** ADR-010 (release signing) remains `PROPOSED` and unchosen
per the human's instruction; blocker B-01 is retained so it resurfaces at G8.

---

## Entry 003 — G1 Android foundation: dependency research and Hilt evaluation

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Sonnet 5 |
| **Gate** | G1 — Android Foundation |
| **Purpose** | Turn the Android bootstrap into a foundation ready for feature work: resolve the two open research questions blocking dependency choices, add only the minimal dependency set the accepted architecture requires, and author Android-scoped AI guidance files — without implementing any attendance feature logic. |

**Prompt summary.** Read PROJECT_STATE.md, REQUIREMENTS_MATRIX.md, ARCHITECTURE.md,
DECISIONS.md, and EXECUTION_PLAN.md first. Inspect the current project and report its
toolchain. Propose the minimal dependency set for the accepted architecture,
critically evaluating whether Hilt earns its place in a one-screen, single-module app
rather than adding it by default. Create `android-attendance/AGENTS.md` and
`android-attendance/CLAUDE.md`. Explicitly out of scope: `AttendanceScreen`,
location tracking, distance calculation, persistence behaviour, attendance
eligibility, final UI.

**Method.** `ER-02` and `ER-04` explicitly forbid answering from memory — the
toolchain (AGP 9.3.2, Kotlin 2.2.10, Compose BOM 2026.02.01) is recent enough that
recalled artifact versions would be a guess. Live web research (`WebSearch`/
`WebFetch` against `developer.android.com`, `developers.google.com`, and
cross-checks on `mvnrepository.com`) confirmed current stable coordinates before any
were pinned.

**Result.**

- `ER-02` and `ER-04` closed (`RF-21`, `RF-22`); two additional findings recorded for
  traceability (`RF-23`, `RF-24`).
- Dependencies added: `com.google.android.gms:play-services-location:21.4.0`
  (ADR-001), `androidx.datastore:datastore-preferences:1.2.1` (ADR-002),
  `androidx.lifecycle:lifecycle-viewmodel-compose` and `-runtime-compose:2.11.0`
  (ADR-006), `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0` (declared
  explicitly rather than relied on transitively, since `domain`/`data` use `Flow`
  directly). `lifecycle-runtime-ktx` bumped to the same `2.11.0` to keep one
  lifecycle version in the catalog.
- **Hilt rejected.** The object graph at G1 is a location source, a coordinate
  store, a pure rule, and one ViewModel — small and shallow enough that
  constructor injection delivers the property that matters (every collaborator
  substitutable in tests) without annotation processing or a composition
  framework. This confirms ADR-009 rather than reopening it; no new ADR was
  needed since the decision was already recorded and did not change.
- `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` declared in the manifest
  (declaration only). Template `ExampleUnitTest`/`ExampleInstrumentedTest`
  removed. Build re-verified: `clean`, `assembleDebug`, `testDebugUnitTest` all
  pass.
- **Deliberately not done:** the `domain`/`data`/`presentation` package skeleton.
  EXECUTION_PLAN.md lists it under G1, but PROJECT_STATE.md's own "first actions"
  list for this gate does not, and empty packages with no classes yet would be
  scaffolding without content. Left for the start of G2, when `AttendanceRule` and
  friends give the packages something real to hold.

**Human verification.** PENDING — the author should confirm the dependency
versions and the Hilt rejection reasoning before G2 begins building on top of them.

---

## Entry 004 — G2 Android attendance domain & office-location persistence

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Sonnet 5 |
| **Gate** | G2 — Android Location & Domain |
| **Purpose** | Implement the pure domain model and rule behind AND-08 (50 m eligibility), the Haversine distance calculation feeding AND-09, and the DataStore-backed office-location persistence behind AND-07/GEN-03 — vertical-slice only, no GPS, no ViewModel, no UI. |

**Prompt summary.** Read PROJECT_STATE.md, REQUIREMENTS_MATRIX.md, DECISIONS.md,
ARCHITECTURE.md, and `android-attendance/AGENTS.md` first, then implement: a
validated `GeoCoordinates` model; `AttendanceRule` with a named 50 m constant and
exact boundary tests at 0/49.9/50.0/50.1/120 m; a pure Haversine `DistanceCalculator`
with identity/symmetry tests; an `OfficeLocationRepository` interface with a DataStore
Preferences implementation, testable on the JVM without Robolectric or a `Context`.
Explicitly out of scope: FusedLocationProvider, permission UI, `AttendanceScreen`,
the final ViewModel, Google Maps, network submission.

**Method.** Package layout follows ARCHITECTURE.md exactly:
`domain/model` (`GeoCoordinates`, `OfficeLocation`, the `OfficeLocationRepository`
interface — kept in `domain` per ADR-002/ARCHITECTURE.md so implementations stay
swappable behind a fake in future ViewModel tests), `domain/attendance`
(`AttendanceRule`, `DistanceCalculator`, `ProximityResult`), `data/local`
(`DataStoreOfficeLocationRepository`, plus a `Context.officeLocationDataStore`
extension as the production construction seam). The DataStore repository takes a
`DataStore<Preferences>` instance directly rather than a `Context`, so JVM unit tests
construct one with `PreferenceDataStoreFactory.create` against a JUnit
`TemporaryFolder` file — no Robolectric, no Android global state.

**Result.**

- 17 unit tests added, all passing: 5 `GeoCoordinates` validation tests, 3
  `DistanceCalculator` tests (identity, known-distance, symmetry), 5 `AttendanceRule`
  boundary tests, 4 `DataStoreOfficeLocationRepository` tests (absent initially, save
  and read back, overwrite, clear).
- **One real defect found and fixed by the test suite itself:** the exact-50.0 m
  boundary test failed on the first run. Round-tripping a target distance through
  degrees→radians→trig→radians→degrees does not land on a bit-identical value, so a
  distance of exactly 50 m could compute as `50.000000000002` and fail a naive `<=`
  check. Fixed with a documented sub-micrometre epsilon
  (`BOUNDARY_EPSILON_METERS = 1e-6`) in `AttendanceRule` — negligible against any real
  GPS fix's accuracy, but removes floating-point flakiness at the boundary the
  assessment explicitly tests.
- Added `kotlinx-coroutines-test` to the version catalog (test-only dependency) to
  drive the DataStore `Flow` assertions with `runTest`/`UnconfinedTestDispatcher`.
- `testDebugUnitTest` and `assembleDebug` both pass; `git diff --check` clean; diff
  scoped to the intended new domain/data files plus the two catalog/build edits.

**Human verification.** PENDING — the author should confirm the boundary-epsilon
justification is acceptable and that `OfficeLocationRepository` living in
`domain.model` (rather than a separate `domain.office` package) reads as the right
call before G3 wires it into the ViewModel.
