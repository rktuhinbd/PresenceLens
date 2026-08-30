# PresenceLens Attendance

PresenceLens Attendance is the Native Android application developed for Task 1 of the Intelligent Machines technical assessment. It demonstrates a robust, location-aware mobile client that securely captures employee attendance at a designated office boundary, utilizing offline-first principles, strong domain decoupling, and modern Android architecture.

## What it demonstrates

- **Location Freshness & Precision Validation**: Verifies GPS coordinates in real-time, rejecting stale or imprecise location data.
- **Office Anchor Handling**: Computes Haversine distance reliably to ensure check-ins only happen within 50 meters of the office.
- **Provider Failure Recovery**: Degrades gracefully or prompts user intervention when location services fail or permissions are denied.
- **Attendance Session Correctness**: Ensures transactional check-ins and provides robust visual feedback for office boundary conditions.

## Architecture

- **Layered MVVM**: Clear separation between UI, presentation logic, and data.
- **Unidirectional Data Flow**: State flows down, events flow up, ensuring a predictable UI state.
- **Kotlin Flow / StateFlow**: Reactive streams driving UI state synchronously and safely.
- **Android-free Domain Layer**: Business logic entirely isolated from Android framework dependencies, ensuring maximum testability.
- **Manual Dependency Composition**: Lightweight, compile-time safe dependency injection.
- **Selective Use Cases**: Focused, single-responsibility use cases encapsulating complex business logic.

## Key correctness behaviors

- Validates that check-ins strictly occur within a 50-meter radius of the office anchor.
- Handles edge cases such as missing permissions, disabled GPS, and mocked location spoofing attempts.
- Recovers safely from lifecycle interruptions and persistence faults.
- Office anchor dynamically configurable and persistently saved across sessions.

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
# Debug build and install
./gradlew installDebug

# To manually install the release APK
adb install release-artifacts/PresenceLens-Attendance-v1.0.0.apk
```

## Tests and verification

The application behavior is verified by a suite of comprehensive automated tests:

- **158 Tests Passed**: Fully automated suite covering domain logic, ViewModels, and data repositories.
- **Lint & Format Clean**: 0 lint errors, built under strict analysis rules.

To run the tests yourself:

```bash
./gradlew lint testDebugUnitTest
```

## Release APK

The signed release APK can be downloaded here:

https://github.com/rktuhinbd/PresenceLens/releases/download/v1.0.0/PresenceLens-Attendance-v1.0.0.apk

## AI usage

Generative AI was used purposefully to assist with specific architectural patterns, edge-case analysis, and testing strategies. See the root [AI_USAGE.md](../docs/AI_USAGE.md) for full transparency, including exact prompts and validation methods.

## Scope/platform notes

This is an assessment artifact focused on architectural correctness, location resilience, and offline-first durability. Decorative features have been deliberately excluded in favor of robust engineering.
