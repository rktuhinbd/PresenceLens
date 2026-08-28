# Architecture

The smallest structure that satisfies the assessment and keeps every mandated rule
independently testable. Decisions behind these shapes live in
[DECISIONS.md](DECISIONS.md); requirement IDs refer to
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md).

## Guiding constraint

Two things drive nearly every choice below:

1. **The mandated rules must be testable without a device.** The 50 m decision
   (AND-08) and the sync state machine (FLT-10 to FLT-12) are what the assessment is
   actually measuring. Both are pushed into pure, dependency-free code.
2. **Failure states are first-class, not afterthoughts.** GEN-04 mandates graceful
   handling of permission and hardware failure. Modelling those as explicit states —
   rather than as booleans checked ad hoc — is what keeps the UI honest.

Everything else is kept deliberately small. Per AGENTS.md, abstractions without a
real responsibility are not added.

---

## Repository layout

```
PresenceLens/
├── android-attendance/       Task 1 — Kotlin + Compose (exists, baseline only)
├── flutter-camera-sync/      Task 2 — Flutter + BLoC (NOT YET CREATED)
├── docs/                     governance, requirements, decisions, plan
└── README.md                 submission documentation (NOT YET CREATED)
```

One repository for both apps — [ADR-007](DECISIONS.md#adr-007).

---

## Application 1 — Android geo-attendance

**Verified baseline:** AGP 9.3.2, Gradle 9.5.0, Kotlin 2.2.10, Compose BOM
2026.02.01, `compileSdk`/`targetSdk` 37, `minSdk` 24, namespace
`io.github.rktuhinbd.presencelens.attendance`. Single `:app` module
([ADR-004](DECISIONS.md#adr-004)).

### Layers

**Layered MVVM with unidirectional data flow, an Android-free domain layer, repository
abstractions, and selective use cases where orchestration justifies them**
([ADR-017](DECISIONS.md#adr-017)). Deliberately *not* described as strict Clean Architecture:
there are no separate Gradle modules, no mapper layer between data and domain models, no
entity/interactor split, and exactly one use case rather than one per operation. The label
would be inaccurate about the code a reviewer can read.

Packages inside `:app`, with dependencies pointing inward only:

```
presentation ──▶ domain ◀── data
     │                        │
   Compose UI            device + storage
   ViewModel             access
```

`domain` depends on nothing. That is the property that makes AND-08 unit-testable
with plain JUnit, and it is asserted by `DomainLayerPurityTest` rather than trusted.

#### `domain` — pure, no Android imports

| Element | Responsibility | Why it exists |
| --- | --- | --- |
| `OfficeLocation` | Saved office coordinates + capture time. | The persisted unit (AND-07). Accuracy is deliberately **not** stored ([ADR-015](DECISIONS.md#adr-015)) — it has no later consumer. |
| `DeviceLocation` | Current position + accuracy + monotonic timestamp. | Carries accuracy so quality can be judged (AMB-14). |
| `AttendanceRule` | `(current, office, radius) -> ProximityResult` | **The mandated 50 m rule (AND-08), isolated.** Pure function, testable at the boundary. |
| `ProximityResult` | Distance in metres + in-range flag + bearing. | Feeds both the gauge (AND-17) and the button gate (AND-08). |
| `LocationFreshness` | How old a fix may be (10 s, monotonic clock). | The retention bound ([ADR-014](DECISIONS.md#adr-014)). |
| `LocationQuality` | Classifies a reported error radius against the attendance radius. | The trust bound ([ADR-015](DECISIONS.md#adr-015)). Both thresholds derive from the 50 m constant. |
| `LocationKnowledge` / `LocationReading` | Folds raw fixes into what the app knows, then reads that at an instant against age **and** accuracy. | The "may this position decide the rule?" state machine. Moved out of the ViewModel at G3.8 ([ADR-017](DECISIONS.md#adr-017)). |
| `SetOfficeLocationUseCase` | Acquire a fresh position → qualify it → persist → report which step decided. | The one action spanning two collaborators and a policy; the only use case in the app. Returns `SetOfficeLocationResult` and holds no UI copy. |

The 50 m radius is a single named constant in `domain`. Nothing else may hard-code it, and the
two accuracy thresholds are derived from it rather than written down again.

**Distance remains the only eligibility rule.** `LocationQuality` decides whether a fix is a
measurement the rule can be applied to; it never becomes a term in the rule. The app does not
evaluate `distance + accuracy <= 50`.

#### `data` — device and persistence access

| Element | Responsibility | Notes |
| --- | --- | --- |
| `LocationDataSource` | Wraps `FusedLocationProviderClient`. Streaming updates as a `callbackFlow`; a separate one-shot current-location call for "Set Office Location" (AND-06). | High-accuracy priority ([ADR-001](DECISIONS.md#adr-001)). Cancellation must remove the callback. The stream waits for an accurate first fix; the one-shot capture refuses the cache entirely (`maxUpdateAge = 0`) at `GRANULARITY_FINE` over a 28 s window ([ADR-015](DECISIONS.md#adr-015)). |
| `OfficeLocationRepository` | Reads/writes office coordinates as a `Flow`. | DataStore Preferences ([ADR-002](DECISIONS.md#adr-002)). |
| `LocationServiceMonitor` | Reports whether location services are enabled. | Required for the services-off state (GEN-04). |

Each is an interface in `domain` with its implementation in `data`, so the ViewModel
is testable with fakes.

#### `presentation` — Compose + ViewModel

`AttendanceViewModel` combines four inputs — permission status, the OS location toggle,
the device location `Flow`, and the office location `Flow` — into **one**
`StateFlow<AttendanceUiState>` ([ADR-006](DECISIONS.md#adr-006)). It consumes the domain's
`LocationReading` rather than re-deriving it, and delegates the office capture to
`SetOfficeLocationUseCase`, mapping its results to user-facing messages.

A provider fault does not end tracking: the stream retries on a capped backoff
(1 s → 2 s → 5 s) for as long as the screen is subscribed ([ADR-015](DECISIONS.md#adr-015)).

`AttendanceStatus` models the screen's conditions as a **sealed hierarchy**, not as
independent booleans, so contradictory states cannot be represented:

```
AttendanceStatus
├── PermissionRequired          (not yet granted / permanently denied)
├── PreciseLocationRequired     (approximate-only grant)
├── LocationServicesDisabled
├── AcquiringFix                (no usable fix yet)
├── RefreshingFix               (a fix, but older than the freshness bound)
├── ImprovingAccuracy           (a current fix, but wider than the radius, or unqualified)
├── LocationUnavailable(cause)  (a real inability)
├── OfficeNotSet                (fix available, no saved office)
└── Tracking(proximity)
```

`Tracking` is the only state in which the 50 m rule is meaningful, which is precisely
why the others are separate: it becomes structurally impossible to render "120m away"
while holding no location fix — or while holding one the app has refused to trust.

Two derived values are deliberately independent of each other:
`canMarkAttendance` is **live** (distance, now), and `isAttendanceConfirmed` is an
**event** that stands for the session once a mark happens
([ADR-016](DECISIONS.md#adr-016)). `canSetOfficeLocation` depends only on the permission
grant, the OS toggle, and whether a capture is already running — never on the live stream,
because the capture issues its own request.

`AttendanceScreen` (AND-03) is a single composable hosting both the setup card and the
attendance action (AND-04), rendering the p2 reference layout (AND-13 to AND-21).
It is stateless with respect to business logic — it reads state and emits events.

### Visual direction

Governed by [ADR-012](DECISIONS.md#adr-012): **reference-layout fidelity with premium
native Material 3 execution.** The reference screenshot's information architecture,
ordering, controls, and overall composition are preserved exactly; the execution
quality above that line is deliberately elevated — typographic hierarchy, spacing
rhythm, shape system, tonal surfaces, meaningful status colour, complete button
states, and subtle purposeful motion. Stable Material 3 / Compose only; no alpha or
preview design libraries. Native Android semantics, accessibility, and touch targets
take precedence over any stylistic influence.

This is a **presentation-layer standard with no behavioural authority.** It cannot
alter AND-08, and it does not license the availability caption to gate anything
([ADR-011](DECISIONS.md#adr-011)).

### Location surface

The map region is an original, dependency-free Compose surface — **not** the Google
Maps SDK ([ADR-003](DECISIONS.md#adr-003)). It keeps the reference panel's position
and approximate visual weight, and conveys office context, a pin/status indicator, the
50 m radius, and the user's position relative to it, alongside the coordinate pill.

Because it draws only project-owned vectors, it carries no API key, no network
dependency, and no third-party map tiles or Maps branding — so it renders in full on a
clean clone, which is what keeps DOC-07 and SUB-01 intact. It must not present pan or
zoom affordances it does not implement.

### Lifecycle and permissions

- Location collection is bound to the resumed lifecycle state; updates stop when the
  screen is not visible ([ADR-001](DECISIONS.md#adr-001) consequences).
- Permission flow covers: not requested, granted, denied once, permanently denied
  (with a settings route). Coarse-only grant is treated as insufficient for a 50 m
  decision and surfaced as such — a coarse fix cannot honestly resolve a 50 m
  boundary (AMB-14).

---

## Application 2 — Flutter camera and sync engine

**Not yet created.** Toolchain verified present: Flutter 3.41.2 stable, Dart 3.11.0.
Plugin choices are unverified — see [RESEARCH.md](RESEARCH.md) `ER-05` to `ER-08`.
Target platform is Android (AMB-12).

### Layers

Layered architecture as mandated by GEN-02/FLT-15:

```
presentation  Cubits/BLoCs + widgets
      │
      ▼
   domain     entities, repository interfaces, sync policy
      ▲
      │
    data      camera, filesystem, SQLite, mock API
```

#### `domain`

| Element | Responsibility |
| --- | --- |
| `CapturedImage` | id, batch id, file path, captured-at, upload state, attempt count, last failure. |
| `Batch` | Groups captures. Opens on the first capture after the previous batch is enqueued; closes on upload (AMB-10 — the assessment never defines this, so it is defined here explicitly). |
| `UploadState` | `queued`, `uploading`, `waitingForConnection`, `retrying`, `synced`, `failedTerminal`. |
| `RetryPolicy` | `(attemptCount, failureKind) -> next delay or give up`. **Pure — the retry logic (FLT-12) is testable with no plugins, no network, and no clock.** |
| `UploadApi` | Interface only. Implemented by the mock ([ADR-008](DECISIONS.md#adr-008)). |

`UploadState` deliberately mirrors the five per-item states in the p3 reference
screenshot (FLT-18), so the suggested UI and the mandated behaviour are the same model
rather than two parallel ones.

#### `data`

| Element | Responsibility |
| --- | --- |
| `CameraDataSource` | Wraps the camera controller: zoom range, zoom level, focus point, capture. Isolates plugin API churn from the Cubits. |
| `ImageFileStore` | Writes captures to the documents directory; deletes on terminal removal. |
| `UploadQueueDao` | SQLite CRUD over queue rows ([ADR-005](DECISIONS.md#adr-005)). |
| `MockUploadApi` | Deterministic, runtime-selectable success / generic failure / low-bandwidth timeout / no-connectivity, with simulated latency ([ADR-008](DECISIONS.md#adr-008)). |
| `ConnectivityMonitor` | Connectivity transitions. "Stable" means reachability-confirmed, not merely linked (AMB-15, `ER-07`). |

#### `presentation`

| Cubit / BLoC | Responsibility |
| --- | --- |
| `CameraCubit` | Preview lifecycle, zoom (pinch, slider, presets — FLT-03 to FLT-05), tap-to-focus with reticle (FLT-06, FLT-07), capture. |
| `BatchCubit` | Open batch contents, capture count badge, enqueue on upload (FLT-08). |
| `SyncCubit` | Observes the queue and connectivity; exposes per-item and aggregate progress for the Upload Manager (FLT-09, FLT-18). |

These are the classes DOC-04 requires the README to name.

Screens: `CameraPreviewScreen` (FLT-02, exact name mandated) and `UploadManagerScreen`.

### Background sync

The mandated behaviour (FLT-10 to FLT-12) is: fail without data loss, then recover
without the user.

```
capture ─▶ file written ─▶ row inserted (queued)
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
             connectivity present         no connectivity
                    │                           │
              attempt upload            waitingForConnection
              ┌─────┴─────┐                     │
              ▼           ▼                     │
           success     failure ────▶ retrying ◀─┘
              │        (row + file           (backoff,
              │         both kept)            attempt++)
              ▼
       row + file removed
```

Two properties are non-negotiable and become explicit tests at gate G6:

- **Nothing is deleted except on terminal success** (FLT-11). The verification must
  assert the row *and* the file survive a failure — asserting only the row would pass
  while silently losing images.
- **No user action appears anywhere in the recovery path** (FLT-12).

A background worker (`workmanager` or verified equivalent) runs the same drain
routine from its own entry point. That entry point cannot see the UI composition root
(flagged in [ADR-009](DECISIONS.md#adr-009)), so the drain routine must be
constructible standalone — this constrains the design and is noted here so it is not
discovered late.

---

## Testing strategy

Tests exist to prove the mandated rules, not to inflate a coverage number.

| Target | Level | Proves |
| --- | --- | --- |
| `AttendanceRule` at 0 / 49.9 / 50.0 / 50.1 / 120 m | Unit (JUnit) | AND-08 exactly, including the boundary |
| `AttendanceViewModel` state sequence with fakes | Unit | AND-12, GEN-04 |
| Permission / services-off / no-fix states | Unit | GEN-04 |
| `AttendanceScreen` enabled/disabled + distance text | Compose UI test | AND-05, AND-08, AND-09, AND-20 |
| `RetryPolicy` backoff and give-up | Unit (Dart) | FLT-12 |
| Queue survives failure — row **and** file | Unit (Dart) | FLT-11 |
| Cubit transitions | `bloc_test` | FLT-14 |
| Zoom mapping, focus-point normalisation | Unit (Dart) | FLT-03, FLT-06 |
| Five upload item states render | Widget test | FLT-18 |

Behaviour that genuinely needs hardware — pinch-to-zoom, tap-to-focus, real GPS
movement, airplane-mode recovery — is verified manually against the failure matrix at
gate G7 and captured as GIFs for DOC-08.
