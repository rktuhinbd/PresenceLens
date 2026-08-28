# Android Attendance — Agent Guidance

Scoped to `android-attendance/`. Read the root [AGENTS.md](../AGENTS.md) first —
this file only adds Android-specific rules. Priority order for facts about this
app: [DECISIONS.md](../docs/DECISIONS.md) (ADR-001, 002, 003, 004, 006, 009, 011,
012, 013, 014, 015, 016, 017) → [ARCHITECTURE.md](../docs/ARCHITECTURE.md) → [REQUIREMENTS_MATRIX.md](../docs/REQUIREMENTS_MATRIX.md)
(`AND-*` rows) → this file.

## Architecture

- **The architecture is "layered MVVM with unidirectional data flow, an Android-free
  domain layer, repository abstractions, and selective use cases where orchestration
  justifies them"** ([ADR-017](../docs/DECISIONS.md#adr-017)). Use that phrasing.
  **Never describe it as "strict Clean Architecture"** — there are no separate modules,
  no mapper layer, no entity/interactor split, and one use case rather than one per
  operation. The label would be inaccurate about code a reviewer can read.
- Single `:app` module ([ADR-004](../docs/DECISIONS.md#adr-004)). Layer with
  packages — `domain`, `data`, `presentation` — not Gradle modules.
- MVVM + unidirectional data flow ([ADR-006](../docs/DECISIONS.md#adr-006)): one
  `ViewModel` exposing a single `StateFlow<AttendanceUiState>`. UI events flow in
  as function calls, never the reverse.
- `domain` has zero Android imports, and `DomainLayerPurityTest` asserts it. The 50 m
  rule (`AttendanceRule`, AND-08), the freshness and accuracy bounds
  (`LocationKnowledge`/`LocationReading`), and `SetOfficeLocationUseCase` must all be
  plain-JUnit testable with no device, no emulator, no Robolectric.
- **`SetOfficeLocationUseCase` is the only use case, and that is deliberate.** Do not add
  `GetOfficeLocationUseCase`, `SaveOfficeLocationUseCase`, `ObserveLocationUpdatesUseCase`,
  `EvaluateAttendanceEligibilityUseCase`, `MarkAttendanceUseCase`, or
  `CalculateDistanceUseCase`. Each would forward one call to one collaborator. A use case
  earns its place by orchestrating; this one acquires, qualifies, persists, and reports.
- No business logic in Composables. A Composable reads state and emits events —
  nothing else. If a Composable needs a decision (in-range? which state to
  render?), that decision was computed upstream, not inline.
- Manual constructor-injection wiring, no Hilt/DI framework
  ([ADR-009](../docs/DECISIONS.md#adr-009)). The object graph is small (a
  location source, a coordinate store, a rule, a ViewModel); a framework here
  would add ceremony a reviewer must read past, not remove any.

## Location

- Foreground `FusedLocationProviderClient` only, high-accuracy priority
  ([ADR-001](../docs/DECISIONS.md#adr-001)). **No `GeofencingClient`** — its
  recommended minimum radius (~100–150 m) is well above this feature's 50 m
  gate and it cannot supply a continuous distance value.
- Location logic lives in `data` (a `LocationDataSource` wrapping the client,
  exposed as a `callbackFlow`), never in `MainActivity` or any Composable.
- Collection is lifecycle-aware: bound to the resumed state, stopped when the
  screen is not visible. This is a review checkpoint, not a suggestion.
- Only `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` (while-in-use).
  Background location is out of scope — never add it.
- Model permission, service-availability, fix-freshness, and fix-quality as explicit
  states (`PermissionRequired`, `LocationServicesDisabled`, `AcquiringFix`,
  `RefreshingFix`, coarse-only treated as insufficient for a 50 m decision). Never
  represent these as independent booleans that could contradict each other.
- **`LocationAvailability` is advice, never a verdict**
  ([ADR-014](../docs/DECISIONS.md#adr-014)). Play Services documents it as a best-guess
  estimate, and a stationary device flips it to `false` routinely. It arrives as
  `LocationFix.ProviderReportedUnavailable` and may never on its own discard a held fix
  or produce `AttendanceStatus.LocationUnavailable`. Reintroducing that mapping
  reintroduces the G3.6 oscillation defect.
- **Location is a retained value with two bounds**, not a stream of verdicts.
  *Age:* `LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS`, measured on the monotonic
  elapsed-realtime clock, never the wall clock — past it the screen shows `RefreshingFix`.
  *Accuracy:* `LocationQuality`, past the attendance radius (or unreported) it shows
  `ImprovingAccuracy` ([ADR-015](../docs/DECISIONS.md#adr-015)). Both are the **progress**
  tone and both disable Mark Attendance; neither is a failure. Age is checked first.
- **Fix accuracy is a prerequisite for the rule, never a term in it**
  ([ADR-015](../docs/DECISIONS.md#adr-015)). `distance <= 50 m` remains the *only*
  eligibility rule and `canMarkAttendance` still reads distance alone. What accuracy
  decides is whether the fix is a measurement the rule can be applied to — a reading whose
  error radius exceeds the radius being tested never reaches `Tracking`. **Never write
  `distance + accuracy <= radius`.** Both thresholds derive from
  `AttendanceRule.ELIGIBLE_RADIUS_METERS`; never hard-code 25 or 50.
- Between half the radius and the radius, a fix is `DEGRADED`: **surfaced as a caution,
  never converted into a refusal.** That earlier rule still holds for this band, and only
  for this band.
- **The office capture is stricter than a live fix, and must stay so.** `maxUpdateAge = 0`
  (no cache at any age), and a fix wider than the radius — or carrying no accuracy —
  **persists nothing** and leaves an existing office untouched. A bad live fix costs a
  second; a bad anchor silently biases every distance the app will ever report.
- Do **not** persist capture accuracy on `OfficeLocation`. It has no later consumer.
- **A provider fault is an interruption, not the end of tracking.** The stream retries on
  a capped backoff while the screen is subscribed. Never replace that with a terminal
  `.catch { }` — that is the defect ADR-015 §4 fixed.
- **"Set Office Location" is not coupled to the live stream.** It depends on the precise
  grant, the OS toggle, and whether a capture is already running — nothing else. It issues
  its own one-shot request and owns its own outcome.

## Persistence

- Office coordinates: DataStore Preferences, not Room, not SharedPreferences
  ([ADR-002](../docs/DECISIONS.md#adr-002)). It is one record with no relations
  — Room would be an abstraction with no responsibility here.
- The 50 m radius is a single named constant in `domain`. Nothing else may
  hard-code it.

## UI

- Jetpack Compose only. No XML layouts for the feature.
- **Stable Material 3 / Compose only** — no alpha or preview design libraries,
  ever, even for visual novelty ([ADR-012](../docs/DECISIONS.md#adr-012)).
- Standard: reference-layout fidelity (p2 screenshot's information architecture,
  ordering, controls, composition) with premium native Material 3 execution
  (typography, spacing, shape, tonal surfaces, meaningful status colour,
  complete button states, subtle motion). Not a literal flat clone; not a free
  reinterpretation. Every enhancement beyond the reference must trace to
  ADR-012 and must never distort a requirement.
- No Google Maps SDK, no API key, no third-party map tiles or branding
  ([ADR-003](../docs/DECISIONS.md#adr-003)). The location/map region is an
  original Compose-drawn surface. It must not present pan/zoom affordances it
  doesn't implement.
- The office-hours caption — the reference screenshot's "AVAILABLE 09:00 AM –
  10:30 AM", relabelled "Office hours" by
  [ADR-013](../docs/DECISIONS.md#adr-013) — is presentation only
  ([ADR-011](../docs/DECISIONS.md#adr-011)). **No code path may consult it when
  deciding Mark Attendance enablement.** The 50 m radius is the only gate.
- **A marked attendance is an event, not a live condition**
  ([ADR-016](../docs/DECISIONS.md#adr-016), superseding ADR-013 §7). Once marked in a
  session, `isAttendanceConfirmed` stays true through a stale fix and through the user
  walking out of range; `canMarkAttendance` stays live and distance-only. Never restore
  `markedAttendance != null && canMarkAttendance`.
- The screen is state-driven ([ADR-013](../docs/DECISIONS.md#adr-013)): a setup face
  before an office exists, a tracking face after. `AttendanceStatusPresenter` resolves
  state to what the status card says and to why Mark Attendance is unavailable — that
  mapping is a pure function and stays one, so it can be tested on the JVM.
- **"Set Office Location" is the exact, mandated label whenever no office is saved**
  (AND-05, the Setup Phase). It becomes "Change office location" only once setup is
  complete, and that path must stay behind the overwrite confirmation.
- Accessibility is a first-class exit criterion, not a follow-up: content
  descriptions on icon-only controls, minimum touch target size (48dp),
  adequate contrast for status colour.

## Verification discipline

- Nothing is `DONE` in the matrix without its own stated verification executed.
- A green build is not evidence for a feature requirement — only the specific
  test/manual method named in REQUIREMENTS_MATRIX.md counts.
- Before calling any change finished: format/lint, run unit tests, run
  `assembleDebug`, inspect `git diff`, update the matrix and PROJECT_STATE.md.
