// The deterministic mock transport (FLT-SYNC-005, FLT-SYNC-011, ADR-F06).

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/api/mock_upload_api.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/entities/upload_outcome.dart';

import '../../support/fakes.dart';

void main() {
  QueuedImage image({String id = 'i1', int attemptCount = 0}) => QueuedImage(
    id: id,
    batchId: 'b1',
    localPath: '/captures/b1/$id.jpg',
    capturedAt: DateTime.utc(2026, 8, 29, 10),
    status: ImageStatus.uploading,
    attemptCount: attemptCount,
  );

  test('alwaysSucceed succeeds, and echoes the idempotency key', () async {
    final MockUploadApi api = MockUploadApi(
      scenario: MockScenario.alwaysSucceed,
      latency: Duration.zero,
    );

    final UploadOutcome outcome = await api.upload(image());

    expect(outcome, isA<UploadSucceeded>());
    expect((outcome as UploadSucceeded).idempotencyKey, 'i1');
  });

  test('alwaysSucceed is deterministic over many calls', () async {
    // A random mock would make the most important behaviour in this task
    // unreproducible for a reviewer, which is why there is no randomness here
    // to test around.
    final MockUploadApi api = MockUploadApi(
      scenario: MockScenario.alwaysSucceed,
      latency: Duration.zero,
    );

    for (int i = 0; i < 25; i++) {
      expect(await api.upload(image(id: 'i$i')), isA<UploadSucceeded>());
    }
  });

  test('alwaysFailRetryable reports a timeout every time', () async {
    final MockUploadApi api = MockUploadApi(
      scenario: MockScenario.alwaysFailRetryable,
      latency: Duration.zero,
    );

    for (int i = 0; i < 5; i++) {
      final UploadOutcome outcome = await api.upload(image());
      expect(outcome, isA<UploadFailed>());
      expect((outcome as UploadFailed).category, FailureCategory.timeout);
    }
  });

  test('failPermanently reports a rejection', () async {
    final MockUploadApi api = MockUploadApi(
      scenario: MockScenario.failPermanently,
      latency: Duration.zero,
    );

    final UploadOutcome outcome = await api.upload(image());

    expect((outcome as UploadFailed).category, FailureCategory.serverRejected);
  });

  group('failThenSucceed', () {
    test('fails the scripted number of attempts, then succeeds', () async {
      final MockUploadApi api = MockUploadApi(
        scenario: const MockScenario.failThenSucceed(2),
        latency: Duration.zero,
      );

      expect(await api.upload(image()), isA<UploadFailed>());
      expect(await api.upload(image(attemptCount: 1)), isA<UploadFailed>());
      expect(await api.upload(image(attemptCount: 2)), isA<UploadSucceeded>());
    });

    test('reads the count from the persisted row, not from memory', () async {
      // So the behaviour is identical after a process death and identical in
      // the worker isolate, which holds no memory of previous attempts.
      final MockUploadApi fresh = MockUploadApi(
        scenario: const MockScenario.failThenSucceed(2),
        latency: Duration.zero,
      );

      expect(
        await fresh.upload(image(attemptCount: 5)),
        isA<UploadSucceeded>(),
        reason: 'a brand-new instance still honours the row it is given',
      );
    });
  });

  group('offlineAware — the default', () {
    test('fails as offline when the device reports no link', () async {
      final FakeConnectivity connectivity = FakeConnectivity(hasLinkNow: false);
      addTearDown(connectivity.dispose);
      final MockUploadApi api = MockUploadApi(
        connectivity: connectivity,
        latency: Duration.zero,
      );

      final UploadOutcome outcome = await api.upload(image());

      expect((outcome as UploadFailed).category, FailureCategory.offline);
    });

    test('succeeds when a link is reported', () async {
      final FakeConnectivity connectivity = FakeConnectivity();
      addTearDown(connectivity.dispose);
      final MockUploadApi api = MockUploadApi(
        connectivity: connectivity,
        latency: Duration.zero,
      );

      expect(await api.upload(image()), isA<UploadSucceeded>());
    });

    test('the same image drains once the link returns', () async {
      // This is the airplane-mode demonstration, expressed as a host test.
      final FakeConnectivity connectivity = FakeConnectivity(hasLinkNow: false);
      addTearDown(connectivity.dispose);
      final MockUploadApi api = MockUploadApi(
        connectivity: connectivity,
        latency: Duration.zero,
      );

      expect(await api.upload(image()), isA<UploadFailed>());
      connectivity.emit(true);
      expect(await api.upload(image(attemptCount: 1)), isA<UploadSucceeded>());
    });

    test('is the scenario used when none is chosen', () async {
      expect(MockUploadApi().scenario, MockScenario.offlineAware);
    });
  });

  test('records every idempotency key it was handed', () async {
    final MockUploadApi api = MockUploadApi(
      scenario: MockScenario.alwaysFailRetryable,
      latency: Duration.zero,
    );

    await api.upload(image(id: 'a'));
    await api.upload(image(id: 'b'));
    await api.upload(image(id: 'a', attemptCount: 1));

    expect(api.receivedIdempotencyKeys, <String>['a', 'b', 'a']);
  });

  test('is a genuine asynchronous boundary', () async {
    // A caller must not be able to depend on an upload completing
    // synchronously, or the processor would appear to work for the wrong
    // reason.
    final MockUploadApi api = MockUploadApi(
      scenario: MockScenario.alwaysSucceed,
      latency: const Duration(milliseconds: 10),
    );

    bool completed = false;
    final Future<UploadOutcome> pending = api
        .upload(image())
        .whenComplete(() => completed = true);

    expect(completed, isFalse);
    await pending;
    expect(completed, isTrue);
  });
}
