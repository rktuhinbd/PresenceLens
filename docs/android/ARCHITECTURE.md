# Android Architecture

This document details the architecture, state management, and domain rules for the Native Android Geo-Attendance application (Task 1).

## 1. Architectural Boundaries

The application is structured into a single module (`:app`) following a deliberate constraint to minimize build complexity for reviewers (`ADR-004`). Architecture is enforced logically via packages rather than Gradle module boundaries:

- **domain**: Pure Kotlin rules and models. Contains `AttendanceRule`, distance calculation, and business logic. It has zero Android dependencies.
- **data**: Device and persistence access. Contains the `FusedLocationProviderClient` implementation and `DataStore` repositories.
- **presentation**: Jetpack Compose UI and the `AttendanceViewModel`.

## 2. MVVM and UDF Flow

The application enforces strict unidirectional data flow (UDF) via the MVVM pattern. UI events flow downwards as function calls into the ViewModel, which holds the single source of truth. The ViewModel exposes a single immutable `StateFlow<AttendanceUiState>` back to the UI.

## 3. AttendanceViewModel Responsibility

`AttendanceViewModel` orchestrates domain and data components to derive the UI state. It holds the active location subscription and coordinates persistence reads/writes. The ViewModel maps raw data from repositories to presentation states, but it delegates all true business logic (e.g., is this location within 50 m?) to pure domain functions.

## 4. Location Data Source & FusedLocationProvider

Location tracking relies exclusively on `FusedLocationProviderClient` rather than OS geofencing (`ADR-001`). The tracker operates entirely in the foreground via a `callbackFlow` tied to the UI lifecycle (active when resumed, stopped when backgrounded).

## 5. Office Anchor Persistence / DataStore

The single office anchor coordinate pair (latitude/longitude) is persisted using Jetpack DataStore (Preferences). Room was explicitly rejected to avoid unnecessary abstraction overhead for a single record (`ADR-002`).

## 6. Office Anchor Cache Policy

The repository uses strict no-cache semantics. The anchor is read directly from the DataStore Flow to ensure the UI immediately reflects changes (e.g., if overwritten), guaranteeing durability over fast-but-stale memory caches.

## 7. Freshness Model

A location fix older than 10 seconds is considered stale (`ADR-014`). This exact threshold allows the app to tolerate up to five consecutive missed updates (at a 2-second interval) before displaying an "Acquiring location..." state, ensuring that stationary devices do not falsely report failures due to minor sensor sleep.

## 8. Accuracy & LocationQuality Model

Fixes are strictly gated by their error radius:
- **PRECISE (<= 25 m)**: Trusted for eligibility.
- **DEGRADED (> 25 m and <= 50 m)**: Treated as caution, not refusal. The user sees a warning banner, but eligibility is still evaluated.
- **UNUSABLE (> 50 m)**: Too coarse to make a 50m boundary decision. Mark attendance is blocked.
- **UNKNOWN**: Missing, invalid, or nonpositive accuracies. Treated as unusable.

## 9. Haversine & 50m Eligibility

The attendance rule is a strict 50 m radius evaluation. The pure-Kotlin `DistanceCalculator` uses the Haversine formula with an Earth radius of exactly **6,371,000 m**, producing deterministic, mathematically provable distances independent of platform APIs.

## 10. Provider Failure and Retry/Backoff

If the location provider encounters an error or drops the connection, the data layer automatically attempts to reconnect using a capped exponential backoff for the duration of the UI subscription.

## 11. Presentation State Derivation

The `AttendanceStatusPresenter` classifies the raw state into one of 14 mutually exclusive UI presentations (`AttendanceStatusKind`). These include `PERMISSION_REQUIRED`, `ACQUIRING_FIX`, `OUT_OF_RANGE`, `READY_TO_MARK`, etc.
Other UI elements are simply modifiers:
- `isCapturingOfficeLocation` modifies the state to show the setup flow.
- `DegradedAccuracyNotice` modifies the state to show a warning.

## 12. Attendance Receipt & Marked Precedence

An AttendanceMessage.AttendanceMarked is a transient, one-shot message. Once marked, the session receipt explicitly records the time and the distance verified *at the exact moment of the mark*. This `markedAttendance` receipt outlives the live location eligibility—so walking out of range does not erase the success state.

## 13. Dependency Wiring

Dependencies are wired manually via constructor injection. No Hilt, Dagger, or Koin is used (`ADR-009`), keeping the architecture clean and readable without annotation processing overhead.

## 14. Key Decisions & ADRs

- **Single Module**: Enforced via packages (`ADR-004`).
- **Visual Direction (`ADR-012`)**: The app adheres to reference-layout fidelity with premium native Material 3 execution. It uses purely custom Compose canvas for the location radar, avoiding any Google Maps SDK dependencies.
