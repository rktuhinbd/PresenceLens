# PresenceLens Attendance

PresenceLens Attendance is the Native Android application developed for Task 1 of the Intelligent Machines technical assessment. It demonstrates a robust, location-aware mobile client that reliably decides employee attendance eligibility at a designated office boundary, utilizing offline-first principles, strong domain decoupling, and modern Android architecture.

## What it demonstrates

- **Location Freshness & Precision Validation**: Verifies GPS coordinates in real-time, rejecting stale or imprecise location data.
- **Office Anchor Handling**: Computes Haversine distance reliably to ensure check-ins only happen within 50 meters of the office.
- **Provider Failure Recovery**: Degrades gracefully or prompts user intervention when location services fail or permissions are denied.
- **Attendance Session Correctness**: Clear visual feedback for every boundary condition. The office anchor is persisted with DataStore; a recorded mark is held in session state and deliberately survives a later stale fix or the user walking away, so the confirmation states what was actually verified at the moment the rule was applied.

## Technology stack

- Kotlin
- Jetpack Compose
- Kotlin Coroutines / Flow / StateFlow
- Android ViewModel + lifecycle
- Google Play Services Fused Location Provider
- DataStore Preferences
- Gradle Kotlin DSL
- JUnit, Android Lint

## Architecture

- **Layered MVVM**: Clear separation between UI, presentation logic, and data.
- **Unidirectional Data Flow**: State flows down, events flow up, ensuring a predictable UI state.
- **Kotlin Flow / StateFlow**: Reactive streams driving UI state synchronously and safely.
- **Android-free Domain Layer**: Business logic entirely isolated from Android framework dependencies, ensuring maximum testability.
- **Manual Dependency Composition**: Lightweight, compile-time safe dependency injection.
- **Selective Use Cases**: Focused, single-responsibility use cases encapsulating complex business logic.

## Key correctness behaviors

- Validates that check-ins strictly occur within a 50-meter radius of the office anchor.
- Handles edge cases such as missing permissions and disabled GPS.
- Recovers safely from lifecycle interruptions and persistence faults.
- Office anchor dynamically configurable and persistently saved across sessions.

## The 50 m rule and location quality

Eligibility is decided by a pure domain rule: the Haversine distance between the saved
office anchor and the current fix must be within 50 m.

A GPS fix is only allowed to answer that question when it is good enough to do so:

- **Accuracy.** A fix within half the radius is precise; up to the radius it is degraded
  and usable with a caution; beyond the radius it is unusable and eligibility fails
  closed rather than guessing.
- **Freshness.** A retained fix is bounded by age, so a stale reading is never silently
  reused as if it were current.
- **Anchor quality.** Capturing the office refuses a fix too coarse to be trusted as a
  permanent anchor — a bad anchor would poison every later decision.
- **Provider faults.** Location failures retry on a capped backoff, and permission or
  service problems are surfaced as actionable UI states rather than silent failure.

No mock-location or spoofing detection is implemented, and none is claimed.

## Screenshot

<img src="../docs/assets/android/attendance-ready.png" alt="Attendance ready" width="250">

Office anchor saved, live distance to the office, and eligibility inside the 50 m radius.
Captured on a physical HONOR DNP-NX9 against a live GPS fix.

## Project structure

- `app/src/main/java/.../domain/`: Core business logic, rules, and models.
- `app/src/main/java/.../data/`: Data sources, repositories, and persistence.
- `app/src/main/java/.../presentation/`: ViewModels, StateFlows, and UI components.
- `app/src/main/java/.../ui/`: Jetpack Compose screens and themes.

## State management

The primary State is managed by the `AttendanceViewModel`, which projects a unified `AttendanceUiState`. This immutable state encapsulates the user's distance to the office, location status (e.g., fetching, ready, failed), and permission states. UI events are dispatched as singular intents, mutating the state through Kotlin `StateFlow` and ensuring that the UI always correctly reflects the underlying business reality.

## Build and run

Ensure you have Android Studio and the Android SDK installed. To build and run the application on a connected device or emulator:

```bash
# Debug build and install on a connected device or emulator
./gradlew installDebug
```

To install the published release build instead, download the APK from the
[v1.0.0 release](https://github.com/rktuhinbd/PresenceLens/releases/tag/v1.0.0) and run
`adb install <downloaded-apk>`.

## Tests and verification

The application behavior is verified by a suite of comprehensive automated tests:

- **158 Tests Passed**: Fully automated suite covering domain logic, ViewModels, and data repositories.
- **Lint & Format Clean**: 0 lint errors, built under strict analysis rules.

To run the tests yourself:

```bash
./gradlew lint testDebugUnitTest
```

## Device and emulator QA

Behaviour was validated by the automated suite plus an emulator acceptance walkthrough,
where office-set, in-range, out-of-range, permission-denied, and location-disabled states
can be driven deterministically with simulated coordinates. The screenshot above was
additionally captured on physical HONOR DNP-NX9 hardware against a live GPS fix.

## Release APK

The release-mode Android APK can be downloaded here:

https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Attendance-v1.0.0.apk

## AI usage

Generative AI was used purposefully to assist with specific architectural patterns, edge-case analysis, and testing strategies. See the root [AI_USAGE.md](../docs/AI_USAGE.md) for full transparency, including exact prompts and validation methods.

## Scope/platform notes

This is an assessment artifact focused on architectural correctness, location resilience, and offline-first durability. Decorative features have been deliberately excluded in favor of robust engineering.
