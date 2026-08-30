# AI Usage Log

Source record for README §3, which the assessment makes **mandatory** (DOC-05, DOC-06).

Recorded as work happens, not reconstructed at the end. Per AGENTS.md, AI output is
assistance, not authority: nothing is retained that the author cannot explain.

## At a glance

**How AI was used.** Claude, via the Claude Code CLI, assisted throughout — **Claude
Opus 5** for the majority of gates (requirements extraction, architecture and ADR
drafting, SQLite concurrency and edge-case analysis, implementation, and this final
documentation reconciliation) and **Claude Sonnet 5** for three specific gates: G1 (Android foundation dependency
research and the Hilt evaluation, Entry 003), G2 (Android attendance domain and
office-location persistence, Entry 004), and the Android release-signing gate
(Entry 007). It did not make
final engineering decisions; every retained artefact was reviewed against the
verification named in its own entry.

**Representative real prompts** are recorded verbatim-in-summary in each entry below —
see Entry 001 (requirements extraction), and the later entries covering the camera
lifecycle, the durable upload queue, and the location quality rules.

**How every output was validated.** Nothing was accepted on the model's word:

- **Automated tests** — 679 across both apps (158 Native Android, 521 Flutter).
- **Static analysis** — Android Lint and `flutter analyze`, both clean.
- **Builds** — debug and release builds, including from a clean clone.
- **Source inspection** — every retained line reviewed; per AGENTS.md, nothing is kept
  that the author cannot explain.
- **Device and emulator QA** — physical HONOR DNP-NX9 runtime QA for the Flutter app,
  emulator acceptance walkthroughs for the Native app.

---

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

5. *Naming the wrong answer, not just the right one* — "Concurrency correctness must
   NOT depend on Dart bools, in-memory mutexes, process-local locks, singletons,
   Bloc/Cubit, widget state, or 'only scheduling once'. Those mechanisms do not
   protect multiple DB connections/isolates."
   **Why it mattered:** every one of those would pass a naive test and fail in
   production, which is the worst possible failure mode. Forbidding them by name
   forced exclusion into SQLite (`ADR-F04`, `ADR-F17`) instead of into Dart.

6. *Evidence standard for the riskiest test* — "Write the contention test early, with
   `sqflite_common_ffi` and separate database connections. A fake repository is NOT
   evidence. A test around an in-memory mutex is NOT evidence."
   **Why it mattered:** it is the difference between a test that proves the claim is
   atomic and one that passes regardless. It also surfaced that sqflite hands back the
   *same* connection for one path within an isolate, so the obvious version of the
   test would have proved nothing.

7. *Honesty boundary on unverifiable claims* — "Do NOT claim emulator/device QA. Do not
   claim physical/device background-worker behaviour from JVM tests."
   **Why it mattered:** it is why nine requirement rows are `PARTIAL` rather than
   `DONE` despite the code being complete, and why the worker tests say they assert a
   decision rather than an outcome.

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

**Resolved.** ADR-012 was accepted at the G0.1 human review (2026-08-28), recorded in
[PROJECT_STATE.md](../PROJECT_STATE.md) Completed milestones §5; no requirement
shifted — the matrix's GEN/AND rows trace unchanged to this pass.

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

**Resolved.** G1 closed (PROJECT_STATE.md Completed milestones §6) and G2–G3.8 built
directly on these dependency choices and the ADR-009 Hilt rejection without reversal;
ADR-009 remains the only `PROPOSED` (not `ACCEPTED`) ADR in the set, by deliberate
design — a manual object graph, revisited only if it stopped being small.

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

**Resolved.** Both stand unchanged through to submission: `OfficeLocationRepository`
remains in `domain/model/` in the shipped source, and G3 wired it into the ViewModel
without restructuring the package.

---

## Entry 005 — G3 Android location layer, ViewModel, and AttendanceScreen

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | G3 — Android UI, Polish, Testing |
| **Purpose** | Complete Native Android Task 1 end to end: the real Fused Location layer, the ViewModel and single UI state, runtime permission/service UX, and `AttendanceScreen` against the p2 reference. |

**Prompt summary.** Delivery-sprint mode. Close G2 with a local commit, then implement
the location data layer (FusedLocationProviderClient, foreground only, lifecycle-aware,
`callbackFlow`) with explicit handling for missing permission, approximate-only,
services disabled, acquiring, usable, and failed; the `AttendanceViewModel` with one
coherent `AttendanceUiState` where the UI computes no distance, eligibility, permission
state, or persistence decision; Compose-compatible permission UX with no dialog loop;
and the full `AttendanceScreen` preserving the reference information architecture with
premium native Material 3 execution. Binding constraints: no Google Maps, no API key,
no background location, no `GeofencingClient`, no alpha/preview design libraries, the
availability caption must never gate eligibility, and the 50 m rule must keep coming
from the tested domain component. Authorised to commit locally; not to push.

**Method.** Four decisions are worth recording because they were judgement calls, not
transcriptions of the brief:

1. **Fix accuracy warns, it never blocks.** GEN-04/AMB-14 ask for a low-quality-fix
   state, and it would have been easy to disable Mark Attendance on a wide error
   radius. That would have changed the mandated behaviour: AND-08 names distance as
   the *only* condition. A degraded fix therefore raises a visible caution and changes
   nothing else. Coarse-only *permission* is different and is refused outright, because
   `android-attendance/AGENTS.md` states that approximate location cannot resolve a
   50 m boundary at all.
2. **Lifecycle-awareness has no manual switch.** `collectAsStateWithLifecycle` →
   `stateIn(WhileSubscribed)` → `callbackFlow`'s `awaitClose` means leaving the screen
   removes the platform callback with no start/stop call for a future maintainer to
   forget. This is asserted, not assumed: `FakeLocationDataSource` counts live
   subscriptions and a test proves the count returns to zero.
3. **`AttendanceUiState` is one data class holding a sealed `AttendanceStatus`, not a
   sealed hierarchy at the top level.** ARCHITECTURE.md specifies a sealed hierarchy;
   the property it exists for is that a distance cannot be rendered without a fix. That
   property is preserved exactly — the distance lives inside `Tracking` — while the
   screen's always-present sections stay renderable in every state, which a top-level
   sealed type would have made awkward for a single-surface screen (AND-04).
4. **No icon dependency.** Compose Material3 1.4.0 no longer brings
   `material-icons-core` onto the classpath. Rather than add a dependency for nine
   glyphs, the icons are project-owned stroked vector drawables — which also removes
   any third-party asset-licence question from a public submission (SUB-01).

The Task-to-coroutine bridge for `getCurrentLocation` is six hand-written lines rather
than an added `kotlinx-coroutines-play-services` dependency, for the same reason.

**Result.**

- 39 unit tests added (56 total, all passing): 19 `AttendanceViewModel` state-behaviour
  tests against hand-written fakes, plus `LocationQuality`, `DistanceFormatter`,
  `ProximityGeometry`, bearing, and repository tests.
- `assembleDebug` passes; `lintDebug` reports **0 errors** (10 warnings: six
  dependency-version advisories against the toolchain deliberately pinned at G1, and
  four `PluralsCandidate` notices on strings whose only numeric argument is the fixed
  50 m radius).
- **A pre-existing test defect was found and fixed.** Two of G2's four DataStore tests
  were failing on this Windows host and had been masked by a cached Gradle result — the
  suite had not actually re-run since it was written. DataStore commits a write by
  renaming a temp file over the target, and `File.renameTo` on Windows refuses to
  overwrite an existing file, so *any* second write failed. This is a host-filesystem
  limitation, not Android behaviour and not a defect in the repository. Multi-write
  behaviour (overwrite, clear) and read-failure recovery now run against an in-memory
  `DataStore<Preferences>`; the real file-backed round trip is retained separately.
  The claim of "17 passing tests" in the G2 record was therefore stale when written.
- Three local commits created: the G2 milestone, the location layer, and the screen.

**Human verification.** PENDING — the author should (a) run the emulator verification
steps in PROJECT_STATE.md, (b) confirm the accuracy-warns-never-blocks reading of
AMB-14 is the intended one, and (c) confirm the restructured DataStore tests are an
acceptable response to the Windows rename limitation rather than something to solve by
changing the persistence layer.

