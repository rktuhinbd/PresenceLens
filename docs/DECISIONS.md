# Architecture Decision Records

Lightweight ADRs for PresenceLens. Each records the reasoning behind a choice so a
future session does not re-litigate it.

**Status vocabulary**

| Status | Meaning |
| --- | --- |
| `PROPOSED` | Reasoned, but depends on external verification or human approval. Do not treat as settled. |
| `ACCEPTED` | Verified and in force. Implementation must follow it. |
| `SUPERSEDED` | Replaced; the replacement is named. |

An ADR is `PROPOSED` whenever it rests on a technical claim this session could not
verify from an authoritative source, or on a judgement the human must make. Marking
something `ACCEPTED` without that verification would be fabricating certainty.

**Flutter-scoped ADRs live in a separate file.** Decisions that apply only to Task 2
are numbered `ADR-F01` … `ADR-F12` in
[docs/flutter/DECISIONS.md](flutter/DECISIONS.md), recorded at gate F0 on 2026-08-29.
The records below remain in force repository-wide; where a Flutter ADR confirms one,
it says so ([ADR-005](#adr-005) → `ADR-F02`, [ADR-008](#adr-008) → `ADR-F06`,
[ADR-009](#adr-009) → `ADR-F01`, [ADR-017](#adr-017) → `ADR-F01`).

**G0.1 human review completed 2026-08-28.** ADR-001, ADR-003, and ADR-011 were
accepted; ADR-012 was added as an accepted design principle. **ADR-010 was resolved
2026-08-28**, ahead of G8, by explicit human authorisation to prepare the final signed
release — see its record below. ADR-009 stays `PROPOSED` on technical grounds and needs
no approval.

---

<a id="adr-001"></a>

## ADR-001 — Foreground Fused Location updates rather than GeofencingClient

**Status:** ACCEPTED — approved at G0.1 human review, 2026-08-28. The geofence
minimum-radius claim is now verified (RESEARCH.md `RF-18`).

**Requirements:** AND-02, AND-08, AND-09, AMB-13, AMB-14

### Context

The assessment calls Task 1 a "Geo-Fenced Attendance System", which invites the use
of `GeofencingClient`. But the actual mandated behaviour is narrower and stricter
than what geofencing provides: a **50-metre** radius test (AND-08) and a
**real-time** distance readout (AND-09), both while `AttendanceScreen` is on screen.

### Decision

Use `FusedLocationProviderClient` with high-accuracy priority, streaming location
updates while the screen is in the resumed state, and compute the distance to the
saved office coordinates directly. Do not use `GeofencingClient`.

### Reasoning

- **Geofencing cannot produce AND-09 at all.** Geofence callbacks fire on transition
  events. They do not supply a continuous distance, so the "You are 120m away"
  indicator would have no data source.
- **50 m is below the radius geofencing is designed for.** Official Android
  Developers documentation recommends a minimum geofence radius of roughly
  100–150 m for best results — two to three times the distance this feature must
  resolve. Geofence transition delivery is also intentionally latency-tolerant to
  preserve battery. Both properties work against an exact, immediate, on-screen
  50 m gate. *(Verified at G0.1 human review — RESEARCH.md `RF-18`.)*
- **Geofencing would broaden the permission surface.** Reliable background geofence
  behaviour pushes toward background-location permission, which this feature does not
  need: the requirement is explicitly satisfied while the user is on the screen.
- Direct computation makes the rule a pure function, which is what makes AND-08
  independently unit-testable at the boundary (49.9 / 50.0 / 50.1 m).

### Consequences

- No background-location permission; `ACCESS_FINE_LOCATION` while-in-use is enough.
- Updates must be lifecycle-aware and must stop when the screen is not resumed, or
  the app drains battery — this becomes a review checkpoint at gate G3.
- The update interval is a deliberate choice (AMB-13). It must be a named constant
  with a comment justifying it, and it must be stated in the README.
- Distance uses the platform's geodesic distance calculation rather than a
  hand-rolled formula, so the 50 m boundary matches what the device itself reports.

---

<a id="adr-002"></a>

## ADR-002 — DataStore rather than Room for the office coordinates

**Status:** ACCEPTED — confirmed at G0.1 human review, 2026-08-28.

**Requirements:** GEN-03, AND-07

### Context

Exactly one office location must persist locally: a latitude, a longitude, and
(usefully) a capture timestamp. AND-07 requires it to survive process death.

### Decision

Use Jetpack DataStore (Preferences) for the office coordinates. Do not add Room.

### Reasoning

- The data is a **single record with no relations, no queries, and no history**.
  Room's value is relational querying and migrations; none applies here.
- Room would add a database, a DAO, an entity, and a code-generation step to store
  two doubles. That is the "abstraction without a real responsibility" that
  AGENTS.md prohibits.
- DataStore is transactional and asynchronous, and exposes values as a `Flow`, which
  composes directly with the location `Flow` in ADR-006 — the office coordinates and
  the current location combine into one UI state stream without extra plumbing.
- "Best practices" in GEN-03 favours DataStore over `SharedPreferences` for new code.
- Official Android Developers documentation positions DataStore for **small, simple
  datasets**, and Room for complex datasets, partial updates, or referential
  integrity. A single office coordinate pair is the former by every measure.
  *(Verified at G0.1 human review — RESEARCH.md `RF-19`.)*

### Consequences

- Storage sits behind an `OfficeLocationRepository` interface, so swapping to Room
  later (e.g. if attendance history is added) touches one implementation class.
- If a future requirement introduces an attendance *log*, that is a genuinely
  relational concern and Room should be reconsidered then — this ADR does not
  pre-commit against it.
- Note the asymmetry with ADR-005, which does choose SQLite for Flutter. The
  difference is real: one record versus a queryable queue.

---

<a id="adr-003"></a>

## ADR-003 — Dependency-free map visual rather than the Google Maps SDK

**Status:** ACCEPTED — approved at G0.1 human review, 2026-08-28, with the design
intent below made explicit and binding.

**Requirements:** AND-15, AMB-03, DOC-07, SUB-01

### Context

The p2 reference screenshot shows a map tile with a coordinate pill overlay. The
screenshot is prescriptive for Android ("Please refer to the following screenshot").
But **no sentence in the assessment requires a map** — the written Setup Phase
requirement is only to fetch and save the coordinates.

### Decision

Do **not** use the Google Maps SDK. Preserve the reference panel's **position and
information role**, and implement a dependency-free, project-owned location surface
using Compose vector drawing and/or project-owned assets — conveying office context,
a pin/status indicator, the 50 m radius, the user's position relative to it, and the
coordinate pill.

Binding constraints on that surface:

- **No Google Maps branding**, and no copyrighted or third-party map tiles.
- No API key and no network dependency, so a clean clone renders it in full.
- **Do not imply interactivity it does not have.** If the surface does not pan or
  zoom, it must not present affordances suggesting that it does.
- It must read as a deliberate, original context surface — not as a degraded
  stand-in for a map.

### Reasoning

- **A Maps SDK needs an API key, and the key cannot be committed.** AGENTS.md forbids
  committing secrets. An uncommitted key means a clean clone does not render the map,
  which directly damages DOC-07 ("steps to clone the repo and run the app") and
  SUB-01 ("complete, **functioning** source code"). A reviewer cloning the repo would
  hit a blank or broken map.
- Committing a key to a public repository (SUB-01) to avoid that is not an option.
- A drawn visual can show something a static map tile cannot: **the 50 m boundary
  itself**, plus the live user position relative to it. That is a better fit for the
  actual feature than a map tile, and it demonstrates the geofence rule visually.
- It keeps the dependency footprint honest, which AGENTS.md asks for.

### Consequences

- Visual fidelity to the p2 screenshot is deliberately non-literal: no street map
  imagery. This is the accepted cost and must be disclosed in the README rather than
  quietly shipped.
- The surface is held to the quality bar in [ADR-012](#adr-012). It is an original
  designed element, not a placeholder.
- The coordinate pill and the panel's information role (AND-15) are delivered in full.
- **Rejected alternative:** Maps SDK plus a documented `local.properties` key step,
  which would leave the panel blank for any reviewer cloning the repository without
  supplying their own key — defeating DOC-07 and SUB-01.

---

<a id="adr-004"></a>

## ADR-004 — Single Android module

**Status:** ACCEPTED

**Requirements:** GEN-08, AND-01

### Context

Multi-module Android architecture is common in senior portfolios and is often read as
a seniority signal. The assessment does not require it.

### Decision

Keep one `:app` module. Enforce layering with **packages** (`domain`, `data`,
`presentation`) rather than Gradle modules.

### Reasoning

- The app is one screen with one business rule. Module boundaries exist to manage
  build times and enforce dependency direction across a large team; neither pressure
  exists here.
- Multi-module would add Gradle configuration, a convention-plugin layer, and
  cross-module wiring that a reviewer must read past to reach the actual attendance
  logic — the opposite of the intended signal.
- AGENTS.md is explicit: "Senior engineering judgement includes knowing what not to
  build", and "do not introduce abstractions without a real responsibility."
- The reviewable property is that the 50 m rule is independently testable (AND-08).
  Package-level separation with a pure domain layer already achieves that.

### Consequences

- Layer discipline is a review responsibility, not a compiler-enforced one. The G3
  exit criteria include an explicit import-direction check.
- The README must state that single-module was a decision, not an oversight —
  otherwise it reads as the latter.

---

<a id="adr-005"></a>

## ADR-005 — Flutter: image files on the filesystem, metadata in SQLite

**Status:** ACCEPTED

**Requirements:** GEN-03, FLT-08, FLT-11, FLT-16

### Context

The Flutter app captures batches of images that must survive app death and reboot
while queued (FLT-11, FLT-16). The two candidate designs are: image bytes as BLOBs in
SQLite, or files on disk with a row holding the path and metadata.

### Decision

Write captured images to the application documents directory. Persist one SQLite row
per queued image holding its **file path**, batch id, capture timestamp, upload
state, attempt count, and last failure reason.

### Reasoning

- **The camera plugin already hands back a file.** Storing BLOBs means reading the
  file into memory and writing it back into the database — a pointless copy of every
  photo, and a memory spike proportional to image size.
- Camera images are megabytes each and batches are plural (FLT-08). Large BLOBs
  inflate the database file, slow queries that never need the bytes, and make the
  common query — "list pending uploads" (FLT-09) — needlessly expensive, since that
  list needs metadata and a thumbnail, not full-resolution bytes.
- Uploading from a file path streams; uploading from a BLOB requires materialising
  the whole image in memory first.
- The database stays small enough that queue reads are cheap on the UI thread's
  isolate boundary.

### Consequences

- **The file and the row can diverge**, and this must be handled rather than assumed
  away: a row whose file is missing (OS cleanup, user deletion) must be detected and
  moved to a terminal failed state, not retried forever. This is an explicit G6 test.
- Deleting a queue item must delete both the row and the file, or storage leaks.
- FLT-11 verification must assert **both** the row and the file still exist after a
  failed upload — checking only the row would pass while silently losing images.

---

<a id="adr-006"></a>

## ADR-006 — Android presentation architecture: MVVM with unidirectional data flow

**Status:** ACCEPTED

**Requirements:** GEN-01, GEN-02, AND-12, AMB-07

### Context

The assessment scopes its architecture requirement explicitly to Flutter ("Any
Layered Architecture **for Flutter**", p1). It mandates Kotlin Flow for state, but
names no Android architecture. AMB-07 records that gap.

### Decision

Android uses MVVM with unidirectional data flow: a `ViewModel` exposing a single
immutable `StateFlow<AttendanceUiState>`, with UI events flowing in as function
calls. Layers are `domain` (pure rules), `data` (device and persistence access), and
`presentation`.

### Reasoning

- A single state object makes the screen's many conditions — permission denied,
  services off, poor fix, office unset, in range, out of range — **mutually exclusive
  by construction**, rather than a set of independent booleans that can contradict
  each other. Given GEN-04's demand for graceful failure states, this is the property
  that matters most.
- `StateFlow` satisfies the mandated Kotlin Flow usage (AND-12) genuinely rather than
  decoratively, and is lifecycle-safe when collected correctly.
- The alternative of hoisting state into composables would put the 50 m rule inside
  the UI layer, making AND-08 hard to unit-test without a UI harness.
- It mirrors the Flutter side's Cubit/BLoC structure, so the README can describe one
  coherent approach across both apps (DOC-03).

### Consequences

- The distance/in-range decision lives in `domain` as a pure function, testable with
  plain JUnit and no Android dependencies.
- The ViewModel must not leak location callbacks; collection is tied to the resumed
  lifecycle state (see ADR-001 consequences).
- `AttendanceUiState` should model location quality explicitly (AMB-14), not assume
  every fix is trustworthy.

---

<a id="adr-007"></a>

## ADR-007 — Both applications in a single repository

**Status:** ACCEPTED

**Requirements:** SUB-01, DOC-01, DOC-07

### Context

The deliverable is "a public GitHub repository" (singular) containing source for both
a native Android app and a Flutter app.

### Decision

One repository: `android-attendance/` and `flutter-camera-sync/` side by side, with a
single root `README.md` covering both, and shared governance in `docs/`.

### Reasoning

- SUB-01 says "a public GitHub repository", and DOC-01 says "the repository must
  include a well-structured README.md". A split across two repos would force the
  reviewer to reconcile two READMEs and would leave one of them without the mandated
  AI-usage disclosure (DOC-05).
- One clone, one set of run instructions (DOC-07), one submission link.
- The two apps share no code, so co-location costs nothing technically.

### Consequences

- The root README must clearly separate per-app run instructions, since prerequisites
  differ (Android SDK vs Flutter SDK).
- `.gitignore` must cover both ecosystems — already verified in place.
- Two release APKs come from one repository (AMB-09, SUB-03).

---

<a id="adr-008"></a>

## ADR-008 — Deterministic mock API, not randomised

**Status:** ACCEPTED

**Requirements:** GEN-07, FLT-13, FLT-11, FLT-12, AMB-05

### Context

No API is supplied. The note on p3 permits either commenting out the API classes or
using hard-coded mock Success and Failed responses.

### Decision

Keep a real `UploadApi` interface with a `MockUploadApi` implementation whose outcome
is **explicitly selectable** (success / generic failure / low-bandwidth timeout /
no-connectivity). Do not comment out the networking code, and do not randomise the
outcome.

### Reasoning

- **Commented-out code cannot be tested and cannot be demonstrated.** The resilience
  requirements (FLT-11, FLT-12) are the substance of Task 2; hiding the call site
  behind comments would leave the most important behaviour unverifiable.
- A **random** mock would make the retry and failure paths non-reproducible. A
  reviewer following the README must be able to force a failure and watch the queue
  hold the image, then force success and watch it drain. Determinism is what makes
  that demo possible — and reproducibility is what EXP-04 rewards.
- An interface seam means swapping in a real HTTP client later is a one-class change,
  which is the honest reading of "API integration" in the Objective (AMB-05).
- The mock must simulate **latency** as well as outcome, or "low bandwidth" (FLT-11)
  cannot be distinguished from "no internet".

### Consequences

- The README must document exactly how a reviewer toggles the mock outcome (DOC-07).
- The toggle must be reachable at runtime, not only at compile time, so the behaviour
  can be demonstrated in the GIFs required by DOC-08.
- The mock lives in the `data` layer behind the domain-facing interface, so the sync
  logic under test never knows it is talking to a mock.

---

<a id="adr-009"></a>

## ADR-009 — Manual dependency wiring, no DI framework

**Status:** PROPOSED — revisit if the object graph grows past what a constructor
chain reads cleanly.

**Requirements:** GEN-08, ADR-004

### Context

Hilt (Android) and get_it/injectable (Flutter) are the conventional choices and are
often expected in senior work.

### Decision

Wire dependencies manually: constructor injection with a small composition root per
app. Add a framework only if the graph justifies it.

### Reasoning

- The object graph is small and shallow: a location source, a coordinate store, a
  rule, and a ViewModel on Android; a camera source, a queue store, a mock API, a
  sync engine, and Cubits on Flutter.
- Hilt adds annotation processing and build time; for this graph it mostly adds
  indirection between the reviewer and the logic.
- Constructor injection already delivers the property that matters — every collaborator
  is substitutable in tests — without a framework.

### Consequences

- The composition root must stay explicit and in one place per app, or wiring will
  scatter into widgets and composables.
- If the Flutter sync engine needs the same singleton from both the UI isolate and
  the background worker, that is a genuine reason to revisit — background workers run
  in a separate entry point and cannot see the UI composition root. Flagged for G6.

---

<a id="adr-010"></a>

## ADR-010 — Release APK signing strategy

**Status:** ACCEPTED — resolved 2026-08-28 by explicit human authorisation to prepare
the final signed release ahead of the general G8 gate. Blocker B-01 is resolved.

**Requirements:** SUB-03, GEN-08

### Context

SUB-03 requires a link to a **built release APK**. The Android baseline defined no
`signingConfig`, so `assembleRelease` produced an unsigned artifact that would not
install on a device. AGENTS.md forbids committing signing keys, and `.gitignore`
already excluded `*.jks`, `*.keystore`, and `key.properties` before this ADR resolved.

This was a real gap in the baseline, not a hypothetical one.

### Decision

Generate a local, project-specific release keystore that is **never committed**
(`android-attendance/keystore/presencelens-attendance-release.jks`, RSA 2048,
10 000-day validity, alias `presencelens-attendance`); reference it through
`android-attendance/key.properties`, which is also never committed; and have the build
fall back gracefully when those files are absent so a clean clone still builds
`assembleDebug` and `assembleRelease` (unsigned) without them. A tracked
`key.properties.example` with placeholder values documents the shape for any reviewer
who wants to produce their own signed build.

This is the preferred option named when the decision was first proposed — a generated
release keystore, not a debug-signed release.

### Reasoning

- An unsigned release APK cannot be installed by a reviewer, so SUB-03 would fail at
  the last step despite the code being complete.
- Signing with the debug key is the alternative. It installs, and it requires no
  secret handling — but shipping a debug-signed artifact as a "release APK" is not
  defensible senior practice, and a reviewer may notice.
- The clean-clone fallback matters because DOC-07 and SUB-01 require the repository to
  build for someone who has neither the keystore nor the password.
- Store and key passwords are independently generated 32-character random strings, so
  JKS (not PKCS12, which requires the two to match) is the correct keystore format
  here — verified when a PKCS12 conversion attempt failed for exactly that reason.

### Consequences

- `app/build.gradle.kts` reads `key.properties` conditionally at configuration time;
  no secret value is hard-coded in the build file.
- The README must state that release builds by a third party (no `key.properties`)
  will be unsigned, and that the published APK link carries the properly signed
  artifact built and verified in this session.
- The signed APK was verified with `apksigner verify --print-certs` (APK Signature
  Scheme v2, 2048-bit RSA) and smoke-tested by install and launch on
  `emulator-5554` before being copied to `android-attendance/release-artifacts/
  PresenceLens-Attendance-v1.0.0.apk` alongside its SHA-256 checksum. Full detail in
  [AI_USAGE.md Entry 007](AI_USAGE.md).
- **The keystore and `key.properties` exist only on this machine.** They must be
  backed up securely by the human before this machine's state can be considered
  disposable — losing them means every future release build carries a different
  signature and cannot upgrade-install over this one.

---

<a id="adr-011"></a>

## ADR-011 — Attendance availability window (screenshot-only element)

**Status:** ACCEPTED — approved at G0.1 human review, 2026-08-28. Resolves AMB-02.

**Requirements:** AND-21, AND-08, AMB-02, EXP-03, EXP-04

### Context

The prescriptive p2 screenshot shows "AVAILABLE 09:00 AM - 10:30 AM" beneath the
Mark Attendance button. No sentence in the assessment mentions a time window. The
only stated gate on the button is the 50 m radius (AND-08).

Both naive resolutions are wrong:

- **Ignore it** — the screenshot is prescriptive for Android and EXP-04 rewards
  missing no detail. Dropping a visible element is exactly the kind of detail an
  evaluator checks.
- **Enforce it as a hard gate** — this would make the button disabled inside 50 m
  outside those hours, which **contradicts AND-08**, the one behaviour the assessment
  states explicitly. Inventing a blocking rule from a mock is a requirement-level
  regression.

### Decision

Preserve the availability caption as **presentation detail only**. It is rendered
because the prescriptive screenshot shows it, and it may be styled to communicate
state — but it **must never become an attendance eligibility rule**.

The assessment's only explicit functional condition is the 50 m radius (AND-08).
Availability time appears solely in the visual reference and therefore carries no
behavioural authority.

### Reasoning

- Preserves AND-08 exactly as written — no mandated behaviour is altered.
- Preserves visual fidelity to the prescriptive screenshot (AND-10, AND-21).
- Demonstrates that the ambiguity was noticed and reasoned about rather than
  stumbled past, which is what EXP-03 and EXP-04 actually reward.

### Consequences

- A reviewer comparing against the screenshot sees the caption present.
- A reviewer testing the 50 m rule at any hour sees it behave as specified.
- The README must explain the choice, or the non-enforcement looks like a bug.
- **Implementation rule:** no code path may consult the availability window when
  deciding whether Mark Attendance is enabled. This is an explicit review checkpoint
  at G3.
- **Rejected alternatives:** omitting the caption (loses a detail from a prescriptive
  screenshot), and enforcing the window as a real gate (would contradict AND-08).

---

<a id="adr-012"></a>

## ADR-012 — Android visual direction: reference-layout fidelity with premium native Material 3 execution

**Status:** ACCEPTED — added and approved at G0.1 human review, 2026-08-28.

**Requirements:** AND-10, AND-13…AND-21, EXP-03, EXP-04, GEN-08

### Context

The p2 screenshot is prescriptive: the UI must follow it (AND-10). But "follow the
screenshot" has two failure modes at opposite extremes, and both cost marks.

A **literal low-fidelity clone** reproduces a mock pixel-for-pixel, including its
flatness, and reads as tracing rather than engineering. A **free reinterpretation**
drifts from the mandated information architecture and stops satisfying AND-10 at all.

The assessment explicitly rewards the middle path: EXP-03 welcomes a better approach,
and EXP-04 demands detail. This ADR fixes that middle path so it is a stated standard
rather than per-screen improvisation.

### Decision

**Reference-layout fidelity with premium native Material 3 execution.**

**Preserve from the reference — non-negotiable:**

- Information architecture and section ordering.
- All required controls and their roles.
- The recognisable overall composition, so the screen is identifiable as the
  reference screen.

**Elevate — required:**

- Refined typographic hierarchy, spacing rhythm, and a coherent shape system.
- Material 3 tonal surfaces, considered elevation, and purposeful colour — including
  status colour that carries meaning (in range / out of range / degraded fix).
- Consistent iconography, complete button states, and subtle, purposeful motion.
- Take inspiration from the restraint and polish associated with high-quality Apple
  HIG work — but **do not make an Android app look like iOS**. Native Android
  semantics, accessibility, touch targets, and Material behaviour take precedence in
  every conflict.

**Constraints — binding:**

- Use **stable** Material 3 / Compose only. Do not depend on alpha or preview design
  libraries for visual novelty.
- Required functionality must remain immediately understandable. Polish may never
  reduce clarity.
- Any enhancement beyond the reference is **clearly optional** and must not distort,
  extend, or reinterpret an assessment requirement.
- Motion must be subtle and purposeful — never decorative animation that delays a
  user action.

**For the map/location region specifically** (with [ADR-003](#adr-003)):

- Retain its position and approximate visual weight in the composition.
- Create an original, polished map-like context surface.
- Meaningfully convey office/location context and pin/status.
- Require no Google Maps SDK and no API key.

### Reasoning

- AND-10 mandates the layout, not the fidelity ceiling. Preserving the information
  architecture satisfies it exactly; the execution quality above it is free headroom
  the assessment explicitly invites (EXP-03).
- A mock is a communication artefact, not a design system. Reproducing its flatness
  would be a misreading of what the screenshot is for.
- Naming the standard now prevents the two predictable failures: shipping a flat
  clone, or drifting from the mandated layout while chasing polish.
- Restricting to stable APIs keeps SUB-01 ("complete, **functioning** source code")
  safe. Preview libraries are exactly the dependency class that breaks a clean clone
  months later.
- The Apple-HIG reference is about **restraint** — hierarchy, spacing, and
  considered motion — not about visual idiom. Stating that boundary explicitly stops
  it being read as "make it look like iOS".

### Consequences

- G3 carries more UI work than a literal clone would. The execution plan's G3 budget
  is increased accordingly, and the increase is drawn from the schedule slack.
- Accessibility is part of the bar, not a follow-up: content descriptions, touch
  target sizes, and contrast are G3 exit criteria.
- Every enhancement must be traceable to this ADR, so a reviewer can distinguish
  deliberate elevation from scope creep.
- Screenshots for DOC-08 should show the elevated screen next to the reference, so
  the fidelity relationship is visible rather than asserted.
- **This ADR governs presentation only.** It has no authority over behaviour. It can
  never justify altering AND-08, and it does not license the availability window to
  become an eligibility rule ([ADR-011](#adr-011)).

---

<a id="adr-013"></a>

## ADR-013 — Attendance screen becomes state-driven (G3.5 UX pass)

**Status:** ACCEPTED — approved by the human as the G3.5 UX direction, 2026-08-28, and the
two interpretive calls it left open **ruled on and accepted at G3.6, 2026-08-28**:

1. **AND-05.** "Set Office Location" is the exact initial Setup Phase label. Once an office
   exists, "Change office location" is approved.
2. **AND-21.** "Office hours" is the approved presentation label for the reference
   screenshot's 09:00 AM – 10:30 AM caption. The time is informational only and **must never
   participate in attendance eligibility** ([ADR-011](#adr-011) unchanged in force).

**Requirements:** AND-03, AND-04, AND-05, AND-10, AND-13…AND-21, GEN-04, EXP-03, EXP-04

**Relates to:** [ADR-011](#adr-011) (unchanged in force), [ADR-012](#adr-012) (this is
an application of it, not a replacement)

### Context

G3 delivered every element the p2 reference prescribes, and the emulator acceptance
run passed. What it did not deliver is a screen that changes *emphasis* with the
user's situation. Every state rendered the same four blocks at the same weight, so a
first-time user with no office saved saw a distance gauge measuring against nothing
and a Mark Attendance button competing with the only action available to them.

Three specific gaps followed from that:

- **No stated reason on a disabled control.** The button greyed out and said nothing
  about why. A disabled control with no explanation is a dead end.
- **A silent destructive path.** Pressing "Set Office Location" a second time
  overwrote a saved coordinate with no confirmation.
- **Undisclosed behaviour.** Where the office coordinates are stored, when location is
  read, and that nothing runs in the background were all true of the implementation
  and stated nowhere in the product.

### Decision

Keep **one** `AttendanceScreen` — no new destinations, no wizard, no tabs — and make
it state-driven.

1. **A dynamic status card** at the top of the screen, in one shape across twelve
   states, always saying what the app is doing and, when the action is unavailable,
   why. Which state is shown is decided by `AttendanceStatusPresenter`, a pure
   function, not inside a Composable.
2. **A first-use setup face.** With no office saved, the office card carries a
   heading, an explanation, and the single prominent filled action; the distance panel
   is not drawn, because it would be measuring against nothing.
3. **A stated reason beside a disabled Mark Attendance**, one short line, derived from
   the same state value the button's `enabled` reads.
4. **"Set Office Location" keeps its exact mandated label for the Setup Phase**
   (AND-05) — the state in which no office is saved. Once an office exists the setup
   phase is over, and the control steps back to a secondary "Change office location"
   behind an overwrite confirmation that names the coordinates being replaced.
5. **The availability caption is relabelled "Office hours"**, keeping the reference's
   position and value. "AVAILABLE 09:00 AM - 10:30 AM" reads as a rule; ADR-011
   already established it is not one, and the old wording was the last place the app
   still implied otherwise.
6. **A "How attendance works" bottom sheet** from the app bar: on-device storage,
   foreground-only reads, the 50 m radius, no background tracking, and the office-hours
   disclosure. A surface over the screen, not a destination.
7. **A compact success state** — the status card, a "Marked at HH:MM" line on the
   panel, and one haptic — replacing the snackbar for that event. The confirmation is
   shown only while the eligibility it confirms still holds.

   **Revised at G3.7 (2026-08-28), on human review of the app on a physical device.**
   The completed state as delivered here said the same thing three times — an
   "ATTENDANCE MARKED" overline, a relabelled disabled button reading "Attendance
   marked", and a green outline around both. It now renders **no control at all**: the
   status card carries the headline, and a single compact confirmation records the time
   and the distance verified at the moment of the mark. The haptic is unchanged.

   **The rule that "the confirmation is shown only while the eligibility it confirms
   still holds" is SUPERSEDED by [ADR-016](#adr-016) (G3.8, 2026-08-29).** A mark is an
   event and now outlives the live condition that permitted it. Everything else in this
   section stands.

### Reasoning

- Directive 2 of the approved brief requires every blocked state to explain why the
  main action is unavailable. That is a property of the *screen*, not of a single
  control, so it needed a first-class surface rather than more copy in the panel.
- Resolving state to presentation in a pure function keeps
  `android-attendance/AGENTS.md`'s "no decisions in Composables" rule intact and makes
  twelve states testable on the JVM (`AttendanceStatusPresenterTest`).
- **On AND-05.** The assessment names the label under the heading "Setup Phase". A
  screen that has completed setup is no longer in that phase, and offering
  "Set Office Location" for something that would *replace* a saved office is the less
  accurate label, not the more compliant one. The exact string is preserved wherever
  the Setup Phase is what the user is in.
- **On AND-21.** ADR-011 kept the caption because the screenshot is prescriptive, and
  forbade it from gating anything. Relabelling preserves the element, its position, and
  its value while removing the implied promise — which is the ADR's intent expressed in
  the copy rather than only in the code.
- The confirmation dialog exists because overwriting the office is the one irreversible
  thing this screen can do, and the user may have walked to the office to record it.

### Consequences

- A Compose UI test for AND-05 must assert the exact label **in the no-office state**;
  asserting it unconditionally would now fail by design. Recorded in the matrix.
- AND-17's gauge is not rendered before an office exists. The reference screenshot
  depicts a state that has one, so no prescribed element is lost.
- `R.string.availability_caption` is replaced by `office_hours_label` /
  `office_hours_value`. The ADR-011 audit is unchanged in kind: both have exactly one
  reference each, `Text` calls, and no path consults either when deciding enablement.
- The dark `errorContainer` is deepened from the Material baseline. "Out of range" is a
  routine condition, and at baseline saturation a full-width card in that role read as
  an alarm every time the user was simply not at the office yet.
- **Rejected alternatives:** a separate onboarding destination (contradicts AND-04 and
  the approved brief); hiding Mark Attendance entirely during setup (AND-04 wants both
  affordances in one composition — it is de-emphasised, not removed); enforcing office
  hours now that they are labelled as such (would contradict AND-08 and ADR-011).

---

<a id="adr-014"></a>

## ADR-014 — Location is a retained value with a freshness bound, not a stream of verdicts

**Status:** ACCEPTED — 2026-08-28 (G3.6), in response to an observed defect.

**Requirements:** AND-08, AND-09, GEN-04, AMB-13, AMB-14

**Relates to:** [ADR-001](#adr-001) (unchanged — still foreground Fused Location, still no
geofencing), [ADR-006](#adr-006) (this is that architecture applied more carefully)

### Context

A screen recording of a **stationary** emulator showed the app oscillating roughly every two
seconds:

```
Ready to mark attendance  →  Location unavailable  →  Ready to mark attendance  →  …
```

The saved office had not changed and the user had done nothing.

**Root cause.** `FusedLocationDataSource.onLocationAvailability` mapped
`LocationAvailability.isLocationAvailable == false` straight to
`LocationFix.Unavailable(NO_FIX_AVAILABLE)`, and `AttendanceViewModel` treated any
`Unavailable` as terminal: it discarded the fix in hand and rendered
`AttendanceStatus.LocationUnavailable`. The next scheduled `onLocationResult` — two seconds
later, by `UPDATE_INTERVAL_MILLIS` — restored the eligible state. The cycle then repeated.

Google documents `LocationAvailability` as a **best-guess estimate** of whether a location can
currently be obtained, not a statement that positioning has failed. On a stationary device the
fused engine flips it to `false` routinely between confident reports. A second, smaller
instance of the same mistake sat beside it: a `LocationResult` carrying no usable location was
also mapped to a failure, when it carries no information at all.

The defect was structural, not cosmetic. The state model asked "what did the provider last
say?" when the question the screen has to answer is "does the app currently hold a position
good enough to decide a 50 m boundary?"

### Decision

**1. Separate the provider's estimate from a real failure.** `LocationFix` gains
`ProviderReportedUnavailable` — advisory, never a failure — and `Unavailable` is renamed
`Failed` so the remaining case cannot be misread. An empty `LocationResult` now emits nothing.

**2. Retain the last usable position.** The ViewModel folds raw fixes into what it *knows*
(`LocationKnowledge`) and derives what it can *say* (`LocationReading`) from that knowledge
plus the age of the last fix. An availability estimate cannot discard a fix already held.

**3. Bound that retention with one named freshness threshold.**
`LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS = 10 000 ms`, measured against the device's
monotonic elapsed-realtime clock (`Location.getElapsedRealtimeNanos`), not the wall clock.

**4. Give staleness its own neutral state.** Past the threshold, with permission granted and
location services on, the screen shows `AttendanceStatus.RefreshingFix` — *"Updating your
location… / Waiting for a fresh GPS fix."* — in the **progress** tone with a spinner. Mark
Attendance is disabled (no `Tracking`, therefore no distance, therefore no eligibility), the
last position stays drawn on the location surface so nothing blinks, and "Set Office Location"
stays available because it issues its own one-shot request.

**5. Reserve "Location unavailable" for a real inability.** It is now reached only by
`LocationFix.Failed` — an exception, a Play Services fault, a one-shot capture whose window
elapsed — or by the single escalation path: the app has **never** held a position *and* the
acquisition window has passed *and* the provider says it cannot obtain one.

**6. Align the one-shot office capture with the same number.** `CurrentLocationRequest`
`maxUpdateAge` moves from an explicit 2 s to `FRESH_FIX_MAX_AGE_MILLIS` — both are chosen
values, neither is the platform default — and its duration from 10 s to 20 s, with an explicit
"Getting a precise fix. This can take a few seconds." note while it runs (AND-06).

**This part is SUPERSEDED by [ADR-015](#adr-015) (G3.8, 2026-08-29).** Reusing the live-screen
freshness bound for the office anchor was a mistake: it let a fix taken up to ten seconds
earlier, somewhere the user no longer is, permanently define the boundary. `maxUpdateAge` is
now `0` and the duration is 28 s. Sections 1–5 above are unchanged and remain in force, with
one addition — ADR-015 adds a **second** bound alongside freshness, so a fix may now also be
too *imprecise* to decide the rule, not only too old.

### Reasoning

- **Why not debounce.** A debounce would delay a wrong answer rather than stop producing one,
  and it would still be wrong in the case that matters — a genuinely dead provider would look
  identical to a healthy one for the length of the window.
- **Why 10 s.** It is five consecutive missed deliveries at the 2 s update cadence
  (`UPDATE_INTERVAL_MILLIS`), comfortably more than the one-or-two-sample gaps a stationary
  device produces, which is exactly the condition that must not disturb the UI. It is also
  short enough to stay honest about the rule: at walking pace (~1.4 m/s) ten seconds is about
  14 m of possible movement, well inside the 50 m boundary and inside the 25 m accuracy the
  app already tolerates (`LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS`). Pinned by
  `LocationFreshnessTest`.
- **Why elapsed realtime.** An NTP correction, a time-zone change, or a user editing the
  system clock would make a fresh fix look hours old under a wall-clock comparison. Freshness
  is a duration, so it is measured with the clock that only measures durations.
- **Why staleness disables the action.** AND-08 is a statement about where the user *is*. A
  position the app can no longer vouch for cannot support that claim, so the honest response
  is to stop claiming it — quietly, in a progress tone, not with an alarm.

### Consequences

- `AttendanceStatusKind` gains `REFRESHING_FIX` and `MarkAttendanceBlocker` gains `STALE_FIX`,
  both covered by `AttendanceStatusPresenterTest`.
- `DeviceLocation.timestampEpochMillis` is replaced by `elapsedRealtimeMillis`. The wall-clock
  stamp had no consumer; the monotonic one has exactly one, and it is the rule above.
- `AttendanceViewModel` takes an injected `elapsedRealtime: () -> Long` (defaulting to
  `SystemClock::elapsedRealtime`) and runs a 1 Hz freshness tick while the screen is observing.
  The tick is inside the `WhileSubscribed` graph, so it stops with the screen, and identical
  readings are dropped by `distinctUntilChanged` — a tick that changes nothing hands the UI
  nothing, which is asserted by a test.
- A held-but-stale position never escalates to "Location unavailable" no matter how old it
  gets. This is deliberate: "Updating your location…" is true and actionable, and the brief is
  explicit that a red failure state must not be the reaction to a provider simply going quiet.
- **What is not covered by automated tests.** The `LocationAvailability` → advisory mapping in
  `FusedLocationDataSource` is Play Services-facing, and the project has no Robolectric or
  mocking framework (ADR-009's spirit). The three lines are documented at the call site, and
  the emulator soak below is their evidence.
- **Rejected alternatives:** debouncing the error state (delays a wrong answer, does not
  remove it); ignoring `LocationAvailability` entirely (throws away the one signal that
  distinguishes "indoors with no signal" from "acquiring"); keeping the distance readout live
  from a stale fix (would leave AND-08 deciding from a position the app cannot vouch for).

---

<a id="adr-015"></a>

## ADR-015 — Fix quality is a prerequisite for the rule, not a second rule

**Status:** ACCEPTED — 2026-08-29 (G3.8), on a source-level accuracy audit.

**Requirements:** AND-06, AND-07, AND-08, AND-09, GEN-04, AMB-13, AMB-14

**Relates to:** [ADR-001](#adr-001) (unchanged — still foreground Fused Location, still no
geofencing, still no background permission), [ADR-011](#adr-011) (unchanged in force),
[ADR-014](#adr-014) (this extends its "retained value" model with a second bound)

### Context

ADR-014 made the app stop trusting a position *older* than ten seconds. It left untouched the
question of whether a position is *precise enough* to answer what is being asked of it, and
three specific gaps followed:

1. **The live stream asked for a fast first fix rather than a good one.**
   `setWaitForAccurateLocation(false)` told Play Services to hand over whatever it had rather
   than briefly hold out for GNSS. Under `PRIORITY_HIGH_ACCURACY` the first delivery is
   routinely a network fix accurate to a few hundred metres — evaluated against a 50 m rule,
   and capable of reporting "in range" before the device has any real idea where it is.
2. **Accuracy was surfaced and never consulted.** A fix reporting ±180 m produced a live
   distance, an "IN RANGE" chip, and an enabled Mark Attendance button, with a caution banner
   beside it. The banner was honest; the button was not.
3. **The office anchor was saved without qualification at all.** `getCurrentLocation` returned
   what it returned and it was written to disk. `maxUpdateAge` was set to the same ten seconds
   the live screen uses, so a cached fix from wherever the user stood ten seconds ago could
   permanently define the boundary.

The third is the one with lasting consequences. A bad live fix is discarded a second later; a
bad anchor silently biases **every** distance the app ever reports, and nothing on screen
would ever reveal it.

### Decision

**1. High-accuracy first delivery is restored.** `setWaitForAccurateLocation(true)` on the
streaming request. The brief wait it can introduce is spent in the "Finding your location…"
state the screen already has, which is a better trade than a coarse first fix landing against
a 50 m boundary. The 2 s cadence is unchanged.

**2. Accuracy becomes a usability gate, expressed as a prerequisite.** `LocationQuality` gains
`UNUSABLE`, and both thresholds derive from `AttendanceRule.ELIGIBLE_RADIUS_METERS`:

| Reported accuracy | Quality | Live fix | Office capture |
| --- | --- | --- | --- |
| `<= radius / 2` (25 m) | `PRECISE` | decides the rule | saved |
| `radius / 2 .. radius` (25–50 m) | `DEGRADED` | decides the rule, with the existing caution | saved, reported as limited |
| `> radius` (50 m) | `UNUSABLE` | `ImprovingAccuracy`, action disabled | **refused, nothing written** |
| not reported | `UNKNOWN` | `ImprovingAccuracy`, action disabled | **refused, nothing written** |

**This is not a second geographic rule, and `distance <= 50 m` remains the only one.** The app
never evaluates `distance + accuracy <= 50`. What the table decides is whether the fix in hand
is a measurement the rule can be applied to at all — a reading whose own error radius exceeds
the circle being tested cannot answer "inside or outside" in either direction, so authorising
from it would be false confidence rather than compliance. `canMarkAttendance` is untouched and
still reads distance alone; an unusable fix simply never reaches it.

`UNKNOWN` fails closed alongside `UNUSABLE`. The alternative is authorising attendance from a
reading the app knows nothing about.

**3. The office capture derives a position rather than accepting one.**
`CurrentLocationRequest` moves to `maxUpdateAgeMillis = 0` — no cache at any age — with
`GRANULARITY_FINE` stated rather than inherited, and the window widened from 20 s to 28 s
because the whole window must now cover a genuine acquisition. Above 50 m of error, or with no
accuracy reported, **nothing is persisted** and an existing office is left exactly as it was.
Between 25 m and 50 m the capture succeeds and says so, because refusing there would strand a
user indoors with no way to finish setup at all.

**4. Provider faults are interruptions, not the end of tracking.** The stream was terminated
by `.catch { emit(Failed) }`, and the only recovery was for the user to leave the screen and
come back — which is not a recovery a user can be expected to discover. It now retries on a
capped backoff (1 s → 2 s → 5 s) for as long as the screen is subscribed, via `retryWhen` so
Kotlin's flow exception transparency is preserved and `awaitClose` still removes the platform
callback before each re-subscription. The failure is still reported while it stands.

**5. Accuracy is not persisted.** `OfficeLocation` keeps latitude, longitude, and
`capturedAtEpochMillis` and nothing else. The accuracy that qualified a capture has no later
consumer — distance is measured from the point, and every live fix carries its own accuracy —
so storing it would add a nullable field and a migration for a number nothing reads back.

### Reasoning

- **Why thresholds at `radius / 2` and `radius`.** Half the radius is the point at which the
  reported position and the true position can fall on opposite sides of the boundary, which is
  what makes a caution meaningful. The radius itself is the point at which the uncertainty
  swallows the whole area being tested, which is what makes the reading useless. Neither number
  is invented; both are read off the one rule the product has.
- **Why the capture is stricter than the live screen.** Asymmetric consequences: a rejected
  live fix costs a second, a bad anchor is permanent and invisible.
- **Why `ImprovingAccuracy` is its own state rather than `RefreshingFix`.** They are different
  waits and deserve different sentences — one is waiting for a *newer* reading, the other for a
  *tighter* one. Age is checked first, so an old imprecise fix reads as stale, which is the
  more fundamental problem.
- **Why capped backoff and not something cleverer.** The failure being recovered from is a
  transient Play Services fault with a user standing there watching. One quick attempt, then a
  ceiling low enough that recovery still feels immediate, is the whole requirement.

### Consequences

- `AttendanceStatus` gains `ImprovingAccuracy`, `AttendanceStatusKind` gains
  `IMPROVING_ACCURACY`, and `MarkAttendanceBlocker` gains `IMPRECISE_FIX` — *"Improving
  location accuracy… / Waiting for a more precise location fix."*, in the **progress** tone,
  never the failure tone.
- **A behaviour previously documented as settled is reversed.** ADR-014 and
  `android-attendance/AGENTS.md` said fix quality is "surfaced as a caution, never converted
  into a refusal". That remains true for `DEGRADED`, which is the case the sentence was written
  about; it no longer holds for a fix wider than the radius itself. Both documents are updated.
- The office capture now has four distinct refusals — no fix, too coarse, accuracy unknown,
  storage failed — and only two paths that write. `SetOfficeLocationUseCaseTest` asserts *that
  nothing was written* on each refusal, not merely which result came back.
- `FusedLocationDataSource` exposes its two request builders as `internal` functions so
  `LocationRequestConfigurationTest` can assert `maxUpdateAge = 0`,
  `waitForAccurateLocation = true`, `GRANULARITY_FINE`, and the capture window on the JVM.
  Play Services floors the reported `maxUpdateDelayMillis` at the interval, so "never batches"
  is asserted as "no delay beyond one interval" rather than as the zero that was set.
- **Correcting ADR-014 §6.** It described moving `maxUpdateAge` "from 2 s to
  `FRESH_FIX_MAX_AGE_MILLIS`" as an alignment. Both values were explicit choices, not platform
  defaults, and reusing the live-screen bound for the anchor was the mistake this ADR fixes.
- **Rejected alternatives:** `distance + accuracy <= 50` (changes the mandated rule); averaging
  or best-of-N capture (a calibration state machine this product does not need, whose failure
  modes are harder to explain than a single qualified fix); persisting capture accuracy (data
  with no consumer); raw `GPS_PROVIDER`, GNSS measurements, or Wi-Fi RTT (abandons the fused
  engine's own sensor blending for a worse result); mock-location detection (an anti-abuse
  feature the assessment does not ask for).

---

<a id="adr-016"></a>

## ADR-016 — A marked attendance is an event, not a live condition

**Status:** ACCEPTED — 2026-08-29 (G3.8), on explicit human ruling. **Supersedes
[ADR-013](#adr-013) §7's rule** that "the confirmation is shown only while the eligibility it
confirms still holds"; ADR-013 is otherwise unchanged and remains in force.

**Requirements:** AND-08, AND-20, EXP-03

### Context

`AttendanceUiState.isAttendanceConfirmed` read:

```kotlin
markedAttendance != null && canMarkAttendance
```

which made a completed action depend on a live condition. Two consequences followed, neither
intended when the rule was written:

- **A momentary stale fix erased the receipt.** Ten seconds of provider silence — the exact
  condition ADR-014 exists to treat as *normal* — removed a confirmation the user had earned.
- **Walking away erased it too.** A user who marked attendance and then left the building saw
  the screen revert to "Move closer to the office", as though the mark had not happened.

In both cases nothing about the past had changed. The screen was reporting a fact about
history as though it were a fact about the present.

### Decision

`isAttendanceConfirmed` is `markedAttendance != null`. The receipt — the time marked, and the
distance verified at the instant the rule was applied — stands for the rest of the session.

`canMarkAttendance` is untouched and remains live: it goes on describing where the user is
now, distance-only, exactly as AND-08 requires. The two values are allowed to disagree, and
after the user walks away they must.

The status card checks confirmation **before** eligibility, so a marked-and-departed screen
reads "Attendance marked" rather than asking for work already done. `markAttendanceBlocker`
returns `null` once confirmed, because no control is rendered and there is no refusal to
explain.

Scope is unchanged: session-scoped local state, no history, no persistence, no backend (p3
Note). Leaving the screen still ends it.

### Reasoning

- A mark is a statement about a moment: *at 10:32, verified 12 m from the office*. Nothing the
  user does afterwards makes that statement false, and a UI that withdraws it is asserting
  something untrue about the past.
- The original rule was defending against a real failure — a stale success message sitting over
  a screen where attendance is no longer possible. That concern is answered by keeping
  `canMarkAttendance` live and by the panel rendering a receipt rather than a control (the
  G3.7 rebuild), not by deleting the record.
- **The conflict with ADR-013 §7 was raised before implementation and ruled on by the human**,
  as `AGENTS.md`'s requirement discipline demands. It is recorded here rather than edited into
  ADR-013, so the earlier reasoning stays legible.

### Consequences

- `AttendanceViewModelTest` and `AttendanceStatusPresenterTest` both replace their
  "confirmation retires" cases with the inverse, plus a stale-fix case and a case asserting
  that `canMarkAttendance` still tracks the current position after a mark.
- A user standing outside the radius after marking sees a success headline and a receipt, with
  the live distance still shown on the gauge above. That combination is intended.
- **Rejected alternative:** keeping the live status card honest by showing `OUT_OF_RANGE`
  beneath a standing receipt. It puts two sentences about the same moment on one screen, one of
  which asks the user to do something they have already done.

---

<a id="adr-017"></a>

## ADR-017 — Layered MVVM with selective use cases, not strict Clean Architecture

**Status:** ACCEPTED — 2026-08-29 (G3.8).

**Requirements:** AND-12, GEN-01

**Relates to:** [ADR-004](#adr-004) (single module, unchanged), [ADR-006](#adr-006) (this
states what that architecture is and is not), [ADR-009](#adr-009) (same principle, applied to
wiring)

### Context

Two things were true at once. `AttendanceViewModel` privately owned `LocationKnowledge` and
`LocationReading` — a pure state machine deciding whether a position may answer a geographic
question, reachable only through a ViewModel, a test dispatcher and a fake clock. And the
office capture, the one action in the app with permanent consequences, was sequenced inline in
an event handler.

The available over-correction is a use case per verb: `GetOfficeLocationUseCase`,
`ObserveLocationUpdatesUseCase`, `CalculateDistanceUseCase`, `MarkAttendanceUseCase`. Each
would be a class forwarding one call to one collaborator.

### Decision

**1. The location state machine moves to `domain/location/`.** `LocationKnowledge` and
`LocationReading` become domain types with zero Android imports, tested directly.

**2. Exactly one use case is added: `SetOfficeLocationUseCase`.** It is the only action that
spans two collaborators and a policy — acquire a fresh position, qualify it against ADR-015,
persist it, report which step decided the outcome. It returns `SetOfficeLocationResult` and
contains no user-facing copy; the ViewModel maps results to messages.

**3. No other use cases are added.** Everything else the screen does is a pure function
(`AttendanceRule`) or a single repository call. A wrapper around either adds a file to read and
removes nothing.

**4. The architecture is described accurately.** In documentation and in interview, this is
**layered MVVM with unidirectional data flow, an Android-free domain layer, repository
abstractions, and selective use cases where orchestration justifies them.** It is deliberately
**not** described as "strict Clean Architecture": there are no separate Gradle modules, no
mapper layer between data and domain models, no entity/interactor split, and no use case for
most operations. Claiming the label would be inaccurate about the code a reviewer can read.

### Reasoning

- The test for whether logic belongs in `domain` is whether it is a rule that survives the UI.
  "Is this position trustworthy enough to answer the question?" is such a rule; "which colour
  is the status card" is not.
- The test for a use case is whether it *orchestrates*. One that forwards a single call is
  indirection wearing the costume of structure.
- Naming the architecture honestly is cheaper than defending an inflated label. A reviewer who
  hears "Clean Architecture" and finds a single module with no mappers concludes the claim was
  decoration; one who hears the sentence above finds exactly what was described.

### Consequences

- `AttendanceViewModel` loses roughly 90 lines and gains a use case dependency.
  `AttendanceComponent` names the location source and the repository so both are shared rather
  than duplicated.
- `LocationKnowledgeTest` and `SetOfficeLocationUseCaseTest` exercise the two moved
  responsibilities with no ViewModel, no dispatcher and no Android.
- `DomainLayerPurityTest` asserts the "zero Android imports" rule against the domain sources
  themselves, including a guard that fails if the scan finds no files — an architecture test
  that silently scans nothing is worse than none.
- Test fakes move from `presentation/attendance/AttendanceTestFakes.kt` to
  `fakes/LocationFakes.kt`: a domain test reaching into a `presentation.*` package for a fake
  would quietly contradict the layering those tests exist to demonstrate.
- **Rejected alternatives:** a `:domain` Gradle module (ADR-004 — module boundaries for a
  single-screen assessment cost build complexity and buy an import rule a test already
  enforces); a use case per operation (ceremony); leaving the state machine in the ViewModel
  (the status quo the audit found).
