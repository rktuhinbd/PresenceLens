# Flutter Architecture

This document details the architecture, state management, and deep subsystem mechanics for the Flutter Capture & Sync application (Task 2).

## 1. Dependency & Layer Direction

The application is structured in strict layers:
- **Presentation Layer**: Flutter widgets and Cubits/Blocs.
- **Application / Domain Layer**: Business logic, queue boundaries, policies, and use cases.
- **Data / Platform Layer**: Hardware access (camera), persistence (SQLite + file system), and network (Mock API).

Dependencies always point inwards.

## 2. Presentation Controllers

- **CameraCubit**: Manages the hardware camera lifecycle, lens discovery, and zoom/focus session readiness.
- **BatchCubit**: Accumulates a local session of captured images (batch identity) until the user explicitly commits them.
- **SyncBloc**: Orchestrates the background upload queue, providing live progress and tone updates (queued, awaitingLink, uploading, retrying, synced, failed) to the UI.

## 3. Camera Subsystem

The camera engine handles hardware boundaries safely:
- **Discovery**: Queries the platform for lenses and binds to the optimal rear-facing option.
- **Initialization**: Configures the resolution preset and frame rates.
- **Switching**: Safely coordinates transitions between lenses to avoid initialization race conditions.
- **Restoring**: Safely restores the specific selected lens upon app resume.
- **Lifecycle**: Listens strictly to app lifecycle changes. On `paused`/`detached`, the camera is released. On `resumed`, the camera is fully restored.
- **Permissions**: Explicitly handles Android denial escalation semantics (`permission A/B/C`). Repeated Android refusals may broaden the offered recovery actions, though canRetry depends on platform-restricted states.
- **Focus**: Tap-to-focus commands land precisely on requested coordinates.
- **Zoom**: Continuous zoom is bounded by platform and controller capabilities.
- **Preset-floor Selection**: Preset selection maps to the greatest preset value <= current zoom.
- **Unavailable/Failure Handling**: A double-shutter guard ensures exactly one platform capture per request. Failed hardware bindings degrade gracefully.

## 4. Capture Durability

- **Local Batch Semantics**: Images are held in memory (in the `BatchCubit`) during the active session.
- **Finish Batch Meaning**: Hitting "Finish batch" commits the session to the durable queue. This is a local-only transaction.
- **App-Files Persistence**: High-resolution captures are written to the application documents directory, isolating large blobs from relational metadata.

## 5. Data Model & SQLite

- **Entities**: Queue items track file paths, status, attempts, and lease timestamps.
- **Batch/Queue Identities**: Each batch has a unique UUID, and each captured item has its own distinct queue identity.
- **Invariants & Transactions**: The SQLite schema enforces invariants via atomic updates.
- **State Transitions**: Lifecycle respects retry states and connectivity boundaries rather than a simple linear progression.

## 6. Concurrency & Storage

Concurrency protections belong in the storage layer, not Dart memory:
- **Atomic Claims**: Queue extraction is performed via conditional UPDATEs, avoiding race conditions between isolates.
- **Lease Owner**: A worker isolate claims an item by stamping it with its own lease time.
- **Lease Expiry**: Leases expire after exactly 10 minutes.
- **Stale-Claim Recovery**: Abandoned items (e.g. process death) are reclaimed when their lease expires.

## 7. Sync Engine & Uploads

- **SyncBloc Responsibilities**: Observes queue size and provides the presentation layer with live counts and six distinct queue tones (queued, awaitingLink, uploading, retrying, synced, failed).
- **Connectivity**: Syncing respects connectivity states. Only un-leased and pending/failed items are selected for the candidate pool.
- **Candidate Selection**: The query explicitly filters for items with no active lease.
- **Worker Boundary & WorkManager**: Background uploads are delegated to a separate isolate spawned by Android `WorkManager`.
- **Retryable Failure**: Network timeouts trigger retries.
- **Permanent Failure**: Missing files or HTTP 400s trigger a permanent terminal state.
- **15s Exponential Backoff**: Failed uploads are retried with a **15-second base exponential backoff**.
- **Bounded Work / Continuation**: Workers process items in bounded slices to prevent OS termination. Unfinished slices trigger continuation work.

## 8. Reconciliation

- **Startup**: On app launch, a sweep verifies queue consistency.
- **Resume**: Bringing the app to foreground instantly reflects background upload progress.
- **Abandoned/Stale Work Recovery**: Startup and resume sweeps reclaim stale leases unconditionally.

## 9. Deterministic Mock API

- **Seam**: The network upload client is a strict interface.
- **Deterministic Failure/Success Semantics**: The injected mock API simulates timeouts and successes deterministically based on input, allowing repeatable reviewer validation.

## 10. Platform Behavior & Limitations

- **Camera Lens Identification**: The Android Camera2 API mapping to physical lenses is undocumented and OEM-specific. The application gracefully handles logical multi-lens devices.
- **Background-Work OEM Caveat**: Honor/MagicOS WorkManager constraints (`HN_USER_EXPERIENCE`) may silently block background isolates until manually enabled in OS settings.

## 11. Key ADRs
- The Camera/Data/Sync boundaries reflect explicit decisions designed to isolate Dart UI thread work from heavy IO operations.
