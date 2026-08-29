/// What happened when scheduling was requested.
///
/// Scheduling never throws and never rolls anything back, but it must not be
/// *silent* either: a caller — or a test — has to be able to tell that the
/// platform did not accept the request, so the next opportunity can ask again.
enum SchedulingOutcome {
  /// The platform accepted the request.
  requested,

  /// Deliberately not forwarded. The background isolate suppresses requests for
  /// *entry* work, because its scheduling lever is its return value.
  suppressed,

  /// The platform refused it, or the plugin was unavailable.
  ///
  /// **Nothing durable is affected.** Queued rows and captured files are
  /// untouched; only the wake-up was lost, and the next capture, resume or
  /// connectivity change asks again.
  unavailable,
}

/// Asks the platform to run a queue drain.
///
/// Deliberately narrow: application code says *that* a drain is wanted and
/// never *when* it happens. Timing belongs to the OS, which already provides
/// constrained scheduling and exponential backoff; a second scheduler inside
/// the app would fight it (`FLT-SYNC-007`, `RS-04`).
///
/// The two methods exist because the platform needs to be told two different
/// things, and conflating them is what makes a healthy backlog look like a
/// failure (`ADR-F19`).
abstract interface class SyncScheduler {
  /// Requests a drain: "there is work; run when you can."
  ///
  /// Safe to call freely — on capture, on finishing a batch, on resume, on a
  /// connectivity improvement. Implementations must be idempotent and must not
  /// throw: a scheduling failure may not endanger work that is already durably
  /// queued (`SYNC_ENGINE.md` §8).
  Future<SchedulingOutcome> scheduleDrain();

  /// Requests a **continuation**: "this slice finished healthily and there is
  /// more; run again after it."
  ///
  /// Called only by a worker that made progress and stopped at its own bound.
  /// It is not a retry, and it must not attract backoff — the previous slice
  /// succeeded.
  Future<SchedulingOutcome> scheduleContinuation();
}
