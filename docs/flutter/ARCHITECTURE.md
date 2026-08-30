# Flutter Task — Architecture

**What this document is for:** it fixes where each responsibility lives, so that
during implementation there is never a question of which layer a piece of logic
belongs in, and so a reviewer can predict the file they are looking for.

Covers `FLT-GEN-001`, `FLT-GEN-002`, `FLT-GEN-006`, `FLT-GEN-007`.

---

## 1. What this architecture is — and is not

It is a **pragmatic layered architecture with unidirectional data flow**.

It is deliberately **not** called Clean Architecture. There is no separate
entity/use-case/interface-adapter ring, and most repositories are consumed
directly by Cubits without a use-case in between. Calling it Clean when it is not
would be architecture theatre, and the same judgement was already applied on the
Android side ([root ADR-017](../DECISIONS.md#adr-017)).

```
┌───────────────────────────────────────────────┐
│ presentation                                  │
│   widgets  ──intent──▶  Cubits  ──state──▶    │
└───────────────┬───────────────────────────────┘
                │ depends on
                ▼
┌───────────────────────────────────────────────┐
│ domain                                        │
│   entities · policies (pure) · repository     │
│   and adapter INTERFACES                      │
└───────────────▲───────────────────────────────┘
                │ implements
┌───────────────┴───────────────────────────────┐
│ data                                          │
│   camera adapter · filesystem · SQLite ·      │
│   mock API · connectivity · scheduler         │
└───────────────────────────────────────────────┘
```

The single rule that makes this checkable: **`domain` imports nothing from
`presentation` or `data`, and no plugin package at all.** `FLT-GEN-007` makes that
an automated test rather than a convention, mirroring the Android
`DomainLayerPurityTest`.

Dependencies point at interfaces declared in `domain`; `data` supplies the
implementations; wiring happens once at composition roots (§7).

---

## 2. Directory layout

```
lib/
├── main.dart                       app entry, composition root (UI isolate)
├── sync_worker_entrypoint.dart     @pragma('vm:entry-point') worker isolate root
│
├── domain/
│   ├── entities/                   CaptureBatch, QueuedImage, UploadOutcome,
│   │                               BatchStatus, ImageStatus, FailureCategory,
│   │                               CameraDevice, CameraCapabilities/ZoomRange,
│   │                               CameraGeometry, CameraError, ZoomPreset,
│   │                               FocusRequest, CameraLifecycleSignal
│   ├── policies/                   pure decision functions (see §4)
│   ├── ports/                      CameraEngine/CameraSession, CaptureStore,
│   │                               UploadQueue, UploadApi, SyncScheduler,
│   │                               ConnectivityPort, Clock, IdGenerator
│   └── usecases/                   RecordCapture, FinishBatch, CaptureIntoBatch
│
├── data/
│   ├── camera/                     CameraXAdapter + CameraXSession over the
│   │                               `camera` plugin, error translation, the
│   │                               preview seam, device diagnostics.
│   │                               **The only place `package:camera` may be
│   │                               imported — asserted by test.**
│   ├── storage/                    FileSystemCaptureStore (injected root dir)
│   ├── database/                   AppDatabase, migrations, UploadQueueDao
│   ├── api/                        MockUploadApi behind UploadApi
│   ├── connectivity/               ConnectivityPlusAdapter
│   ├── identity/                   UuidV4Generator (ADR-F15)
│   ├── composition/                buildDataLayer / assembleDataLayer (§7)
│   └── sync/                       QueueProcessor, DrainOutcome,
│                                   WorkManagerSyncScheduler,
│                                   ConnectivityDrainTrigger
│
└── presentation/
    ├── theme/                      tokens, Material 3 schemes, camera palette
    ├── camera/                     CameraPreviewScreen + CameraCubit + widgets
    ├── batch/                      BatchCubit
    └── uploads/                    UploadManagerScreen + SyncCubit + widgets
```

`QueueProcessor` sits in `data/sync` rather than `domain` deliberately: it
*orchestrates* ports and performs I/O. The decisions it makes are delegated to the
pure policies in `domain/policies`, which is where the testable behaviour lives.

**`domain/usecases/` holds three things, and the bar for a fourth is unchanged.** §9
sets the bar — a use case is justified only when it orchestrates more than one
port — and `RecordCapture` is the operation that clears it: it spans `CaptureStore`
and `UploadQueue`, and the rule it enforces is what must happen when the *second*
of them fails after the first succeeded (file, then row; compensate the file if
the row cannot be written). That rule belongs somewhere pure and testable, not
inlined into whichever Cubit happens to call it.

`FinishBatch` joined it in the same gate, for the mirror-image reason: the durable
transaction must commit before anything is scheduled, and never the reverse.

`CaptureIntoBatch` joined at F3 and clears the same bar. It spans `UploadQueue`,
`IdGenerator` and `Clock` around a delegated `RecordCapture`, and the rule it holds
is the **batch boundary** — `FLT-BAT-004`'s "a batch opens on the first capture
after the previous batch was enqueued". Without it, that sentence would be executed
inside `CameraCubit`, and again inside `BatchCubit` at F4. It notably does *not*
reimplement the file-then-row ordering; it delegates, which is the point.

Three is where it stops unless a fourth clears the same bar.

`FileSystemCaptureStore` takes its root `Directory` by injection rather than
calling `path_provider` itself. Resolving the directory is the composition root's
job; taking the plugin as a dependency here would mean every test of durable
storage needed a Flutter binding, which is exactly the cost the layering exists to
avoid.

---

## 3. State management: the Bloc-vs-Cubit decisions

Both are required by the assessment as a family ("BLoC/Cubit"). Which one to use
is decided per feature by whether events carry meaning beyond "do this now".

| Owner | Choice | Rationale |
| --- | --- | --- |
| **`CameraCubit`** | **Cubit** | Every camera interaction is a direct imperative command — initialise, set zoom, focus here, capture, switch camera. There is no event stream worth replaying, no debouncing across event types, and no benefit to a sealed event hierarchy. A `Bloc` here would add an event class per method call for nothing. The hard part of the camera is *lifecycle and races* (`FLT-CAM-013`), which is solved by sequencing inside the Cubit, not by event modelling. |
| **`BatchCubit`** | **Cubit** | Two operations: append a capture, enqueue the batch. Modelling that as events would be pure ceremony. |
| **`SyncCubit`** | **Bloc** | This one genuinely earns it. It merges **three independent asynchronous sources** — the queue's own change stream, connectivity transitions, and app-lifecycle resume — and must react differently depending on which arrived. A sealed event type (`QueueChanged`, `ConnectivityChanged`, `AppResumed`, `RetryRequested`) makes that fan-in explicit and lets each be tested in isolation. `Bloc`'s transformers also allow connectivity chatter to be debounced without hand-rolled timers. |

The mixed choice is itself the argument: the codebase shows that the distinction
is understood rather than applied uniformly.

All state classes extend `Equatable` so `BlocBuilder` suppresses identical
rebuilds — which matters on a screen rendering a live camera preview.

---

## 4. What stays pure Dart

These are plain functions or small classes in `domain/policies` with no Flutter
import, no plugin import and no I/O. They hold every rule a reviewer would want to
see tested, and they are the reason the test suite can be fast and device-free.

| Policy | Decides | Requirement |
| --- | --- | --- |
| `ZoomPolicy` | Clamping a requested zoom to the reported `[min, max]`; the pinch anchored at gesture start; the zoom a camera opens at. | FLT-CAM-003, FLT-CAM-007 |
| `ZoomPresetPolicy` | Which preset stops to offer, given a reported zoom range. Never invents an optical multiplier, and stamps every preset with its provenance. | FLT-CAM-005, FLT-CAM-016 |
| `FocusPointMapper` | Preview-local tap pixels → `NormalizedPoint` in 0–1, through the *displayed image* rect under either `contain` or `cover`. | FLT-CAM-008 |
| `CameraSelectionPolicy` | Which cameras are offered (back-facing only), which one opens first, and whether the platform's lens identity can be trusted at all. | FLT-CAM-011 |
| `BatchPolicy` | When a batch opens and closes; refusing to enqueue an empty batch. | FLT-BAT-004, FLT-BAT-006 |
| `UploadStateMachine` | Which state transitions are legal. | FLT-SYNC-001 |
| `FailureClassifier` | Whether an outcome is retryable, permanent, or success. | FLT-SYNC-006, FLT-ERR-008 |
| `StaleClaimPolicy` | Whether an `uploading` lease has expired and may be reclaimed. | FLT-SYNC-009 |
| `RetentionPolicy` | Whether a file may be deleted after confirmed upload. | FLT-SYNC-016 (bonus) |

---

## 5. Component responsibilities

### Camera

| Component | Owns | Explicitly does not own |
| --- | --- | --- |
| `CameraEngine` (domain interface) | Enumerating cameras and opening a session on one. | Anything `CameraController`-shaped. |
| `CameraSession` (domain interface) | One live camera: its identity, its read-back capabilities, zoom, focus, exposure, capture, dispose. | Deciding *when* it should exist. |
| `CameraXAdapter` (data) | The `camera` plugin: `availableCameras()`, controller construction with `enableAudio: false`, `initialize`, capability read-back, plugin exceptions → classified domain failures. | Deciding *when* to dispose. |
| `CameraXSession` (data) | **Sole ownership of one `CameraController`.** Also exposes it, read-only, through `CameraPreviewSource`. | Anything about which camera should be open. |
| `CameraCubit` (presentation) | Sequencing: acquire, switch, lifecycle, the generation guard, the capture guard, the one shared zoom value and its coalescing pump, focus requests and their outcomes. | Widget layout; filesystem or database access; animation state. |
| `CameraPreviewScreen` (**F5**) | Rendering state; forwarding gestures with the `PreviewLayout` only it knows; **observing `didChangeAppLifecycleState`** and mapping it to a `CameraLifecycleSignal`. | Any decision. |

**Two interfaces rather than one**, because a camera app has two lifetimes that do
not coincide: the *list of cameras* is a property of the device, while a *session*
is acquired, replaced on a switch, and released on every background. Modelling both
as one long-lived object is what leads to a disposed controller still attached to a
preview.

`CameraCubit` takes `CaptureIntoBatch`, not a queue or a store. It is a sequencer;
it does not know what SQLite is.

Lifecycle ownership sits in the widget because that is where Flutter delivers the
signal (`FR-02`), but the *action* is a Cubit method, so it is testable.

### Capture persistence

`CaptureStore` (domain port) → `FileSystemCaptureStore` (data). It copies the
plugin's temporary `XFile` into an app-owned directory from `path_provider` and
returns a durable path. **This is the boundary at which a capture becomes real**
(`FLT-CAM-015`): the queue row is written only after the file is durably in place,
never before, so no row can ever reference a file that does not exist
(`FLT-ERR-005`).

### Queue and sync

| Component | Responsibility |
| --- | --- |
| `UploadQueue` / `UploadQueueDao` | Transactional SQLite access. Owns `claim`, the atomic conditional update that makes concurrency safe. |
| `UploadApi` / `MockUploadApi` | The network seam. Deterministic Success/Failed (`FLT-SYNC-005`). |
| `QueueProcessor` | The drain loop: claim → attempt → classify → transition. Runs identically in both isolates. |
| `SyncScheduler` / `WorkManagerSyncScheduler` | Registering the one-off drain task with its constraints and backoff. |
| `SyncCubit` | Presenting queue state; reacting to connectivity and resume. |

`QueueProcessor` being isolate-agnostic is the key simplification: there is one
implementation of "drain the queue", used by the worker and by the foreground.

---

## 6. Isolates

Two Dart isolates run this app's code, and they share **no memory**:

```
UI isolate                          Worker isolate (WorkManager)
──────────                          ────────────────────────────
main()                              sync_worker_entrypoint.dart
  └ composition root                  └ @pragma('vm:entry-point')
      Cubits, screens                     Workmanager().executeTask(...)
      QueueProcessor ──┐                      └ its OWN composition root
                       │                          QueueProcessor ──┐
                       ▼                                           ▼
                 ┌─────────────────────────────────────────────────────┐
                 │  SQLite file  +  captured-image directory           │
                 │  (the ONLY shared state)                            │
                 └─────────────────────────────────────────────────────┘
```

Answering the question directly — *how does the worker isolate bootstrap its
dependencies without UI objects?* It does not receive them. It **rebuilds** them.
`sync_worker_entrypoint.dart` calls
`WidgetsFlutterBinding.ensureInitialized()`, opens its own `AppDatabase`, resolves
its own directory via `path_provider`, constructs its own `MockUploadApi`, and
assembles a `QueueProcessor`. Nothing is passed across; only the database path and
the storage directory are common, and both are derived, not transferred.

The corollary is the constraint that shapes everything else: because the two
isolates hold **separate database connections**, no Dart-level lock can coordinate
them (`FR-08`). Coordination must happen in SQLite.

---

## 7. Composition roots

Manual constructor wiring, no DI framework — consistent with
[root ADR-009](../DECISIONS.md#adr-009). At this size a container would obscure
the graph rather than clarify it, and there are exactly two roots to keep in step:

1. `main.dart` — builds repositories and adapters, provides Cubits via
   `MultiBlocProvider`.
2. `sync_worker_entrypoint.dart` — builds the same data layer, no presentation.

To stop those drifting apart, both call one shared factory,
`buildDataLayer({required bool forBackground})`. That single function is the only
place the object graph is described.

`buildDataLayer` does two things: it resolves the platform paths (`path_provider`,
`getDatabasesPath`) and opens the database, then hands off to
**`assembleDataLayer`**, which is the pure wiring. The split is not decoration —
it is what lets the `DATA` suite drive the *real* graph (real DAO, real processor,
real store, real SQLite) against a temporary directory on the host, instead of a
test that either needs a device or asserts against a graph nobody ships.

`forBackground` is load-bearing in exactly one place: the worker gets a
`BackgroundSyncScheduler`, which **suppresses** a request for entry work and
**forwards** a request for a continuation.

That asymmetry is the whole of the worker's relationship with the scheduler. Its
lever for "come back and try again" is its **return value** — returning retry
asks WorkManager to reschedule under the configured backoff — so a worker that
also registered entry work from inside itself would be a second scheduler
competing with the OS's own (`RS-04`). But a worker that finished a healthy slice
with more to do is saying something different, and WorkManager has a mechanism
for exactly that: an appended successor. Splitting the two into separate methods,
and letting the type refuse one of them, means a future caller inside the worker
cannot reintroduce the mistake by accident (`ADR-F19`).

---

## 8. Platform differences kept rather than abstracted

Falsely unifying these would hide real behaviour.

| Difference | Reality | How it is surfaced |
| --- | --- | --- |
| Lens identity | iOS populates `CameraLensType`; Android always reports `unknown` (`FR-04`). | `CameraPort` exposes an optional lens type. Presets degrade to range-derived labels when it is absent, rather than pretending. |
| Background execution | Android WorkManager runs constrained work reasonably reliably; iOS `BGTaskScheduler` is opportunistic and may not run for long periods. | The scheduler interface is shared; README states the iOS caveat plainly. No iOS behaviour is claimed as verified. |
| Retry timing | Android clamps backoff to a **10-second** minimum and a 5-hour maximum (`FR-06`); the app configures a 15-second initial delay, which is a choice rather than the floor. | The app sets policy and lets the OS own timing; it does not simulate a uniform cross-platform schedule. |

---

## 9. What was deliberately not built

| Not built | Why |
| --- | --- |
| A use case per repository method | They would forward a single call. Use cases appear only where they orchestrate more than one port. |
| A DI container | Two composition roots, one shared factory. |
| A repository over the camera | The camera is a device, not a data source. `CameraEngine` is an adapter interface, and naming it a repository would misdescribe it. |
| A pure-Dart preview abstraction | `CameraPreview` needs a real `CameraController`; an interface whose only implementation returns one anyway is theatre that makes the integration worse. The seam is one read-only getter, confined by an automated import test to `lib/data/camera/` (`ADR-F23`). |
| A wrapper per plugin method | The plugin exposes flash, video, image streaming, exposure-offset stepping and orientation locking. None is in scope, and mirroring them would make the port harder to fake than the thing it wraps. |
| `permission_handler` | Reconsidered at F3 when Android turned out not to report permanent denial, and rejected again: a second permission library for one permission, whose signal is only meaningful immediately after a request (`ADR-F22`). |
| A custom navigation stack | Two routes. `Navigator` suffices. |
| An app-side retry timer | WorkManager already provides backoff (`FR-06`); a second scheduler would fight it. |
| A real HTTP client | No API exists (p3 Note). The seam is real so a client can be dropped in; the transport is not fabricated. |
