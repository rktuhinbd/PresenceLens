// Opportunistic rescheduling on a regained link (FLT-SYNC-004, FLT-SYNC-011).

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/sync/connectivity_drain_trigger.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';

import '../../support/fakes.dart';

void main() {
  late FakeConnectivity connectivity;
  late RecordingScheduler scheduler;
  late ConnectivityDrainTrigger trigger;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    connectivity = FakeConnectivity(hasLinkNow: false);
    scheduler = RecordingScheduler();
    trigger = ConnectivityDrainTrigger(
      connectivity: connectivity,
      scheduler: scheduler,
    );
  });

  tearDown(() async {
    await trigger.stop();
    await connectivity.dispose();
  });

  test('schedules nothing merely by starting', () async {
    await trigger.start();
    await settle();

    expect(
      scheduler.scheduleCount,
      0,
      reason: 'a drain is requested when something changes, not on principle',
    );
  });

  test('requests a drain when a link is regained', () async {
    await trigger.start();

    connectivity.emit(true);
    await settle();

    expect(scheduler.scheduleCount, 1);
  });

  test('does not request one when the link is lost', () async {
    await trigger.start();
    connectivity.emit(true);
    await settle();

    connectivity.emit(false);
    await settle();

    expect(scheduler.scheduleCount, 1);
  });

  test('a repeated "connected" does not re-register', () async {
    // Only the transition into having a link matters. Reacting to every
    // emission would re-register on ordinary Wi-Fi-to-mobile handovers.
    await trigger.start();

    connectivity.emit(true);
    connectivity.emit(true);
    await settle();

    expect(scheduler.scheduleCount, 1);
  });

  test('an offline-online-offline-online cycle requests two drains', () async {
    await trigger.start();

    connectivity.emit(true);
    connectivity.emit(false);
    connectivity.emit(true);
    await settle();

    expect(scheduler.scheduleCount, 2);
  });

  test(
    'starting while already connected does not fire on the first event',
    () async {
      final FakeConnectivity connected = FakeConnectivity();
      addTearDown(connected.dispose);
      final RecordingScheduler recorder = RecordingScheduler();
      final ConnectivityDrainTrigger already = ConnectivityDrainTrigger(
        connectivity: connected,
        scheduler: recorder,
      );
      addTearDown(already.stop);

      await already.start();
      connected.emit(true);
      await settle();

      expect(recorder.scheduleCount, 0);
    },
  );

  test('stopping ends the subscription', () async {
    await trigger.start();
    expect(trigger.isRunning, isTrue);

    await trigger.stop();
    expect(trigger.isRunning, isFalse);

    connectivity.emit(true);
    await settle();
    expect(scheduler.scheduleCount, 0);
  });

  test('starting twice listens once', () async {
    await trigger.start();
    await trigger.start();

    connectivity.emit(true);
    await settle();

    expect(scheduler.scheduleCount, 1);
  });

  test('an unavailable connectivity plugin does not stop the app', () async {
    connectivity.failHasLink = true;

    await expectLater(trigger.start(), completes);
    expect(trigger.isRunning, isTrue);
  });

  group('scheduling failure is observable', () {
    test('records that the platform accepted the request', () async {
      await trigger.start();
      expect(trigger.lastSchedulingOutcome, isNull);

      connectivity.emit(true);
      await settle();

      expect(trigger.lastSchedulingOutcome, SchedulingOutcome.requested);
    });

    test('records that the platform refused it', () async {
      // A lost wake-up costs a delay, never a capture — but it must not be
      // invisible, or a queue that quietly stops being drained looks like a
      // queue that has nothing to do.
      final FakeConnectivity link = FakeConnectivity(hasLinkNow: false);
      addTearDown(link.dispose);
      final RecordingScheduler failing = RecordingScheduler(
        drainOutcome: SchedulingOutcome.unavailable,
      );
      final ConnectivityDrainTrigger observed = ConnectivityDrainTrigger(
        connectivity: link,
        scheduler: failing,
      );
      addTearDown(observed.stop);

      await observed.start();
      link.emit(true);
      await settle();

      expect(observed.lastSchedulingOutcome, SchedulingOutcome.unavailable);
      expect(
        failing.scheduleCount,
        1,
        reason: 'it did try; the platform is what refused',
      );
    });

    test('a later success replaces the recorded failure', () async {
      // The next opportunity asking again is the whole recovery story, so the
      // record has to move with it.
      final RecordingScheduler flaky = RecordingScheduler(
        drainOutcome: SchedulingOutcome.unavailable,
      );
      final FakeConnectivity link = FakeConnectivity(hasLinkNow: false);
      addTearDown(link.dispose);
      final ConnectivityDrainTrigger observed = ConnectivityDrainTrigger(
        connectivity: link,
        scheduler: flaky,
      );
      addTearDown(observed.stop);

      await observed.start();
      link.emit(true);
      await settle();
      expect(observed.lastSchedulingOutcome, SchedulingOutcome.unavailable);

      flaky.drainOutcome = SchedulingOutcome.requested;
      link.emit(false);
      link.emit(true);
      await settle();

      expect(observed.lastSchedulingOutcome, SchedulingOutcome.requested);
    });
  });
}
