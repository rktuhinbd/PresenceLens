# PresenceLens Architecture

**What this document is for:** it provides a high-level, cross-application architectural summary of the two systems built for the PresenceLens assessment.

## Architecture at a glance

### Task 1: Native Android Geo-Attendance
- **Language / UI:** Kotlin / Jetpack Compose
- **State Management:** `StateFlow`
- **Pattern:** Layered MVVM + Unidirectional Data Flow (UDF)
- **Deep Dive:** [android/ARCHITECTURE.md](android/ARCHITECTURE.md)

### Task 2: Flutter Capture & Sync
- **Language / UI:** Dart / Flutter
- **State Management:** BLoC / Cubit
- **Pattern:** `presentation` → `application/domain` ← `data/platform`
- **Deep Dive:** [flutter/ARCHITECTURE.md](flutter/ARCHITECTURE.md)

## Shared engineering principles

1. **Strictly layered boundaries:** Both applications enforce a domain layer entirely free of UI or framework dependencies (verified by `DomainLayerPurityTest` in both codebases).
2. **Explicit failure paths:** Both applications model failures as structured types (e.g. sealed states/events) rather than relying on silent catches or generic exceptions.
3. **No mock-location spoof detection:** Out of scope for this assessment.
4. **Offline-first resilience:** Both apps function smoothly under network and hardware constraints.

## State management

### Native
- **`AttendanceViewModel`**: Uses `StateFlow` to combine location updates, office anchors, and permission statuses into a single, unified `AttendanceUiState` sealed hierarchy.

### Flutter
- **`CameraCubit`**: Manages the hardware camera lifecycle and session readiness.
- **`BatchCubit`**: Accumulates captured images until the user triggers a finish.
- **`SyncBloc`**: Handles background resilient upload queues.

## Persistence

### Native
- **`DataStore`**: Persists only the single office anchor coordinate. The attendance mark itself is transient session state.

### Flutter
- **App-owned files + SQLite**: High-resolution image files are stored in the app's isolated document directory, while their metadata and upload status are tracked in a robust local SQLite queue.

## Failure handling

Both applications are built to gracefully handle denied permissions, disabled device services, missing fixes, or network drops, surfacing exact reasons to the user through specific UI states rather than generic errors.

## Verification

The systems were rigorously verified through automated test suites covering pure domain rules, state machines, and integrations.

- **Native tests:** 158
- **Flutter tests:** 521
- **Combined total:** 679

## Documentation map

For detailed, application-specific architectural decisions, refer to the local documentation spaces:
- **Native Android:** [docs/android/](android/)
- **Flutter:** [docs/flutter/](flutter/)
