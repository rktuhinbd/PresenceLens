# Android Attendance — Agent Guidance

Scoped to `android-attendance/`. Read the root [AGENTS.md](../AGENTS.md) first —
this file only adds Android-specific rules. Priority order for facts about this
app: [DECISIONS.md](../docs/DECISIONS.md) (ADR-001, 002, 003, 004, 006, 009, 011,
012, 013, 014) → [ARCHITECTURE.md](../docs/ARCHITECTURE.md) → [REQUIREMENTS_MATRIX.md](../docs/REQUIREMENTS_MATRIX.md)
(`AND-*` rows) → this file.

## Architecture

- Single `:app` module ([ADR-004](../docs/DECISIONS.md#adr-004)). Layer with
  packages — `domain`, `data`, `presentation` — not Gradle modules.
- MVVM + unidirectional data flow ([ADR-006](../docs/DECISIONS.md#adr-006)): one
  `ViewModel` exposing a single `StateFlow<AttendanceUiState>`. UI events flow in
  as function calls, never the reverse.
- `domain` has zero Android imports. The 50 m rule (`AttendanceRule`, AND-08)
  must be plain-JUnit testable with no device, no emulator, no Robolectric.
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
- **Location is a retained value with one freshness bound**, not a stream of verdicts.
  `LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS` is the only such threshold; measure age
  on the monotonic elapsed-realtime clock, never the wall clock. Past it the screen
  shows `RefreshingFix` in the **progress** tone and disables Mark Attendance — it does
  not show a failure.

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
