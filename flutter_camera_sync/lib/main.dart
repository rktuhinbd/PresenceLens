/// Application entry point for PresenceLens Capture.
///
/// Task 2 of the Intelligent Machines Senior App Developer assessment: a custom
/// camera screen and a resilient upload queue.
///
/// This file does three things and nothing else: register the background worker
/// for this process, assemble the UI isolate's object graph, and start the app.
/// Everything about *what* is assembled lives in `buildDataLayer`, which the
/// worker isolate calls too — the wiring is described once (`ARCHITECTURE.md`
/// §6).
library;

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'data/composition/data_layer.dart';
import 'sync_worker_entrypoint.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrapBackgroundSync();
  runApp(
    StartupBootstrapApp(
      bootstrap: () async {
        final DataLayer layer = await buildDataLayer(forBackground: false);
        return PresenceLensCaptureApp(dataLayer: layer);
      },
    ),
  );
}

/// Registers the WorkManager callback dispatcher for this process.
///
/// Registration only — nothing is scheduled here. A drain is requested when
/// there is something to drain (on finishing a batch, at startup and on resume
/// if durable work is waiting, on regaining a link); scheduling one
/// unconditionally at launch would ask the OS to wake a worker for an empty
/// queue.
///
/// A failure is swallowed on purpose. If the plugin cannot initialise, the app
/// must still start and must still be able to capture: images are made durable
/// by the filesystem and the database, not by the scheduler, and the foreground
/// drain still works.
Future<void> _bootstrapBackgroundSync() async {
  try {
    await Workmanager().initialize(syncCallbackDispatcher);
  } catch (_) {
    // Left to the next launch. Captures already queued are unaffected.
  }
}
