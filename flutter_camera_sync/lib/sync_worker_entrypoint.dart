/// The background isolate's root.
///
/// WorkManager does not hand the worker a running app. It starts a **second
/// Flutter isolate** with its own plugin channels and no access to anything the
/// UI isolate holds — no Cubit, no `BuildContext`, no widget tree, no camera
/// controller, no service locator. Nothing is passed across.
///
/// So the worker does not receive its dependencies. It **rebuilds** them, from
/// the same `buildDataLayer` factory the UI uses, and reaches the same SQLite
/// file and the same captures directory by *deriving* both paths rather than by
/// being told them (`ARCHITECTURE.md` §6, `ADR-F04`).
library;

import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import 'data/composition/data_layer.dart';
import 'data/sync/drain_outcome.dart';
import 'data/sync/work_manager_sync_scheduler.dart';
import 'domain/ports/sync_scheduler.dart';

/// The WorkManager callback dispatcher.
///
/// The `vm:entry-point` annotation is not decoration: without it, tree shaking
/// removes this function from a release build and background sync silently
/// stops working in exactly the build that ships (`RESEARCH.md` `FR-07`).
@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((String taskName, Map<String, dynamic>? _) {
    return runDrainTask(taskName);
  });
}

/// Builds the data layer this isolate will use.
typedef DataLayerFactory = Future<DataLayer> Function();

/// Runs one drain pass and maps it onto WorkManager's result vocabulary.
///
/// Returning `true` completes the task; returning `false` asks WorkManager to
/// reschedule it under the configured exponential backoff. The mapping is
/// deliberately thin, because the OS owns timing and the app owns durability:
///
/// | Disposition | Returns | Effect |
/// | --- | --- | --- |
/// | `idle` — nothing was eligible | `true` | Done. |
/// | `drained` — nothing outstanding | `true` | Done. |
/// | `continuationRequired` — progress made, more to do | `true`, after enqueuing a **successor** | Runs again promptly, with **no backoff**. |
/// | `retryLater` — no progress was possible | `false` | Rescheduled under exponential backoff. |
/// | The pass itself threw | `false` | Come back later; the queue is untouched. |
///
/// **Why a continuation rather than a retry.** The bound on a drain pass is a
/// property of the *worker's execution window*, not of the queue's health. A
/// hundred perfectly uploadable photos take four passes, and reporting each of
/// the first three as a failure would make WorkManager back off further every
/// time — so the more successfully the queue drained, the slower it would get.
/// Progress and failure are now different answers (`ADR-F19`).
///
/// If the continuation cannot be enqueued, the worker falls back to `false`.
/// That is deliberately the *safe* direction: a backlog delayed by backoff is
/// recoverable, a backlog nobody is coming back for is not.
///
/// Separate from [syncCallbackDispatcher] so it can be exercised by a host test
/// against a real data layer, which the plugin callback itself cannot be.
/// [buildLayer] exists for that test alone; the app never passes it.
Future<bool> runDrainTask(
  String taskName, {
  DataLayerFactory buildLayer = buildBackgroundDataLayer,
}) async {
  if (taskName != WorkManagerSyncScheduler.taskName) {
    // An unrecognised task is not a failure to retry: rescheduling it would
    // just bring it back.
    return true;
  }

  DataLayer? layer;
  try {
    layer = await buildLayer();
    final DrainOutcome outcome = await layer.queueProcessor.drain();

    switch (outcome.disposition) {
      case DrainDisposition.idle:
      case DrainDisposition.drained:
        return true;

      case DrainDisposition.continuationRequired:
        // Enqueued from inside the running worker, so it becomes a successor of
        // this slice rather than a competitor to it.
        final SchedulingOutcome scheduled = await layer.scheduler
            .scheduleContinuation();
        return scheduled == SchedulingOutcome.requested;

      case DrainDisposition.retryLater:
        return false;
    }
  } catch (_) {
    // Nothing was lost: every state change the pass made was committed as it
    // went, and anything it did not reach is still queued. Ask to come back.
    return false;
  } finally {
    // The worker's connection dies with its engine, so leaving it open is a
    // file handle held for nothing.
    await layer?.close();
  }
}

/// Rebuilds the data layer inside the background isolate.
///
/// Plugins used from a background isolate have to be registered in it; the
/// binding itself is established by `Workmanager().executeTask`. Registration
/// lives here, beside the construction that needs it, rather than at the top of
/// [runDrainTask] where a host test could not avoid it.
Future<DataLayer> buildBackgroundDataLayer() async {
  DartPluginRegistrant.ensureInitialized();
  return buildDataLayer(forBackground: true);
}
