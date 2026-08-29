import 'dart:async';

import '../../domain/ports/connectivity_port.dart';
import '../../domain/ports/sync_scheduler.dart';

/// Asks for a drain when the device regains a link, while the app is running.
///
/// This is the *third* and last legitimate use of connectivity in this app
/// (`SYNC_ENGINE.md` §3): it turns a likely-useful moment into an attempt
/// sooner. It is an accelerator and nothing more.
///
/// What it deliberately is **not**:
///
/// * not a gate — it never decides whether an upload may be attempted;
/// * not a poller — it reacts to a stream the platform pushes, and holds no
///   timer;
/// * not required for correctness — if it never fired, the WorkManager task
///   registered at enqueue would still drain the queue.
///
/// If the regained link turns out to be unusable, the attempt fails, the item
/// returns to the queue, and nothing is lost. That is the whole reason it is
/// safe to act on a signal that proves nothing.
class ConnectivityDrainTrigger {
  /// Creates the trigger.
  ConnectivityDrainTrigger({
    required ConnectivityPort connectivity,
    required SyncScheduler scheduler,
  }) : _connectivity = connectivity,
       _scheduler = scheduler;

  final ConnectivityPort _connectivity;
  final SyncScheduler _scheduler;

  StreamSubscription<bool>? _subscription;
  bool _hadLink = false;
  SchedulingOutcome? _lastSchedulingOutcome;

  /// Whether the trigger is listening.
  bool get isRunning => _subscription != null;

  /// What the platform said about the most recent request, or `null` if none
  /// has been made.
  ///
  /// Recorded so a scheduling failure here is observable rather than merely
  /// survivable. Nothing durable depends on it: a lost wake-up costs a delay,
  /// never a capture.
  SchedulingOutcome? get lastSchedulingOutcome => _lastSchedulingOutcome;

  /// Starts listening for a link becoming available.
  ///
  /// Only the transition into "has link" schedules anything. Reacting to every
  /// emission would re-register on ordinary Wi-Fi-to-mobile handovers, which is
  /// harmless but pointless noise.
  Future<void> start() async {
    if (_subscription != null) {
      return;
    }
    _hadLink = await _hasLinkQuietly();
    _subscription = _connectivity.linkChanges.listen(_onLinkChanged);
  }

  /// Stops listening.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onLinkChanged(bool hasLink) {
    final bool regained = hasLink && !_hadLink;
    _hadLink = hasLink;
    if (regained) {
      unawaited(_requestDrain());
    }
  }

  Future<void> _requestDrain() async {
    _lastSchedulingOutcome = await _scheduler.scheduleDrain();
  }

  Future<bool> _hasLinkQuietly() async {
    try {
      return await _connectivity.hasLink();
    } catch (_) {
      // An unavailable connectivity plugin must not stop the app starting.
      // Assuming "no link" only means the first transition is not missed.
      return false;
    }
  }
}