**Resolved, with one revision.** (a) The emulator walkthrough was run repeatedly
(G3.5, G3.6, G3.8) and again as a physical-device screenshot session at submission.
(c) The DataStore test restructuring stands unchanged in the shipped suite.
(b) **Superseded, not simply confirmed:** the original "warns, never blocks" reading
of AMB-14 was later revised by [ADR-015](../DECISIONS.md#adr-015) at G3.8 — a fix
wider than the 50 m radius now fails closed rather than only warning, because a fix
that coarse cannot measure the boundary at all. AMB-14's resolution note in
[REQUIREMENTS_MATRIX.md](../REQUIREMENTS_MATRIX.md) reflects the final, revised rule.

---

## Entry 006 — G3.5 Android UX polish sprint

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | G3.5 — Android UX Polish Sprint |
| **Purpose** | Raise the attendance screen from "every prescribed element present" to a state-driven experience, against a human-supplied UX direction of ten numbered directives. |

**Prompt summary.** The human supplied the direction in full and it was not invented
here: keep one `AttendanceScreen`; add a first-use setup state; add a dynamic status
card covering eight named conditions; state the reason beside a disabled Mark
Attendance; relabel the misleading availability caption to "Office hours" without
letting it affect eligibility; reduce the prominence of "Set Office Location" once an
office exists and guard the overwrite with a confirmation; add a small "how attendance
works" surface; refine the no-Maps location panel; add a compact success state with
haptics; hold to native Material 3 with 48 dp targets and accessible contrast.
Explicit prohibitions: do not change the 50 m rule, do not add screens, Maps SDK,
backend behaviour, or Flutter, and do not push.

**Method.** Presentation logic was extracted rather than written inline. Twelve status
conditions and six "why is this disabled" reasons are resolved by
`AttendanceStatusPresenter`, a pure function with no Android imports, so the mapping is
unit-testable on the JVM and `android-attendance/AGENTS.md`'s "no decisions in
Composables" rule survives a much larger surface. The screen was then driven through
every state on `emulator-5554` and each state read back as a screenshot.

**Decisions taken, and why.**

1. **AND-05 was re-read rather than overridden.** The assessment names the exact label
   under the heading "Setup Phase". A screen with a saved office is no longer in that
   phase, so "Set Office Location" is preserved verbatim in the no-office state and the
   control becomes "Change office location" afterwards. Recorded as
   [ADR-013](DECISIONS.md#adr-013), and the matrix now says a Compose UI test for
   AND-05 must target the no-office state.
2. **The availability caption was relabelled, not removed or enforced.** ADR-011
   already ruled it presentation-only; "AVAILABLE 09:00 AM - 10:30 AM" was the last
   place the app still implied a rule that does not exist. Position and value are
   unchanged.
3. **The distance panel is not drawn before an office is saved.** A gauge with no
   reference point is a dial the user must learn to ignore. The reference screenshot
   depicts a state that has an office, so no prescribed element is lost.
4. **The success confirmation does not outlive its eligibility.** Walking out of range
   returns the screen to guidance rather than leaving "Attendance marked" on a screen
   where attendance is no longer possible. This is pinned by a test.
5. **The snackbar for a successful mark was dropped.** Status card, panel line, and
   haptic already confirm it; a fourth confirmation of one event is noise.
6. **The dark `errorContainer` was deepened** from the Material baseline. "Out of
   range" is a routine condition, and at baseline saturation a full-width card in that
   role read as an alarm every time the user was merely not at the office yet.

**Two defects were found by looking at the running app, not by reading the code.**
The location panel's new legend named an "Office" and a "You" marker in the first-use
state where neither is drawn — it was advertising markers that did not exist. It now
lists only markers actually rendered, and the setup state draws the live position at
the centre of the dashed preview ring, since that position *is* what a capture would
record. Separately, section spacing was rebuilt to come from each section's own
padding: `Arrangement.spacedBy` leaves a gap behind when a section collapses.

**Result.**

- 14 unit tests added (**70 total, all passing**), covering all twelve status
  conditions, all six blocked reasons, and the confirmation's dependence on
  eligibility.
- `assembleDebug` passes; `lintDebug` reports **0 errors** (11 warnings: six
  dependency-version advisories against the toolchain pinned at G1, and five
  `PluralsCandidate` notices on strings whose only numeric argument is the fixed 50 m
  radius).
- **Emulator walkthrough executed** on `emulator-5554`: permission prompt, first-use
  setup, office capture, in-range enablement, mark attendance, out-of-range
  disablement at 255 m, persistence across force-stop and reinstall, the overwrite
  confirmation, the disclosure sheet, and light + dark rendering.
- ADR-013 recorded; matrix rows AND-05, AND-10, AND-13…AND-21, GEN-04 and GEN-08
  updated with the new evidence.

**Human verification.** PENDING — the author should (a) confirm the AND-05 reading in
ADR-013 is the intended one, since it is the single interpretive change in this pass,
(b) confirm the office-hours relabel is acceptable against the prescriptive screenshot,
and (c) sanity-check the haptic on a physical device, which an emulator cannot show.

**Resolved for (a) and (b); (c) remains an accepted residual.** Both ADR-013
interpretive calls were "ruled on and accepted" at G3.6 (PROJECT_STATE.md). The haptic
on the mark-attendance path was never separately confirmed on physical hardware —
it is recorded honestly as an accepted residual in
[PROJECT_STATE.md §Next gate](../PROJECT_STATE.md), not claimed.

---

## G3.6 — Location-state stability and the final UX pass (2026-08-28)

**Prompt (abridged).** A human-supplied brief with two halves. First, a **correctness bug**:
a screen recording of a stationary emulator showed
`Ready to mark attendance → Location unavailable → Ready to mark attendance` cycling every few
seconds. The brief required root-causing it before changing behaviour, forbade a debounce
("fix the state model"), and supplied one platform fact to preserve — Play Services documents
`LocationAvailability` as an estimate, so `isLocationAvailable == false` must not on its own
produce a hard failure while services are on, permission is valid, and a recent usable fix
exists. It specified the seven states the screen should model, asked for **one** clearly named
freshness threshold (~10 s unless inspection justified otherwise), and listed six regression
tests. Second, a **final UX pass**: 15–20% less vertical density, less first-use repetition
with four target strings given verbatim, "attendance" terminology throughout, a completed
success CTA, concise product copy, and an explicit do-not-regress list. It also ruled ADR-013's
two open interpretive calls ACCEPTED.

**What the AI was asked to decide, and what it decided.**

**1. The root cause — found by inspection, not assumed.** The brief named nine places to look
and forbade guessing. Reading them in order located the defect in two lines of
`FusedLocationDataSource`: `onLocationAvailability` mapped the availability *estimate* straight
to `LocationFix.Unavailable`, and `AttendanceViewModel` treated any `Unavailable` as terminal —
discarding the position it was holding. The two-second period of the observed flicker matched
`UPDATE_INTERVAL_MILLIS` exactly, which is what confirmed the diagnosis before any code changed.
A second instance of the same mistake sat beside it: an empty `LocationResult` was also mapped
to a failure, when it carries no information at all.

**2. The shape of the fix.** The brief ruled out a debounce, correctly — a debounce delays a
wrong answer rather than stopping the production of one. The chosen model separates *what the
platform said* from *what the app knows*: raw fixes fold into `LocationKnowledge`, and what the
screen may claim (`LocationReading`) is derived from that knowledge plus the age of the last
fix. An availability estimate can no longer discard a position already held, because it is no
longer the thing that decides.

**3. The threshold — 10 s, taken rather than inherited.** The brief offered ~10 s "unless
inspection reveals a better technically defensible value". Inspection *supported* it, from two
directions: it is five consecutive missed deliveries at the existing 2 s update cadence, well
above the one-or-two-sample gaps a stationary device produces; and at walking pace it is about
14 m of possible drift, inside both the 50 m rule and the 25 m accuracy the app already
tolerates. Both arguments are written at the constant and pinned by `LocationFreshnessTest`,
including a test asserting the drift stays under the accuracy tolerance — so the reasoning
fails loudly if someone later widens the number.

**4. One judgement the AI made that the brief did not specify.** The brief reserved "Location
unavailable" for a genuine inability "after the normal acquisition path". Left literally, an
app that had *never* obtained a fix while the provider reported it could not obtain one would
sit on "Finding your location…" forever, and `LOCATION_UNAVAILABLE_NO_FIX` would become an
unreachable state — a smell, not a feature. The escalation therefore uses the same single
threshold as its acquisition window: never held a position, window passed, provider says it
cannot get one → real failure. One number, two uses, both meaning "this is how long we wait
before saying we do not have a position". Conversely, a position that is merely *stale* never
escalates however old it gets, which is a deliberate asymmetry: "Updating your location…" stays
true, and the brief is explicit that a red state must not be the reaction to a quiet provider.

**5. Where the AI declined to widen scope.** The stale state keeps the last marker on the
location surface (so nothing blinks) but produces no distance, because `AttendanceUiState`'s
invariant — no distance without a fix — is what makes AND-08 unrepresentable in a wrong state.
Carrying a "greyed-out distance" would have read slightly better and cost that invariant. The
invariant won.

**Verification, including the part that could be automated.** The emulator half of this pass
was driven rather than eyeballed: `adb emu geo fix` for movement, `settings put secure
location_mode` for the services toggle, and `uiautomator dump` to read the status card back as
text so the result is a transcript rather than an impression. That is what makes the central
claim measurable — **30 samples over ~70 s on a stationary device, all "Ready to mark
attendance"**. The same method measured the density change: the span from the status-card title
to the "OUT OF RANGE" chip fell from **2288 px to 1853 px (19%)**, taken from a build of the
previous commit and a build of this one on the same device, rather than estimated from the dp
values changed.

**Result.**

- **20 unit tests added (90 total, all passing)** — eight ViewModel stability cases, two
  presenter cases, six `LocationFreshnessTest` cases, and four other gaps the pass exposed.
- `assembleDebug` passes; `lintDebug` reports **0 errors** (10 warnings: six dependency-version
  advisories against the toolchain pinned at G1, four `PluralsCandidate`).
- Eight manual checks executed on `emulator-5554`, all passing, recorded in PROJECT_STATE.md.
- ADR-014 recorded; ADR-013 marked ACCEPTED with both rulings; matrix rows AND-06, AND-07,
  AND-08, AND-09, GEN-01, GEN-04 and AMB-13 updated. AND-07 moved to `DONE` — its stated
  verification method is the force-stop/relaunch check, and that check was executed.

**Honest limitation.** The `LocationAvailability` → advisory mapping in `FusedLocationDataSource`
has no automated test: it is Play Services-facing and the project deliberately carries no
Robolectric or mocking framework. Its ViewModel counterpart is covered by four JVM regression
cases, and the emulator soak is the data-source half's evidence. This is stated rather than
papered over, because a reviewer reading the regression suite would otherwise reasonably assume
both halves are pinned.

**Human verification.** PENDING — the author should re-run the eight manual checks on their own
device, and confirm the haptic on physical hardware, which an emulator cannot show.

**Resolved for the manual checks; haptic remains an accepted residual.** The
emulator walkthrough was re-executed at G3.8 after further changes, and the app was
subsequently confirmed live on physical HONOR hardware at submission. Haptic
confirmation on physical hardware was never separately performed — same accepted
residual noted above, not silently dropped.

---

## Entry 007 — Android release signing (ADR-010 resolved)

| Field | Value |
| --- | --- |
| **Date** | 2026-08-28 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Sonnet 5 |
| **Gate** | Release preparation — human explicitly authorised proceeding ahead of the general G8 gate, resolving ADR-010's deferred choice now rather than later |
| **Purpose** | Produce a signed, installable release APK for external distribution (Google Drive), resolving blocker B-01. |

**Prompt summary.** Generate a dedicated local release keystore (not the debug key),
wire optional Gradle release signing that never hard-codes secrets and still lets a
clean clone build both debug and unsigned release, verify the signature with
`apksigner`, install and smoke-test the signed build, copy the final artifact with a
SHA-256 checksum, and record the decision — all without printing passwords, committing
secrets/binaries, or pushing.

**What the AI did.**

1. **Keystore.** Generated `presencelens-attendance-release.jks` with `keytool`
   (RSA 2048, 10 000-day validity — until 2054), alias `presencelens-attendance`, and an
   assessment-appropriate identity (`CN=PresenceLens Assessment, O=Independent
   Assessment, L=Dhaka, C=BD` — no claim to represent Intelligent Machines or bKash).
   Store and key passwords were generated locally (32-character random alphanumeric,
   via `/dev/urandom`), written straight into `key.properties`, and the temporary files
   holding them were deleted immediately after. Neither password was printed at any
   point in this session.
2. **Gradle wiring.** `app/build.gradle.kts` reads `key.properties` (via `rootProject
   .file`) only if it exists; when present it defines a `release` `signingConfig` from
   the properties; when absent, `assembleRelease` still succeeds but produces an
   unsigned APK. No secret value appears in the Gradle file itself.
3. **Git safety audited before and after**, not assumed: `git check-ignore -v` on
   `key.properties`, the `.jks`, and the copied release APK all resolved to the correct
   `.gitignore` patterns (lines 52/54/44) before any file was written and again after.
   `git status --short` was inspected for anything unexpected.
4. **Build verification, in the required order.** `clean` → `testDebugUnitTest` (90
   tests, pass) → `lintDebug` (0 errors) → `assembleRelease` (success,
   `validateSigningRelease` and `writeReleaseSigningConfigVersions` both ran, confirming
   the signing config was actually applied). No R8/ProGuard settings were touched —
   `optimization { enable = false }` was left exactly as it was.
5. **Signature verification.** `apksigner verify --verbose --print-certs` against
   build-tools 36.1.0 confirmed the APK verifies, is signed with APK Signature Scheme
   v2, and carries the expected certificate DN and a 2048-bit RSA key.
6. **Install and smoke test** on the already-running `emulator-5554`: uninstalled the
   existing debug-signed install first (a same-package, different-signature APK cannot
   overwrite-install), installed the release APK, launched it, granted location
   permission, and confirmed via screenshot and `logcat` (`AndroidRuntime`/`FATAL`
   filter) that the app launches cleanly, the permission flow fires, and the
   AND-05 Setup Phase ("Set Office Location") face is reachable — no crash.
7. **Artifact finalised** at `android-attendance/release-artifacts/
   PresenceLens-Attendance-v1.0.0.apk` with a sibling `.sha256.txt` computed from the
   copied file (not assumed equal to the build output).

**Where the AI diverged from the literal instruction, and why.** The instruction
suggested trying a PKCS12 conversion note from `keytool`'s own output; a first attempt
at `-importkeystore` to PKCS12 failed non-interactively (PKCS12 requires identical
store/key passwords, which conflicts with generating two independent secrets) and
prompted for interactive input that this session cannot supply. Rather than weaken the
credential model to fit PKCS12, the keystore was regenerated cleanly as JKS — a fully
supported format for `apksigner` and Play-style signing — and the failed conversion
artifact was discarded before use.

**ADR-010 resolution.** The deferred decision — generated release keystore versus
debug-signed release — is resolved in favour of the generated keystore, exactly the
preferred option ADR-010 already named. Recorded in DECISIONS.md.

**Human verification.** Build, lint, test, `assembleRelease`, `apksigner verify`, and
the install/launch smoke test were all executed and their output inspected in this
session — not asserted from memory. **Partially resolved.** The final side-by-side
install check ran at submission: both `PresenceLens-Attendance-v1.0.0.apk` and
`PresenceLens-Capture-v1.0.0.apk` were downloaded fresh from the published v1.0.0
GitHub release and installed side by side on a physical HONOR DNP-NX9 with no ID
collision (`io.github.rktuhinbd.presencelens.attendance` /
`io.github.rktuhinbd.presencelens.capture`). **Still not independently confirmable
from an AI session:** whether the author personally made an off-repository backup of
`key.properties` and the `.jks` file — that fact lives outside anything a session can
observe, and is not claimed here.

## Entry 008 — G3.7 Android success-state refinement

**Date.** 2026-08-28
**Model / tool.** Claude Opus 5 via Claude Code.

**Human prompt, in substance.** After reviewing the built app on a real device, the
human rejected the post-attendance presentation as redundant: the completed state said
"ATTENDANCE MARKED", showed a large button-shaped surface also reading "Attendance
marked", drew a green success border around both, and left the eligible-distance copy
still explaining that Mark Attendance was unlocked. The brief was narrow and explicit —
refine the success state only, keep everything before the mark unchanged, remove the
completed "button", replace it with a compact confirmation carrying the time and the
verified distance, make the top status card read as complete, shorten the eligible
distance copy, and freeze every business rule, the location layer, persistence, the
architecture, the signing identity, and Flutter. The human supplied the intended copy
and information hierarchy.

**What the AI did.**

1. **Made "the screen has finished its job" a single derived value.**
   `AttendanceUiState.isAttendanceConfirmed` is read by the status-card presenter, by
   the action area, and by the new `AttendanceStatusPresenter.markAttendanceAction`, so
   the headline, the confirmation, and the availability of the action cannot disagree.
2. **Replaced the completed control rather than restyling it.** `MarkAttendanceAction`
   is a closed set — `AVAILABLE`, `BLOCKED`, `COMPLETED` — because "completed" is not a
   shade of "disabled". In `COMPLETED` the panel renders no `Button`, no dashed/solid
   outline and no overline; a `uiautomator` dump of the running app was used to confirm
   no `Mark Attendance` node and no clickable node survives in that state.
3. **Captured the verified distance at the moment of the mark.** `MarkedAttendance`
   (time + distance) replaces the bare timestamp, so "Location verified · 1 m from
   office" states the reading the 50 m rule was applied to rather than a live value that
   drifts afterwards. The 50 m rule, the Haversine calculation, the freshness policy and
   the data sources were not touched.
4. **Semantics.** The confirmation is one node with one sentence
   (`clearAndSetSemantics`), announced as a statement — TalkBack no longer meets a
   control-shaped element that cannot be pressed.

**Where the AI exercised judgement beyond the literal instruction.** The supplied
sketch put the confirmation in the success colour role. Rendered, that produced two
saturated green blocks repeating the same headline — the repetition the sprint existed
to remove. The confirmation was demoted to the screen's own `surfaceContainerLow` card
role with the check keeping the success colour, so the green announcement stays
singular. The sketch's three stacked lines were also folded into two, with the time on
the trailing edge, which is what makes the target footprint reduction achievable; both
changes are within the brief's stated permission to improve the layout, and are flagged
here rather than buried.

**Verified, not assumed.** `clean` → `testDebugUnitTest` (**95 tests**, 0 failures) →
`assembleDebug` → `lintDebug` (0 errors) → `git diff --check`. The before/after states
were driven on `emulator-5554` in both light and dark: the ready face is unchanged and
still actionable, the marked face carries one headline, one receipt, the live distance
context and Office hours, and the attendance region's measured height falls from 467 px
to 300 px (**~36 % shorter**). Leaving the radius was exercised and still retires the
confirmation and restores the locked CTA; returning restores the confirmation with its
originally verified time and distance.

---

## Entry 009 — G3.8 Android accuracy and architecture hardening

**Date.** 2026-08-29
**Model / tool.** Claude Opus 5 via Claude Code.

**Human prompt, in substance.** The previous session was an audit only. This one was
handed its findings as an approved work list and told to implement exactly those, with an
unusually explicit set of guardrails on both sides: restore high-accuracy first delivery,
add a live accuracy usability policy, make the office capture fresh-only and quality-gated,
decouple "Set Office Location" from the live stream, make provider failures recoverable,
move the location state machine into `domain`, add **exactly one** use case, fix the
attendance-confirmation lifetime, tighten the Haversine test around 50 m, and stop
describing the architecture as strict Clean Architecture. Equally explicit about what **not**
to do: no change to the 50 m rule, no `distance + accuracy <= 50`, no averaging or
best-of-N calibration, no raw GNSS, no Kalman filtering, no mock-location detection, no
persisted capture accuracy, no extra use cases, no UI redesign, no new dependency, no
Flutter, no push.

**What the AI did.**

1. **Raised a documented conflict before implementing, rather than after.** Part H of the
   brief asked for event semantics on the attendance confirmation and added: *if the
   current behaviour is strongly established in source and docs, report the conflict
   before changing it.* It was — ADR-013 §7, reaffirmed in the G3.7 revision, plus KDoc in
   three places and a passing test. The AI stopped, stated exactly where the rule was
   written and what changing it would cost, offered three options, and implemented only
   after the human ruled. That ruling is [ADR-016](DECISIONS.md#adr-016), and it is
   recorded as a supersession rather than edited into ADR-013 so the earlier reasoning
   stays readable.
2. **Isolated a pre-existing working-tree change instead of absorbing it.** The tree
   carried an uncommitted office-hours copy change (`10:30 AM` → `5:00 PM`) alongside a
   `rememberSaveable` → `rememberSavable` comment typo. The typo was reverted; the copy
   change was committed **separately, before the hardening work**, with its divergence
   from ADR-013 §5's "keeps the reference's value" noted in the commit message. The
   hardening commit contains only hardening.
3. **Expressed accuracy as a prerequisite, not as a rule.** The trap in Part B is that
   "don't let a bad fix authorise attendance" reads like "add accuracy to the rule", which
   the same brief forbids. The implementation keeps `canMarkAttendance` reading distance
   alone and gates *upstream*: an unusable fix never becomes `AttendanceStatus.Tracking`,
   so there is no code path where accuracy is a term in the comparison. Both thresholds are
   derived from `AttendanceRule.ELIGIBLE_RADIUS_METERS`; neither 25 nor 50 is written down
   a second time.
4. **Made the office capture strictly stricter than a live fix, and said why.**
   `maxUpdateAge = 0` with a 28 s window, and a refusal above 50 m of error or on unknown
   accuracy that persists nothing. The asymmetry is the argument: a rejected live fix costs
   a second, a bad anchor silently biases every distance the app will ever report.
5. **Chose `retryWhen` over a hand-rolled collect loop.** The obvious implementation of
   Part E — `while (true) { try { collect } catch { emit; delay } }` inside a `flow {}` —
   also catches exceptions thrown by the *downstream* collector and violates Kotlin's flow
   exception transparency, which surfaces as an `IllegalStateException` under load rather
   than in a test. `retryWhen` catches upstream only, keeps cancellation working, and lets
   `awaitClose` remove the platform callback before each re-subscription.
6. **Added one use case and argued for the absence of the others.**
   `SetOfficeLocationUseCase` orchestrates four steps across two collaborators;
   `GetOfficeLocationUseCase` and its siblings would each forward one call. The reasoning
   is in [ADR-017](DECISIONS.md#adr-017) so a future session does not "improve" the
   architecture by adding them, and `android-attendance/AGENTS.md` now names them as
   forbidden.
7. **Made the Haversine claim falsifiable.** The existing large-distance test had a 500 m
   tolerance, which substantiates nothing about a 50 m rule. The new tests compare the
   spherical result against an **independent WGS-84 ellipsoidal computation** (local
   meridional and normal radii of curvature) across 24 bearings at the radius. Worst-case
   divergence is under 0.25 m — about 1/100th of the tightest accuracy the app calls
   precise. Testing the formula against itself would have passed and proved nothing.
8. **Asserted the architecture rule instead of trusting it.** `DomainLayerPurityTest`
   reads the domain sources as text and fails on any `android.*`, `androidx.*`, or Play
   Services import — with a second test that fails if the scan found no files, because an
   architecture guard that silently scans nothing is worse than none.

**Where the AI exercised judgement beyond the literal instruction.**

- Part L asked for a test that the fresh-only request configuration is used "where testable
  at current seams". The apparent answer was "it isn't — `FusedLocationDataSource` needs
  Play Services". The AI checked rather than assumed, found that
  `LocationRequest.Builder` and `CurrentLocationRequest.Builder` are plain value objects
  that construct on the JVM, and extracted the two builders as `internal` functions so the
  settings are asserted rather than only reviewed. That test immediately earned its place:
  it failed on first run and revealed that Play Services **floors** the reported
  `maxUpdateDelayMillis` at the interval, so "never batches" had to be asserted as "no
  delay beyond one interval" rather than as the zero that was set.
- The `AttendanceScreenPreviews` "Degraded fix" preview showed a ±180 m accuracy beside a
  live distance — a combination the ViewModel can no longer construct. It was corrected to
  40 m and a separate "Improving accuracy" preview added, so no preview depicts an
  unreachable state.
- Test fakes were moved out of `presentation/attendance/` into their own `fakes/` package.
  The domain tests need them, and a test proving the domain is layer-independent while
  importing from `presentation.*` would undercut its own point.
- Two verification steps were **not** claimed. The >50 m office-capture refusal and the
  provider-fault backoff cannot be induced on an emulator — the fused provider will not
  report a poor error radius on demand and Play Services will not throw on demand. Both are
  covered by unit tests, and both are recorded as unit-tested-only in PROJECT_STATE.md and
  the matrix rather than folded into the emulator PASS list.

**Verified, not assumed.** `clean` → `testDebugUnitTest` (**158 tests**, 0 failures, up from
95) → `assembleDebug` → `lintDebug` (0 errors, no new warnings) → `git diff --check` clean →
`domain` grep clean → no dependency change. Eight-step emulator QA on `emulator-5554`: cold
start with no eligibility flash, first fix accepted, 200 m out-of-range stable (and reading
exactly 200 m, which is the geodesy claim visible on a device), return-to-range stable,
location services off/on recovered in place, **"Set Office Location" confirmed actionable
while the live stream had produced nothing at all**, and a mark held its receipt while the
user stood 200 m away with the gauge honestly reporting OUT OF RANGE.

---

## Entry 010 — F0 Flutter requirements, architecture and design direction

| Field | Value |
| --- | --- |
| **Date** | 2026-08-29 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | F0 — Flutter planning, architecture and visual approval gate |
| **Purpose** | Produce the complete engineering pack for Task 2 — requirements, architecture, data model, camera and sync engine design, UX specification, test strategy, risk register, ADRs, execution plan — plus static visual prototypes, and normalise the scaffolded Flutter project. Explicitly **no production UI**. |

**Prompt summary.** Act as primary senior Flutter implementation engineer. Verify the
repository (single repo, `main`, no nested `.git`, `android-attendance` frozen and
read-only). Re-read the assessment as the authoritative source. Perform fresh
primary-source research before selecting versions or APIs, and verify rather than
trust. Produce a twelve-document engineering pack with stable requirement IDs,
traceability, and risk-based verification design. Design a pragmatic layered
architecture and answer ten specific architecture questions (Bloc vs Cubit, isolate
bootstrapping, concurrency defence, process-death recovery, idempotency, retained
platform differences). Produce static, openable visual prototypes for seven screen
states. Run the non-device gates. Make exactly one milestone commit. **Do not
implement `CameraPreviewScreen` or the Pending Uploads UI**; stop at a visual approval
gate.

**Method.** Research was done against primary sources and then re-checked against the
**resolved packages in the local pub cache**, because two of the most important
findings could not be established from documentation alone. Package versions in the
pack are the versions in `pubspec.lock` after a real `flutter pub get`, not the
numbers advertised on package landing pages. The visual prototypes were rendered in a
browser and audited programmatically for overflow and touch-target size rather than
being declared finished on the strength of the markup.

**What the AI produced.** All twelve documents in `docs/flutter/`, the seven prototypes
and their generator, the `pubspec.yaml` dependency set, the project identity
normalisation, the strict `analysis_options.yaml`, the manifest changes, the
placeholder app shell and its two tests, and the reconciliation edits to the five root
documents.

**Load-bearing findings the AI produced, and which the author must be able to defend:**

1. **`camera_android_camerax` never populates `CameraDescription.lensType`.** Verified
   by grepping the resolved package — the identifier does not occur in it — while
   `camera_avfoundation` maps all four cases. Consequence: on Android, the only
   mandated platform, the app has no truthful basis for a `0.5x` or `2x` label, so
   zoom presets are derived from the device-reported zoom range instead
   (`ADR-F03`). This closes the long-standing `ER-05`.
2. **sqflite's synchronisation does not span isolates.** The WorkManager callback runs
   in a separate isolate with its own database connection, so no Dart-level lock can
   coordinate the two. Mutual exclusion was moved into SQLite as an atomic conditional
   `UPDATE` whose `WHERE` clause re-tests the precondition (`ADR-F04`). This is the
   single most consequential design decision in the task.
3. **`INTERNET` was missing from the release manifest.** Flutter's generated project
   declares it only for debug and profile. Left alone, the release APK — the actual
   deliverable — would have failed every upload on a permission error while debug
   worked perfectly (`ADR-F11`).
4. **The active zoom preset failed contrast.** The UX spec originally called for white
   text on a 22%-white fill; rendering it over a bright document showed it was close to
   invisible. Both the prototype and the spec were corrected. This is the prototype
   gate doing its job.

**Human verification.** ☐ **Pending at F0; resolved by later gates, not by this
checklist being independently walked.** (1) `lensType`'s absence was re-confirmed live
at F7 (`FQ-01`, physical HONOR DNP-NX9) — the strongest form of this check, a real
device rather than a package grep. (2) The sqflite exclusion claim was proven twice
over: `upload_queue_claim_test` races real independent connections, and F7 confirmed
no duplicate upload occurred with the real worker running. (3) Manifest permissions
were confirmed on the installed release APK via `dumpsys package` at F7 — CAMERA,
INTERNET, ACCESS_NETWORK_STATE present; RECORD_AUDIO, READ/WRITE_EXTERNAL_STORAGE,
POST_NOTIFICATIONS, MANAGE_EXTERNAL_STORAGE absent — stronger evidence than reading
the manifest source. (4) opening
`docs/flutter/design/03-camera-active-batch.html`.

**Not accepted from the AI.** Nothing in this gate was retained on the AI's assertion
alone where a check was available: every dependency version was confirmed by a real
resolution, the camera and connectivity claims were confirmed in the resolved source,
and the prototypes were confirmed by rendering and measuring them rather than by
reading the markup. Device behaviour was **not** claimed anywhere — the four open
questions that need hardware are recorded as open (`FQ-01` … `FQ-04`) rather than
answered optimistically.

---

## Entry 011 — F0 visual polish pass (pre-approval refinement)

| Field | Value |
| --- | --- |
| **Date** | 2026-08-29 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | F0 — visual polish before production UI is unlocked |
| **Purpose** | Apply six targeted refinements to the design direction after human review of the first prototype set. Explicitly **not** a redesign: preserve the visual language, palettes, camera-first hierarchy and 48 dp floor, and change only what was named. |

**Prompt summary.** Two decisions approved by the human: ADR-F12 stands (no fake
retry denominator), and the stray empty `flutter-camera-sync` directory may be
removed after verifying it is empty. Then six refinements: relabel the batch
action from "Upload batch" to "Finish batch" because finishing is a local durable
act and the old label made Offline + Upload read as contradictory; remove the
ambiguous top-left X from the camera; refine connection copy so it communicates
that captures are safe, sync is automatic and no user retry is required, without
overpromising OS-controlled scheduling; reduce Upload Manager density by roughly
5–10%; specify one signature production interaction (focus → capture → batch) in
documentation rather than animating the prototypes; and add no decoration.
Regenerate all seven prototypes, verify overflow / touch targets / CTA fit at
realistic counts, update only affected documents, and **do not commit**.

**What the AI produced.** Edits to the prototype generator and all eight generated
pages; new `UX_SPEC.md` §3.1 (navigation semantics), §3.2 (batch action
language), §4.1 (status copy rules) and §7.1 (the signature motion sequence);
`ADR-F13` and `ADR-F14`; the ADR-F12 approval note; traceability and test-strategy
updates; removal of the empty directory.

**Judgements the AI made that are worth checking:**

1. **"Finish batch" was extended into a copy rule, not just a label change.** The
   same reasoning — say what is true of the data before anything about the
   network — was applied to the status chips, giving "Offline · captures are safe"
   and "Connected · uploading automatically" (the latter because *retrying*
   asserts a failure that has not happened). A table of forbidden phrasings was
   added so the rule survives future copy edits.
2. **Removing the X was turned into an explicit invariant.** The interesting part
   is not the deleted control but the guarantee it forced into writing: no
   gesture, control or navigation path may discard an open batch as a side
   effect. That is now a table in `UX_SPEC.md` §3.1 with a row per event.
3. **The motion spec deliberately refuses precision it cannot have.** Durations
   are given as a starting point derived from the existing tokens, with the
   ordering marked non-negotiable and the numbers marked as requiring device
   tuning. It also states the two cases where the animation must *not* play — on
   capture failure, and ahead of the database write — because a motion that
   asserts durability must not run when durability was not achieved.

**Verification performed.** All seven prototypes were re-rendered and audited in a
browser: zero elements escaping the 390×844 frame, zero interactive targets under
48 dp, zero horizontally clipped text, and no close control present on any screen.
The "Finish batch (n)" label was measured at counts 1, 4, 12, 99 and 128 —
156–171 px against a 358 px budget. After the density increase, the reassurance
line (679–717 px) and CTA (734–786 px) were confirmed still inside the frame on
every Upload Manager screen, and both batch headers still visible on screen 04.

One apparent defect — the camera-flip control rendering as an iconless dark square
— was investigated against the DOM and computed styles, found correct (48×48,
radius 999 px, icon present, `currentColor` inherited), and confirmed as a
preview-pane snapshot artefact on re-render. It was not "fixed", because there was
nothing wrong.

**Human verification.** ☐ **Pending re-review at F0; not separately re-litigated
later.** The design direction these questions were raised against is the one that
shipped unchanged through F5 and was visually confirmed at F7 on physical hardware —
no later gate reopened the close-control removal, the "Finish batch" wording
(`ADR-F14`), or the Upload Manager layout. Treated as settled by continuation rather
than by a second explicit sign-off. The four things to look at:
the camera top bar now that the X is gone (does its absence read as confident or
as missing?), whether "Finish batch" reads as completing capture rather than
starting a transfer, whether the Upload Manager is easier to scan without feeling
sparse, and whether the signature motion sequence in `UX_SPEC.md` §7.1 describes
something that would feel purposeful rather than decorative on a real device.

**Not accepted from the AI.** The prototypes were not animated to demonstrate the
motion spec — the instruction was to document it, and an animated HTML mock would
have implied timing precision that has not been earned before device tuning. No
new documents were created for this pass; only affected ones were edited.

---

## Entry 012 — F1/F2 Flutter durable capture and sync foundation

| Field | Value |
| --- | --- |
| **Date** | 2026-08-29 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | F1 + F2 — Flutter data layer, durable queue and resilient sync engine |
| **Purpose** | Implement the highest-risk, non-visual half of Task 2: durable capture metadata, a persistent multi-batch queue, transactional state changes, concurrency-safe claiming across isolates, stale-claim recovery, a deterministic mock upload API, the queue processor, and WorkManager scheduling and bootstrap — with risk-based automated verification. Explicitly **no production UI**. |

**Prompt summary.** Act as primary senior Flutter implementation engineer for the
data + domain + sync + background half of Task 2. Verify the repository first
(single repo, `main`, expected HEAD, clean tree, no nested `.git`,
`android-attendance` frozen) and stop rather than repair if anything differs. Read
the twelve-document engineering pack as a binding contract; where implementation
evidence contradicts it, resolve the contradiction deliberately and update the ADR
rather than quietly diverging or rewriting docs to match whatever was typed.

Build in a stated order — domain model, schema, repository, finish-batch
transaction, **atomic claim, then the real SQLite contention test early**, stale
lease, filesystem store, file/DB compensation, mock uploader, failure taxonomy,
processor, scheduler abstraction, worker entry point, connectivity trigger, batch
completion, architecture tests, documentation, verification, one commit.

Specific constraints carried by the prompt, each of which shaped code:

- Concurrency correctness must not depend on Dart bools, mutexes, singletons,
  Bloc, widget state or "only scheduling once" — none of those span isolates.
- The contention test must use `sqflite_common_ffi` with **separate connections**;
  a fake repository or a test around an in-memory mutex is explicitly not evidence.
- No `RETRYABLE_FAILURE` resting state; retry is derived from
  `status == PENDING && attemptCount > 0`.
- No invented attempt ceiling, and no fake "attempt 3/5".
- Connectivity is advisory; `if (connected) upload()` is forbidden as a
  correctness rule.
- Success must be persisted **before** any local-file cleanup, and a failed
  cleanup must never re-queue an upload.
- Do not implement `CameraPreviewScreen`, the Upload Manager, or any approved
  visual element. Stop after one commit and await review.

**What the AI produced.** 20 Dart source files under `lib/domain`, `lib/data` and
`lib/sync_worker_entrypoint.dart`; 16 test files totalling **188 tests**; four new
ADRs; and the reconciliation edits to eleven living documents.

**Load-bearing findings and decisions the author must be able to defend:**

1. **A real defect, found by a test rather than by review (`ADR-F18`).** The first
   `QueueProcessor` re-claimed the image it had just failed. A retryable failure
   returns a row to `PENDING`, which makes it immediately claimable again, so a
   single offline image produced **25 upload attempts in a fraction of a second** —
   an app-side retry loop by accident, competing with the WorkManager backoff the
   design had explicitly delegated to. The risk register had named this risk
   (`RS-04`) but had imagined it only as a `Timer`. The fix excludes ids already
   tried in the current pass from the claim query. *This is the single most
   valuable thing the test suite did in this gate, and it is worth being able to
   describe.*

2. **The designed claim SQL could not be implemented as written (`ADR-F17`).** The
   design used one statement with an inline subquery; that form cannot tell the
   caller **which** row it claimed. `UPDATE … RETURNING` would, but it needs SQLite
   3.35, and `sqflite` uses the platform's own SQLite on Android. Resolved as a
   candidate read followed by a conditional `UPDATE … WHERE id = ? AND
   (precondition)`. The atomicity is unchanged because it was never in the
   subquery — it is in the `WHERE` clause of the write. `DATA_MODEL.md` §4 was
   corrected to show the statement that actually runs.

3. **A contention test is worthless unless the connections are genuinely
   separate.** sqflite returns the *same* connection for the same path within one
   isolate (`singleInstance: true`), so the obvious version of this test would have
   been two calls on one connection, proving nothing. `AppDatabase.open` gained a
   `singleInstance` flag the app never changes, used only by the suite. The test
   then races two — and eight — real connections and asserts one winner, including
   on a stale lease. **What it does not prove** (OS-level parallelism; the ffi
   backend serialises through one isolate) is written down in `TEST_STRATEGY.md`
   §11 rather than glossed.

4. **A bonus row collided with approved design (`ADR-F16`).** Post-upload file
   deletion (`FLT-SYNC-016`) conflicts with the approved Upload Manager, which
   renders a thumbnail on every row including synced ones. The mechanism and its
   ordering are implemented and tested; the flag defaults to **off**, and the
   conflict is recorded as an F6 decision instead of being resolved by silently
   degrading a frozen screen.

**Human verification.** ☐ **Pending at F1; corroborated, not re-walked, by F7.**
The claim path this checklist audits ran for real at F7 — two consumers (the
foreground drain and the WorkManager worker) against one live database on a physical
device, with no duplicate upload. That is stronger field evidence than the
tampering steps below would produce, though the steps themselves were not
separately re-executed by a human this pass. Four checks, in descending order of value:

1. Read `UploadQueueDao.claimNext` and `upload_queue_claim_test.dart` together, and
   satisfy yourself that no Dart-level construct is doing the excluding. Delete the
   `AND (status = ? OR (status = ? AND claimed_at < ?))` clause from the `UPDATE`
   and confirm the contention tests fail.
2. Delete the `skip: deferred` argument in `QueueProcessor.drain` and confirm "a
   failed pass claims each item once, then stops" fails with 25 attempts. That is
   finding 1 reproduced in ten seconds.
3. Confirm `QueueProcessor` has no `ConnectivityPort` in its constructor — that is
   the structural reason `if (wifi) upload()` cannot be written here.
4. Run `flutter test` and confirm 188/188, then `flutter analyze` for 0 issues.

**Not accepted from the AI.** No device behaviour is claimed anywhere: the worker
tests assert the *decision* the worker makes, and both the code comments and the
matrices say plainly that whether Android runs it is a device check. Requirement
rows whose stated verification method includes `DEVICE` were held at `PARTIAL`
however complete the code is — nine rows, six of them waiting on hardware alone.
The `workmanager` and `connectivity_plus` API surfaces were re-checked against the
resolved packages in the local pub cache rather than recalled, and the host SQLite
version (3.53.4) was confirmed by running a probe before any `DATA` test was
written. The approved UI was neither implemented nor redesigned.

---

## Entry 012b — F1 post-audit hardening (same commit, amended)

| Field | Value |
| --- | --- |
| **Date** | 2026-08-29 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | F1/F2 — corrections required by the architecture audit |
| **Purpose** | Apply six findings from the Principal Mobile Architect / QA Gatekeeper audit of F1. The architecture was **accepted**; these are corrections within it, not a redesign. Amended into the existing F1 commit rather than added as a second milestone. |

**Prompt summary.** The audit accepted the F1 architecture and instructed: do not
redesign F1, do not implement camera or UI, do not push, do not create a second
functional commit — fix and amend. Six findings, each with its own constraint:

1. **Healthy continuation vs retry failure.** The 25-item bound made a bounded
   slice return the same thing as a failed one, so a large healthy queue attracted
   escalating backoff. Required: explicit outcome semantics distinguishing at least
   `DRAINED/IDLE`, `RETRYABLE_FAILURE` and `CONTINUATION_REQUIRED`; keep the worker
   bounded; consider a time budget as well as an item budget; use a
   WorkManager-supported continuation mechanism; **no custom timer or polling
   loop**; no duplicate simultaneous drains; the atomic claim stays the correctness
   boundary; and seven named properties had to be proven by test.
2. Correct the backoff documentation — Android's minimum is 10 s, not 15 s.
3. Make scheduler failure observable without making it unsafe, and without
   building a logging framework.
4. Decide explicitly whether "one `DRAFT` batch" is a database invariant or an
   application policy, preferring the latter unless multiple independent creators
   exist.
5. Add a migration scaffold so a future version bump cannot silently record a new
   version without running a migration. Do not invent a fake v1→v2 migration.
6. Document Android vs iOS retry semantics honestly; claim nothing about iOS.

Plus: verify stage numbering across the documents rather than assuming the report
was wrong, and do not damage any of the twenty-one F1 decisions listed as accepted.

**Method.** Every platform claim in this pass was read from an artifact rather
than recalled, because the finding that triggered it (#2) was itself an
inherited documentation error:

* `MIN_BACKOFF_MILLIS`, `MAX_BACKOFF_MILLIS` and `DEFAULT_BACKOFF_DELAY_MILLIS`
  were read with `javap` from the compiled `androidx.work.WorkRequest` inside
  `work-runtime-2.11.2.aar`, after confirming with `gradlew app:dependencies`
  that 2.11.2 is what this app actually resolves.
* The continuation mechanism was chosen only after reading
  `workmanager_android`'s `WorkManagerUtils.kt`.

**Load-bearing findings the author must be able to defend:**

1. **`ExistingWorkPolicy.keep` would have been silently wrong for a
   continuation.** A worker asking for its own successor *is* itself uncompleted
   work under that unique name, so `KEEP` discards the request — the backlog
   would sit until something unrelated woke it, and nothing would look broken.
   This is the kind of defect that survives review and never fires in a test.
2. **The plugin's Dart documentation does not match its native behaviour.** Dart's
   `append` maps to Android's `APPEND_OR_REPLACE`, not `APPEND`; and the doc for
   `update` describes periodic-work semantics that one-off work does not have.
   `APPEND_OR_REPLACE` happens to be the variant we want — it starts a fresh chain
   rather than inheriting a cancelled or failed one — but that was verified, not
   assumed (`FR-06a`).
3. **"Progress" is the right criterion for continuing, and it is what bounds the
   chain.** A continuation requires at least one item to have left the work set.
   The obvious alternative — "outstanding > 0" — would allow an endless chain of
   zero-work continuations whenever another processor held every claimable item.
   That case now returns retry, which is honest: there was nothing this pass could
   do (`ADR-F19`).
4. **A time budget was added because an item count is a poor proxy for the limit
   Android actually enforces.** Twenty-five slow uploads can exceed the ~10-minute
   worker window, and a worker killed mid-item reports *nothing* — the pass is cut
   off rather than finishing and asking for a continuation, which is the exact
   failure the fix exists to prevent.
5. **The one-`DRAFT` rule was being described as something it was not.** It is a
   read-then-insert with no unique index, safe only because the foreground is the
   sole creator of batches. Declared an application policy, with a test that
   asserts the *limit* of the guarantee so nobody later reads it as cross-isolate
   protection (`ADR-F20`).

**Human verification.** ☐ **Pending at F1; corroborated, not re-walked, by F7.**
The continuation-vs-retry distinction this checklist audits is exactly what let a
healthy 5-image offline batch drain in one pass at F7 rather than being throttled by
backoff — real-world behaviour consistent with the tested design. The tampering step
itself was not separately re-run by a human this pass. Three checks, in descending order of value:

1. In `sync_worker_entrypoint.dart`, change the `continuationRequired` branch to
   `return false`. Four tests in "healthy backlog continues instead of failing"
   should fail. That is finding #1 reproduced in under a minute.
2. In `WorkManagerSyncScheduler.scheduleContinuation`, change
   `ExistingWorkPolicy.append` to `.keep`. The continuation test fails — and note
   that on a device this change would produce no error at all, just a queue that
   stops draining.
3. Confirm the backoff figure independently: `javap -constants -p` on
   `androidx/work/WorkRequest.class` from `work-runtime-2.11.2.aar`.

**Not accepted from the AI.** No iOS behaviour was implemented or claimed; the
platform difference is recorded as a limitation (`RS-10`) rather than papered
over. Startup/resume reconciliation was **not** invented to close finding #3 — the
scheduling outcome is now observable, and the fact that nothing yet acts on it is
recorded as residual risk (`RS-11`) belonging to `FLT-SYNC-012` at gate F5. The
stage numbering was checked against `EXECUTION_PLAN.md` rather than assumed: the
Camera Engine milestone is **F3**, and the report that said so was right.

---

## Entry 012c — F1 final scheduling-race closure (same commit, amended again)

| Field | Value |
| --- | --- |
| **Date** | 2026-08-30 |
| **Tool** | Claude Code (CLI) |
| **Model** | Claude Opus 5 |
| **Gate** | F1/F2 — final acceptance correction |
| **Purpose** | Close a scheduling-liveness race identified by the second architecture audit: `ExistingWorkPolicy.keep` discards a drain request made while a worker is still running, so a batch finished at the wrong moment stays durably `PENDING` with nothing scheduled to collect it. |

**Prompt summary.** The audit supplied the race as a numbered sequence and the
required invariant — *commit pending work → request drain → either the current
chain is guaranteed to revisit it, or a successor is durably enqueued; no
check-then-finish window may leave newly `PENDING` work with neither*. It
suggested using the unique chain consistently but stated the outcome mattered
more than the mechanism, and required the policy mapping to be verified **from
the resolved native source rather than from pub.dev prose or memory**.

It also required an audit of every scheduling call site — specifically whether a
capture schedules work, given that a `DRAFT` image is not uploadable — ten named
properties proven by test with the exact `ExistingWorkPolicy` asserted, and a
truthful audit of whether chained continuations can hammer the transport, with
explicit permission to record a bounded risk rather than engineer it away. Twenty
accepted F1 decisions were listed as not to be disturbed.

**Method.** The native mapping was read verbatim from
`workmanager_android-0.10.8/.../WorkManagerUtils.kt` in the local pub cache,
along with the `enqueueUniqueWork` call that applies it. `APPEND → APPEND_OR_REPLACE`,
`KEEP → KEEP`.

**Load-bearing findings the author must be able to defend:**

1. **The race is real and was confirmed, not assumed.** `KEEP` discards while
   *uncompleted* work exists, and a RUNNING worker is uncompleted. Nothing is
   lost, every component reports success, and the queue stops draining until an
   unrelated trigger appears. It is invisible by construction, which is why it
   survived two passes of review.

2. **The fix is one word, and its cost is the opposite failure.** `append`
   everywhere means a request can never vanish — but redundant requests now
   accumulate as extra chain nodes instead of collapsing. That is the cheaper
   mistake: a redundant node finds an empty queue and returns `idle` in
   milliseconds; a discarded request loses the feature. Stated as a tradeoff in
   `ADR-F21` rather than presented as free.

3. **The audit's call-site question exposed a genuine gap, though not the one it
   expected.** `RecordCapture` never scheduled anything — so there was nothing to
   remove. But **nothing scheduled on finish-batch either**: the DAO's
   `enqueueBatch` had no caller that requested a drain, so the app's main
   scheduling trigger did not exist yet. Added as a `FinishBatch` use case,
   ordered transaction-then-schedule, which is also what makes the audit's
   properties F, G and J testable at all.

4. **Proving "the atomic claim is still the final protection" exposed a second
   defect.** Two processors draining one file concurrently produced `SQLITE_BUSY`
   escaping out of `QueueProcessor.drain` — which documents that it does not throw
   for an ordinary failure, and contention between the app's own two isolates is
   ordinary by design. It now ends the pass with `DrainStop.databaseBusy`. This
   matters most for the *foreground* drain in F5, where no WorkManager exists to
   catch anything.

5. **The retry-hammering audit was answered honestly rather than optimistically.**
   A flaky item *is* re-attempted once per chained slice, because the `skip` set
   spans one pass. It is bounded — each attempt is separated by real upload work,
   and backoff takes over the moment healthy work runs out — so it is recorded as
   `RS-12` with the bound asserted by test, not suppressed with a second scheduler.

**Human verification.** ☐ **Pending at F1; corroborated, not re-walked, by F7.**
This is the exact defect class F7's critical path would have silently exhibited had
it still been present: a drain requested while a worker is running getting discarded.
It did not happen — the offline-built queue drained cleanly once connectivity
returned. The tampering step itself was not separately re-run by a human this pass.
Three checks:

1. Change `WorkManagerSyncScheduler.conflictPolicy` back to
   `ExistingWorkPolicy.keep`. Three tests fail immediately — and note that on a
   device this change produces no error at all, only a queue that occasionally
   stops draining.
2. Read `WorkManagerUtils.toAndroidWorkPolicy` in the pub cache and confirm
   `APPEND → APPEND_OR_REPLACE` for yourself; the Dart doc comment says otherwise.
3. `grep -rn "scheduleDrain" lib` — two call sites, `FinishBatch` and
   `ConnectivityDrainTrigger`, and neither is on the capture path.

**Not accepted from the AI.** Native WorkManager chain ordering is **not** claimed
to be verified — the tests assert the policy handed to the plugin, and whether
Android honours it remains a device check. The retry-hammering behaviour was not
engineered away to look tidier. The twenty frozen F1 decisions were left alone;
the one deviation from the "do not change" list — adding `DrainStop.databaseBusy`
— is additive, is reported rather than buried, and was forced by a defect the
audit's own required test uncovered.

---

## Entry 013 — F3 Flutter camera engine

**Date:** 2026-08-30 · **Gate:** F3 · **Scope:** camera mechanics only; no
production camera UI.

### What the AI was asked for

The camera engine beneath Task 2's mandated camera behaviour: enumeration, a
capability model, controller lifecycle, safe switching, zoom, tap-to-focus,
capture concurrency, the handoff into the F1 durable pipeline, error
classification, `CameraCubit`, and fake-adapter tests. The brief was explicit that
the approved `CameraPreviewScreen` design was **not** to be built in this pass.

### Representative prompt (abridged)

> Implement the CAMERA ENGINE. Camera mechanics first. Do NOT implement the final
> approved `CameraPreviewScreen` visual design yet. Verify the actual resolved
> plugin source before relying on APIs — do not assume list order means 0.5x / 1x
> / 2x, do not infer focal length from a camera ID, do not fabricate optical
> multipliers. Protect against: switch A → B, A's initialize completes late, A
> overwrites state for B. Own an application-level capture guard as well, because
> asynchronous UI calls can race.

### The two decisions worth recording

**1. A second platform gap, found the same way as the first.**

`ADR-F03` already rested on reading `camera_android_camerax` in the pub cache
rather than trusting documentation. Mapping permission codes for `FLT-ERR-001`
began the same way, and turned up something the approved design had not
anticipated: `CameraPermissionsManager.java` declares exactly two error constants,
and `CameraAccessDeniedWithoutPrompt` is not one of them. It exists only in
`camera_avfoundation`.

That made `CAMERA_ENGINE.md` §7's second permission state **unreachable on the one
platform that must ship** — a specified behaviour that could not be implemented
truthfully. The resolution (`ADR-F22`) splits the platform's verdict from the
app's suspicion: `isPermanentPerPlatform` is set only when the platform actually
said so, and a separate count of consecutive refusals lets the later UI escalate
what it *offers* without asserting what it was never told. `permission_handler`
was reconsidered on the strength of the new evidence and rejected again.

**Why this is the entry's centrepiece:** it is the same discipline as `ADR-F03`,
applied unprompted to a different question, and it produced a *correction to an
approved document* rather than an implementation that quietly diverged from it.

**2. Two approved documents disagreed, and neither was wrong.**

`CAMERA_ENGINE.md` §5 specified letterboxed preview coordinates; `UX_SPEC.md` §4
specifies a full-bleed viewfinder. Those are different renderings, and a mapper
written for one is subtly wrong under the other — wrong in a way that is invisible
in a screenshot, because the reticle still lands under the finger while the camera
focuses somewhere else. `FocusPointMapper` takes the fit as an input and implements
both (`ADR-F23`), so the F5 sprint is not forced to change an approved layout.

### What the AI got right, and what had to be corrected

Two test-authoring mistakes were caught by running the tests, not by review:

* The first switch-race test asserted that a superseded camera opens and must then
  be disposed. It never opened at all — the generation check fires *before*
  `openSession`. The correct response was not to weaken the assertion but to test
  **both** orderings: superseded before the open begins (never acquired) and
  superseded after (disposed on arrival). The second is the dangerous one and now
  has to be constructed deliberately, by waiting until the open is genuinely in
  flight.
* A cover-crop test asserted a wide image in a square box crops top and bottom. It
  crops left and right. The arithmetic was right and the test's premise was wrong.

Both are recorded because they are the useful kind of failure: the implementation
was correct and the test was not, which is only distinguishable by working out
what *should* happen rather than adjusting the expectation to match the output.

### Human verification

☐ **Pending at F3; the device check this list explicitly deferred was executed at
F7.** `FQ-01` confirmed live: the physical HONOR DNP-NX9 reports one back camera with
no `lensType`, exactly as the package-source grep below predicted — the
honest-ordinal fallback (`ADR-F03`) is what a real user actually sees, not a
hypothetical. Four checks that need no device:

1. `grep -rn "lensType" $LOCALAPPDATA/Pub/Cache/hosted/pub.dev/camera_android_camerax-0.7.4+7`
   — zero hits. That single fact is the whole basis of `ADR-F03`.
2. Read `CameraPermissionsManager.java` in the same package and count the error
   constants. There are two, and `ADR-F22` follows from it.
3. Delete the `if (!_isCurrent(generation))` check after `openSession` in
   `CameraCubit._acquire`. Three switch-race tests fail — and note that on a device
   this change produces no error message at all, only a preview showing the wrong
   camera.
4. `grep -rn "package:camera/" lib` — every hit is under `lib/data/camera/`.

### Not accepted from the AI

No device behaviour is claimed. 445 host tests say nothing about whether a real
lens focused, and every camera row whose evidence is a device run stays `PARTIAL`.
The eight rows that moved to `DONE` are rules the engine settles by itself; **no
`FLT-UX` row moved, and neither did `FLT-CAM-001`, `-002`, `-004`, `-009` or
`-010`** — an engine API is not a screen, and marking those done because the state
exists to render would be the exact failure this project's status vocabulary is
designed to prevent.

The "Open settings" platform channel was scoped, costed and **not built**: it has
no caller until F5, and shipping an untested recovery path is worse than shipping
none. The camera backend was not swapped to Camera2 to obtain richer metadata; an
honest label costs nothing and a platform change made on speculation risks
everything.

---

## F4/F5 — the production Flutter experience (2026-08-30)

**Prompt intent.** Build the assessment-facing Flutter application: the camera
screen, the Upload Manager, the batch and sync presentation state, startup and
resume reconciliation, the approved failure states, accessibility and restrained
motion — implementing the frozen visual direction faithfully rather than
redesigning it, and with tests that are high-value rather than count-padding.

### What the AI contributed, and what it got wrong

**1. It found a real constraint by measurement, not by reasoning — `ADR-F24`.**
The plan was for widget tests to drive the real DAO, exactly as the F1 `DATA`
tier does, so that "the count came from the database" would be a claim about the
database. The first run did not fail; it **hung**, sitting at `pumpAndSettle` for
its full ten-minute timeout with no output. The cause is that `testWidgets` runs
its body inside a fake-async zone with a controlled clock, and the FFI SQLite
engine's real file I/O is never completed by anything that clock advances.

The instructive part is the diagnosis. The first hypothesis — an indeterminate
`CircularProgressIndicator` preventing `pumpAndSettle` from settling — was
plausible and wrong. It was discarded by a throwaway test that printed the cubit's
state after each frame and produced **no output at all**, which located the hang
*before* the first pump rather than during it. The fix that followed (split the
tiers, state in each file header which of the two it may claim) is a design
decision the constraint forced, and it is recorded as such rather than presented
as foresight.

**2. It made a scoping decision that needed a stated reason — `ADR-F25`.**
`SYNC_ENGINE.md` §8 said the foreground *may* drain the queue directly. It now
does, one bounded pass per reconciliation trigger. The argument is not "more is
better": Android can defer a worker substantially under Doze, and a correct queue
nobody can observe working is a poor demonstration of the one requirement the
assessment cares most about. The same ADR resolves an overlap the UI created —
`ConnectivityDrainTrigger` (F1) and `SyncBloc` both see the link signal — by
giving the platform request to the tested F1 component and the foreground pass to
the bloc, with an integration test asserting that regaining a link increments the
scheduling count by exactly **one**.

**3. It wrote a circular test and had to be caught.** A first draft of the
rewritten `app_shell_test.dart` asserted that a probe widget it had just mounted
was present — a test that could not fail and proved nothing. It was replaced with
two assertions that can fail: the themes derive from one seed in both
brightnesses, and the storage-failure shell renders its message. The "camera is
the primary route" claim moved to the navigation test, where it is asserted
against a real navigator that genuinely cannot pop.

**4. Where it was held to the honesty rules already in the register.** Three
places where the obvious implementation would have overstated what the app knows,
and each is now asserted by a test rather than left to review:

* the camera selector labels by **ordinal** ("Camera 1, 1 of 2"), never by a
  fabricated multiplier, because Android reports no lens identity (`ADR-F03`);
* the retry row shows "attempt 3" with **no denominator**, because no cap exists
  (`ADR-F12`) — the reference screenshot's "3/5" is deliberately not reproduced;
* the permission panel widens its **offer** after repeated refusals without ever
  using the word "permanently", because Android never issues that verdict
  (`ADR-F22`).

**5. Deliberate departures from the advisory p3 screenshots.** "PAUSE ALL" and
the flash/settings camera controls were not built. Pausing an automatic queue
invites a state where uploads stop and nobody remembers why, against a mandate
that is explicitly recovery *without user intervention*; flash and settings carry
no mandated behaviour. Both are recorded in the matrix rows rather than quietly
omitted.

### Verification actually executed

`dart format lib test`, `flutter analyze` (0 issues), `flutter test`
(**516 pass**, +71 this gate), `flutter build apk --debug` (PASS),
`git diff --check` clean, `git diff -- android-attendance` empty.

**No device QA was performed and none is claimed.** 516 host tests say nothing
about whether a real lens focused or whether Android ran a worker.

---

## F7 — Android runtime bring-up and device QA (2026-08-30)

**Prompt intent.** Take over an in-progress runtime fix, finish the remaining
real-device QA on a physical HONOR DNP-NX9, run the critical offline-sync
acceptance path, and land a single hardening commit — without redoing the
root-cause diagnosis a prior session had already completed.

### What the AI verified from the prior session's diff

The uncommitted changes matched the handoff brief exactly: `AppDatabase.configure`
moved `PRAGMA busy_timeout` from `db.execute` to `db.rawQuery` (Android classifies
the assignment-form PRAGMA as a query and aborts `execSQL` on it before
`onCreate`/`onUpgrade` ever runs); `StartupBootstrapApp` replaced the old
try/catch-to-null pattern with a real retry boundary; `RECORD_AUDIO`,
`READ/WRITE_EXTERNAL_STORAGE`, and `POST_NOTIFICATIONS` were removed from the
merged manifest via `tools:node="remove"`; and two new regression tests pinned
both the query-API choice and the retry behaviour. Nothing in `android-attendance`
had moved.

### What device QA found that the host suite could not

**1. A device-OEM background restriction, not a code defect.** The critical
offline-sync path (capture offline → finish batch → background → restore network
→ automatic drain) stalled indefinitely on first attempt: a WorkManager job sat
`READY` on every standard Android constraint (connectivity, doze, quota,
background-restricted) while one Honor-proprietary constraint —
`HN_USER_EXPERIENCE` — stayed permanently unsatisfied across four escalating
backoff attempts. This is MagicOS's own job-launch gate, orthogonal to
`AndroidManifest.xml` and to anything `WorkManager` exposes. Confirmed by
manually switching the app from "Manage automatically" to "Manage manually" (all
three sub-toggles on) in Settings → Apps → App launch: the same live job's
unsatisfied-constraint bitmask dropped `HN_USER_EXPERIENCE` immediately, and the
already-queued offline batch drained to `COMPLETED` with no code change and no
retry press. **No source fix exists for this** — it is a per-device, per-install
OS setting, and the correct engineering call was to document it rather than build
around an OEM battery manager. One operational wrinkle worth recording: `adb shell
am force-stop` silently reverts that manual grant back to "automatic," so the
toggle has to be reapplied after every force-stop before the constraint clears
again.

**2. A false-positive defect the AI caused and then correctly retracted.** After
disabling networking to test the offline path, several capture attempts appeared
to fail permanently — no new row in `queued_images`, no thumbnail increment, no
change even after restoring connectivity — which briefly looked like a real
regression in the offline capture pipeline. The actual cause was `mWakefulness:
Dozing`: the device's screen timeout was short enough that it locked between
adjacent `adb shell input tap` calls during multi-second diagnostic pauses, so
the taps were landing on nothing. This is exactly the failure mode
`CAMERA_ENGINE.md`/session-handoff guidance warns about — inferring a result from
a later screenshot without confirming the app was still foreground and awake.
Once `screen_off_timeout` was extended and wakefulness was checked before every
injected action, the identical capture sequence succeeded cleanly both online and
offline, with no code change. The lesson is now load-bearing for any future
`adb`-driven session on this device: verify `dumpsys power | grep mWakefulness`
immediately before *and after* any tap that a multi-second command chain
precedes.

### Verification actually executed

**Flutter:**
- **HONOR DNP-NX9 / Android 16**: extensive live camera, capture, focus, zoom, offline queue, automatic background recovery, permission and lifecycle QA. Zoom slider and all three presets round-tripped
1x↔8x with the readout always matching the requested state. Tap-to-focus at
center, corners, and at 8x zoom all landed the reticle correctly. Capture,
double-shutter guard (two rapid taps produced exactly one new row), and
Camera→Pending Uploads→Camera batch-draft preservation all confirmed against the
live SQLite file (pulled via `run-as` and inspected directly, not inferred from
the UI). The offline-sync path passed end-to-end once the OEM constraint above
was cleared: 5 photos captured offline, `Finish batch` offline showed
"Waiting for connection" per item with no fabricated progress, and all 5 drained
to `UPLOADED` automatically while the app was backgrounded. CAMERA-revoke showed
the honest "Camera access is off" copy (no false "permanently denied" claim) with
Pending Uploads still reachable, and recovered without a restart once the
permission was re-granted. Force-stop/relaunch and foreground/background cycling
both preserved correct durable state. Installed-APK permissions confirmed via
`dumpsys package`: `CAMERA`, `INTERNET`, `ACCESS_NETWORK_STATE` present;
`RECORD_AUDIO`, `READ/WRITE_EXTERNAL_STORAGE`, `POST_NOTIFICATIONS`,
`MANAGE_EXTERNAL_STORAGE` absent. 

- **Samsung Galaxy S25**: physical pinch interaction verification. Physical two-finger pinch was **not** automated — `adb shell input` cannot produce trustworthy multi-touch — and is recorded as a manual-user check on Samsung, not a fabricated pass.

**Native Android:**
- **Emulator + automated verification**: 158 automated tests and manual emulator acceptance.

Host gate from `clean`: `dart format` (0 changed), `flutter analyze` (0 issues),
`flutter test` (**521 pass**, +5 this gate: the two `app_database_test.dart`
busy-timeout regressions, the `app_shell_test.dart` retry-boundary case, and the
two new `test/architecture/android_manifest_test.dart` permission-removal
guards),
`flutter build apk --debug` (PASS), `git diff --check` clean,
`git diff -- android-attendance` empty.
