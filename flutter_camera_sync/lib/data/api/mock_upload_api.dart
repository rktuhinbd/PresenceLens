import '../../domain/entities/failure_category.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/entities/upload_outcome.dart';
import '../../domain/ports/connectivity_port.dart';
import '../../domain/ports/upload_api.dart';

/// Which behaviour [MockUploadApi] should exhibit.
///
/// **Deterministic, never random.** A reviewer has to be able to demonstrate
/// the failure path on demand, and a random mock makes the single most
/// important behaviour in this task unreproducible (`ADR-F06`).
sealed class MockScenario {
  /// Const base constructor.
  const MockScenario();

  /// Every upload succeeds. The happy path.
  static const MockScenario alwaysSucceed = _AlwaysSucceed();

  /// Every upload fails as a timeout, so nothing is ever delivered and nothing
  /// is ever lost (`FLT-SYNC-003`).
  static const MockScenario alwaysFailRetryable = _AlwaysFailRetryable();

  /// Every upload is rejected outright, exercising terminal handling.
  static const MockScenario failPermanently = _FailPermanently();

  /// Consults connectivity: retryable failure with no link, success otherwise.
  ///
  /// The default, because it makes the mandated demonstration
  /// (`FLT-SYNC-004`) work naturally on a device with no code change: turn on
  /// airplane mode, watch items queue, turn it off, watch them drain.
  ///
  /// Note the direction of this dependency. Connectivity stands in for *the
  /// server's* reachability **inside a fake transport**. It is not the app
  /// deciding whether to try, which would be exactly the bug `ADR-F05` exists
  /// to prevent.
  static const MockScenario offlineAware = _OfflineAware();

  /// Fails the first [failures] attempts on an image, then succeeds.
  ///
  /// Demonstrates automatic recovery. The count is read from the image's own
  /// persisted `attemptCount`, not from memory, so the behaviour is identical
  /// after a process death and identical in both isolates.
  const factory MockScenario.failThenSucceed(int failures) = _FailThenSucceed;
}

final class _AlwaysSucceed extends MockScenario {
  const _AlwaysSucceed();
}

final class _AlwaysFailRetryable extends MockScenario {
  const _AlwaysFailRetryable();
}

final class _FailPermanently extends MockScenario {
  const _FailPermanently();
}

final class _OfflineAware extends MockScenario {
  const _OfflineAware();
}

final class _FailThenSucceed extends MockScenario {
  const _FailThenSucceed(this.failures);

  final int failures;
}

/// A deterministic stand-in for the upload endpoint the assessment does not
/// provide (p3 Note).
///
/// The seam ([UploadApi]) is real, so a genuine HTTP client replaces this class
/// and nothing else. What is *not* fabricated is a transport: there is no
/// socket here and none is claimed.
class MockUploadApi implements UploadApi {
  /// Creates the mock.
  ///
  /// [latency] models an asynchronous boundary so callers cannot accidentally
  /// depend on an upload completing synchronously. Tests pass
  /// [Duration.zero].
  MockUploadApi({
    MockScenario scenario = MockScenario.offlineAware,
    ConnectivityPort? connectivity,
    Duration latency = defaultLatency,
  }) : _scenario = scenario,
       _connectivity = connectivity,
       _latency = latency;

  /// Delay applied to every attempt in the app.
  static const Duration defaultLatency = Duration(milliseconds: 400);

  final MockScenario _scenario;
  final ConnectivityPort? _connectivity;
  final Duration _latency;
  final List<String> _receivedKeys = <String>[];

  /// Idempotency keys this instance has been handed, in order.
  ///
  /// A real backend would deduplicate on these. Recording them is how the tests
  /// show the client does its half of that contract (`RS-06`); the mock makes
  /// no claim to resolve an ambiguous failure on the client's behalf, because
  /// the client cannot.
  List<String> get receivedIdempotencyKeys =>
      List<String>.unmodifiable(_receivedKeys);

  /// The scenario in force.
  MockScenario get scenario => _scenario;

  @override
  Future<UploadOutcome> upload(QueuedImage image) async {
    _receivedKeys.add(image.id);
    if (_latency > Duration.zero) {
      await Future<void>.delayed(_latency);
    }

    switch (_scenario) {
      case _AlwaysSucceed():
        return UploadSucceeded(idempotencyKey: image.id);

      case _AlwaysFailRetryable():
        return const UploadFailed(
          FailureCategory.timeout,
          detail: 'Mock scenario: alwaysFailRetryable',
        );

      case _FailPermanently():
        return const UploadFailed(
          FailureCategory.serverRejected,
          detail: 'Mock scenario: failPermanently',
        );

      case _FailThenSucceed(:final int failures):
        if (image.attemptCount < failures) {
          return UploadFailed(
            FailureCategory.timeout,
            detail:
                'Mock scenario: attempt ${image.attemptCount + 1} '
                'of $failures scripted failures',
          );
        }
        return UploadSucceeded(idempotencyKey: image.id);

      case _OfflineAware():
        final bool hasLink = await _connectivity?.hasLink() ?? true;
        if (!hasLink) {
          return const UploadFailed(
            FailureCategory.offline,
            detail: 'Mock transport: the device reports no link',
          );
        }
        return UploadSucceeded(idempotencyKey: image.id);
    }
  }
}
