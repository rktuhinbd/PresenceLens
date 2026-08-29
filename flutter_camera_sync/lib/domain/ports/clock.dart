/// The source of "now".
///
/// Injected rather than called directly so lease expiry, attempt stamps and
/// queue ordering can be driven deterministically in tests. A ten-minute lease
/// is otherwise untestable without a ten-minute test.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime nowUtc();
}

/// The real clock.
final class SystemClock implements Clock {
  /// Creates the system clock.
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
