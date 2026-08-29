/// Decides when an `UPLOADING` claim has been abandoned.
///
/// This is the whole of the app's process-death recovery (`FLT-SYNC-009`). An
/// item claimed by a processor that was then killed would otherwise sit in
/// `UPLOADING` forever and the queue would silently stop draining (`RD-03`).
///
/// The lease is folded into the claim query rather than swept at startup, so
/// recovery happens on **every** drain, in both isolates, with no separate code
/// path anyone can forget to call.
class StaleClaimPolicy {
  /// Creates the policy, optionally overriding [leasePeriod] (tests do).
  const StaleClaimPolicy({this.leasePeriod = defaultLeasePeriod});

  /// How long a claim is respected before it may be taken over.
  ///
  /// Ten minutes: comfortably longer than any plausible single upload attempt,
  /// so a live processor is never robbed of work it is doing; short enough that
  /// a process killed mid-upload recovers within one ordinary WorkManager
  /// cycle rather than at the next launch.
  static const Duration defaultLeasePeriod = Duration(minutes: 10);

  /// The lease length in force.
  final Duration leasePeriod;

  /// The instant before which a claim counts as abandoned.
  DateTime cutoffFrom(DateTime now) => now.subtract(leasePeriod);

  /// Whether a claim stamped [claimedAt] is abandoned as of [now].
  ///
  /// A claim exactly at the cutoff is **not** expired, matching the strict `<`
  /// used by the SQL claim, so the Dart rule and the database rule cannot
  /// disagree at the boundary. A stamp in the future is never expired.
  bool isExpired({required DateTime claimedAt, required DateTime now}) =>
      claimedAt.isBefore(cutoffFrom(now));
}
