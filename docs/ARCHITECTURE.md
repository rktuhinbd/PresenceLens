# PresenceLens Architecture



**What this document is for:** it provides a high-level, cross-application architectural summary of the two systems built for the PresenceLens assessment. Detailed implementation remains in the respective platform architecture files.



## 1. Repository & Application Split



The PresenceLens repository is structured as a monorepo containing two fully independent applications, sharing no code or runtime dependencies. This satisfies the assessment requirement to build a native Android geo-attendance system and a Flutter capture/sync engine within one repository structure.



- **Task 1: Native Android Geo-Attendance** (`android-attendance/`)

- **Task 2: Flutter Capture & Sync** (`flutter_camera_sync/`)



### Independent Build & Runtime Boundaries

Each application has its own build system (Gradle for Android, Flutter toolchain for Dart/Flutter) and distinct runtime properties. They do not share assets, databases, or UI components.



## 2. Shared Engineering Principles



While implemented independently, both applications adhere to the following shared engineering principles:



1. **State-Driven UI**: Both applications use a unidirectional data flow (UDF) approach where the UI is a pure reflection of an immutable state object emitted by a ViewModel (Android) or Cubit/Bloc (Flutter).

2. **Offline-First Resilience**: Both apps function smoothly under network and hardware constraints. They are designed to degrade gracefully (e.g., degraded location accuracy, offline sync queues).

3. **Strict Separation of Concerns**: Both codebases enforce a domain layer entirely free of UI or framework dependencies, making core business logic highly testable.

4. **Explicit Failure Paths**: Failures are modeled as structured types (e.g. sealed states/events) rather than relying on silent catches or generic exceptions.



## 3. Key Root-Level Architectural Decisions



Several key decisions shape the overall repository approach (from the migration contract):



- **Single Android Module (`ADR-004`)**: The native Android application is contained in a single `:app` module, enforcing architectural layering via packages (`domain`, `data`, `presentation`) rather than over-engineering with Gradle modules.

- **Both Applications in a Single Repository (`ADR-007`)**: A shared repository simplifies reviewer context and satisfies documentation constraints, with distinct build paths for each task.

- **Deterministic Mock API (`ADR-008`)**: The Flutter sync engine uses a deterministic mock API behind a real client seam, allowing exact reproduction of success, timeout, and failure scenarios during review.

- **Manual Dependency Wiring (`ADR-009`)**: Dependencies are wired manually via constructor injection in small composition roots, avoiding heavyweight DI frameworks (Hilt/get_it) that obscure the review path.

- **Release APK Signing Strategy (`ADR-010`)**: The release pipeline uses a local, project-specific keystore that is never committed, with graceful fallback to allow a clean clone to build unsigned binaries.



## 4. Documentation Map



For detailed, application-specific architectural decisions, refer to the platform documentation spaces:



- **Native Android:** [docs/android/ARCHITECTURE.md](android/ARCHITECTURE.md)

- **Flutter:** [docs/flutter/ARCHITECTURE.md](flutter/ARCHITECTURE.md)
