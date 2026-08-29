import 'package:workmanager/workmanager.dart';

import '../../domain/ports/sync_scheduler.dart';

/// The exact registration call [WorkManagerSyncScheduler] makes.
///
/// Injected so the scheduling *strategy* — unique name, conflict policy,
/// constraint, backoff — can be asserted by a host test. Calling the real
/// plugin would need a device, and "we registered some work" is not the part
/// worth verifying: the parameters are.
typedef RegisterOneOffTask =
    Future<void> Function(
      String uniqueName,
      String taskName, {
      Constraints? constraints,
      ExistingWorkPolicy? existingWorkPolicy,
      BackoffPolicy? backoffPolicy,
      Duration? backoffPolicyDelay,
    });

/// Registers the queue drain with Android WorkManager.
///
/// The app sets policy; the OS owns timing. That division is deliberate:
/// WorkManager already persists its queue across process death and reboot and
/// already provides exponential backoff, so an app-side retry timer would only
/// fight it (`FLT-SYNC-007`, `RS-04`).
///
/// Both operations enqueue onto **one serial unique chain** with
/// `ExistingWorkPolicy.append`. They stay separate methods because the
/// background isolate is allowed to do only one of them (see
/// [BackgroundSyncScheduler]) and because they mean different things to a
/// reader — not because they register differently.
///
/// * [scheduleDrain] — "durable uploadable work now exists";
/// * [scheduleContinuation] — "that slice finished healthily and there is more".
class WorkManagerSyncScheduler implements SyncScheduler {
  /// Creates the scheduler.
  WorkManagerSyncScheduler({RegisterOneOffTask? registerOneOffTask})
    : _register = registerOneOffTask ?? _registerWithPlugin;

  /// The single unique name every registration uses, entry and continuation
  /// alike.
  ///
  /// One name means one **serial chain**: WorkManager runs unique work for a
  /// given name one node at a time, so however many requests arrive, no two
  /// drains are started in parallel by the scheduler (`RS-03`). Ordering is
  /// preserved, and a request made while a drain is running becomes that
  /// drain's successor rather than a competitor.
  ///
  /// Two drains running at once would still be *safe* — the atomic claim is the
  /// correctness boundary, not the scheduler — but there is no reason to ask
  /// for them.
  static const String uniqueName = 'presencelens.sync.drain';

  /// The task name handed to the background handler.
  static const String taskName = 'drainUploadQueue';

  /// The **initial** backoff delay configured on every request.
  ///
  /// Android's floor is `WorkRequest.MIN_BACKOFF_MILLIS`, which is **10
  /// seconds** (verified in `androidx.work:work-runtime:2.11.2`, the version
  /// this project resolves; the maximum is 5 hours and the platform default is
  /// 30 seconds). Fifteen seconds is therefore a valid configured value that
  /// sits just above the floor — it is *not* the floor itself, and describing
  /// it as one would misstate the platform.
  static const Duration backoffDelay = Duration(seconds: 15);

  final RegisterOneOffTask _register;

  /// The error from the most recent failed registration, or `null`.
  ///
  /// A deliberately tiny diagnostic seam — not a logging framework. It exists
  /// so a failure is *observable* rather than merely survivable.
  Object? get lastSchedulingError => _lastSchedulingError;
  Object? _lastSchedulingError;

  /// The conflict policy used by **both** operations.
  ///
  /// `append` maps to Android's `APPEND_OR_REPLACE` — verified in
  /// `workmanager_android` 0.10.8's own `WorkManagerUtils.toAndroidWorkPolicy`,
  /// not taken from the Dart doc comment, which describes plain `APPEND`
  /// (`RESEARCH.md` `FR-06a`).
  ///
  /// **Why not `keep`, which this scheduler used for entry work until the final
  /// F1 audit.** `KEEP` discards a request while *uncompleted* work exists under
  /// the same name — and a currently **running** worker is uncompleted. That
  /// opens a liveness race with no data loss and no visible symptom:
  ///
  /// 1. a drain worker takes its final outstanding-count reading;
  /// 2. the foreground commits a finished batch, moving images to `PENDING`;
  /// 3. the foreground asks for a drain; `KEEP` sees the running worker and
  ///    discards it;
  /// 4. the worker returns success, because it never saw those rows;
  /// 5. nothing is scheduled, and durable `PENDING` work waits for an unrelated
  ///    trigger.
  ///
  /// `APPEND_OR_REPLACE` cannot lose that request: with no chain it starts one,
  /// and with a running worker it enqueues a successor. It also starts a fresh
  /// chain rather than inheriting a cancelled or failed predecessor.
  ///
  /// The cost is the opposite failure — redundant requests accumulate as extra
  /// nodes instead of collapsing. That is deliberately the cheaper mistake: a
  /// redundant node finds an empty queue and returns `idle` immediately, while
  /// a discarded request is a queue that silently stops draining. It is kept
  /// small by asking only when durable *uploadable* work appears — finishing a
  /// batch, regaining a link — never on every shutter press (`ADR-F21`).
  static const ExistingWorkPolicy conflictPolicy = ExistingWorkPolicy.append;

  @override
  Future<SchedulingOutcome> scheduleDrain() => _enqueue(conflictPolicy);

  @override
  Future<SchedulingOutcome> scheduleContinuation() => _enqueue(conflictPolicy);

  Future<SchedulingOutcome> _enqueue(ExistingWorkPolicy policy) async {
    try {
      await _register(
        uniqueName,
        taskName,
        // Asks the OS not to wake the worker with no link at all. It saves
        // wake-ups; it proves nothing about reachability, and no upload
        // decision is taken from it (`ADR-F05`).
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: policy,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: backoffDelay,
      );
      _lastSchedulingError = null;
      return SchedulingOutcome.requested;
    } catch (error) {
      // Scheduling is an accelerator, not the queue. Work that is already
      // durably persisted must survive a plugin fault here, and a foreground
      // caller must not be handed an exception that makes a successful capture
      // look like a failed one. The outcome is returned rather than thrown so
      // the caller can still *know*, and ask again later.
      _lastSchedulingError = error;
      return SchedulingOutcome.unavailable;
    }
  }

  static Future<void> _registerWithPlugin(
    String uniqueName,
    String taskName, {
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
  }) {
    return Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      constraints: constraints,
      existingWorkPolicy: existingWorkPolicy,
      backoffPolicy: backoffPolicy,
      backoffPolicyDelay: backoffPolicyDelay,
    );
  }
}

/// The scheduler the **background isolate** gets.
///
/// It forwards a continuation and suppresses everything else. That asymmetry is
/// the point:
///
/// * a worker asking for *entry* work would be a second scheduler competing
///   with WorkManager's own backoff (`RS-04`) — suppressed;
/// * a worker reporting "this slice finished healthily and there is more" is
///   the platform's own continuation mechanism — forwarded.
///
/// Enforcing it here rather than by convention means a future caller inside the
/// worker cannot reintroduce the mistake by accident.
class BackgroundSyncScheduler implements SyncScheduler {
  /// Wraps the scheduler that talks to the platform.
  const BackgroundSyncScheduler(SyncScheduler delegate) : _delegate = delegate;

  final SyncScheduler _delegate;

  @override
  Future<SchedulingOutcome> scheduleDrain() async =>
      SchedulingOutcome.suppressed;

  @override
  Future<SchedulingOutcome> scheduleContinuation() =>
      _delegate.scheduleContinuation();
}
