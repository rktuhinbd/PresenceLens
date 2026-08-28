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
session — not asserted from memory. **Still pending from the human:** confirming the
`key.properties` and `.jks` backups were made, and the final side-by-side install check
on the device intended for actual submission upload.

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
