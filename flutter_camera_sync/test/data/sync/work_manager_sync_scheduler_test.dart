// The scheduling strategy (FLT-SYNC-002, FLT-SYNC-007, RS-03, RS-04, ADR-F19).
//
// What is asserted here is the *policy* handed to WorkManager, not that
// WorkManager ran anything — the OS owns that, cannot be driven from a host,
// and is verified on a device at gate F7. "We registered some work" would be
// worthless; the parameters are the design.

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/sync/work_manager_sync_scheduler.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:workmanager/workmanager.dart';

import '../../support/fakes.dart';

class _RecordedRegistration {
  _RecordedRegistration({
    required this.uniqueName,
    required this.taskName,
    required this.constraints,
    required this.existingWorkPolicy,
    required this.backoffPolicy,
    required this.backoffPolicyDelay,
  });

  final String uniqueName;
  final String taskName;
  final Constraints? constraints;
  final ExistingWorkPolicy? existingWorkPolicy;
  final BackoffPolicy? backoffPolicy;
  final Duration? backoffPolicyDelay;
}

void main() {
  late List<_RecordedRegistration> registrations;
  late WorkManagerSyncScheduler scheduler;

  RegisterOneOffTask recorder({Exception? throws}) {
    return (
      String uniqueName,
      String taskName, {
      Constraints? constraints,
      ExistingWorkPolicy? existingWorkPolicy,
      BackoffPolicy? backoffPolicy,
      Duration? backoffPolicyDelay,
    }) async {
      registrations.add(
        _RecordedRegistration(
          uniqueName: uniqueName,
          taskName: taskName,
          constraints: constraints,
          existingWorkPolicy: existingWorkPolicy,
          backoffPolicy: backoffPolicy,
          backoffPolicyDelay: backoffPolicyDelay,
        ),
      );
      if (throws != null) {
        throw throws;
      }
    };
  }

  setUp(() {
    registrations = <_RecordedRegistration>[];
    scheduler = WorkManagerSyncScheduler(registerOneOffTask: recorder());
  });

  group('A — requesting a drain when no chain exists', () {
    test('registers one-off work under a single fixed unique name', () async {
      expect(await scheduler.scheduleDrain(), SchedulingOutcome.requested);

      expect(registrations, hasLength(1));
      expect(registrations.single.uniqueName, 'presencelens.sync.drain');
      expect(registrations.single.taskName, WorkManagerSyncScheduler.taskName);
    });

    test('constrains the work to a connected network', () async {
      // Advisory only: it saves pointless wake-ups. No upload decision is taken
      // from it, because link presence is not reachability (`ADR-F05`).
      await scheduler.scheduleDrain();

      expect(
        registrations.last.constraints?.networkType,
        NetworkType.connected,
      );
    });
  });

  group('B — a request made while a drain may be running is not discarded', () {
    test('entry work uses append, never keep', () async {
      // **The final F1 acceptance fix.** This used to be `keep`, and `KEEP`
      // discards a request while *uncompleted* work exists under the same
      // unique name — a running worker is uncompleted. That produced a
      // liveness race with no data loss and no symptom:
      //
      //   worker takes its last outstanding reading
      //   → foreground commits a finished batch to PENDING
      //   → foreground requests a drain; KEEP discards it
      //   → worker returns success, never having seen those rows
      //   → durable PENDING work, and nothing scheduled to collect it.
      //
      // `append` maps to Android's APPEND_OR_REPLACE (verified in the resolved
      // plugin's Kotlin, `FR-06a`): with no chain it starts one, and with a
      // running worker it enqueues a successor. The request cannot vanish.
      await scheduler.scheduleDrain();

      expect(
        registrations.single.existingWorkPolicy,
        ExistingWorkPolicy.append,
      );
      expect(
        registrations.single.existingWorkPolicy,
        isNot(ExistingWorkPolicy.keep),
        reason: 'keep is what reopened the liveness race',
      );
    });

    test('the policy is one constant, shared by both operations', () async {
      // So the two can never drift apart into one safe and one racy path.
      await scheduler.scheduleDrain();
      await scheduler.scheduleContinuation();

      expect(
        registrations
            .map((_RecordedRegistration r) => r.existingWorkPolicy)
            .toSet(),
        <ExistingWorkPolicy>{WorkManagerSyncScheduler.conflictPolicy},
      );
      expect(
        WorkManagerSyncScheduler.conflictPolicy,
        ExistingWorkPolicy.append,
      );
    });
  });

  group('D — repeated requests stay on one serial chain', () {
    test('every request uses the same unique name', () async {
      // One unique name means WorkManager runs the chain one node at a time, so
      // the scheduler never asks for two drains in parallel however many
      // requests arrive (`RS-03`). Correctness would survive it anyway — the
      // atomic claim, not the scheduler, is the boundary — but there is no
      // reason to ask.
      for (int i = 0; i < 3; i++) {
        await scheduler.scheduleDrain();
      }
      await scheduler.scheduleContinuation();

      expect(registrations, hasLength(4));
      expect(
        registrations.map((_RecordedRegistration r) => r.uniqueName).toSet(),
        <String>{WorkManagerSyncScheduler.uniqueName},
      );
      expect(
        registrations.map((_RecordedRegistration r) => r.taskName).toSet(),
        <String>{WorkManagerSyncScheduler.taskName},
      );
    });

    test('a redundant request is a wasted wake-up, never a lost one', () async {
      // The tradeoff `append` buys, stated as a test: requests accumulate as
      // extra nodes rather than collapsing. A redundant node finds an empty
      // queue and returns `idle` at once; a discarded request is a queue that
      // stops draining.
      for (int i = 0; i < 5; i++) {
        expect(await scheduler.scheduleDrain(), SchedulingOutcome.requested);
      }

      expect(registrations, hasLength(5));
    });
  });

  group('C — a continuation joins the same serial chain (ADR-F19)', () {
    test('appends, so it runs after the slice that asked for it', () async {
      // `append` is the plugin's name; verified verbatim in the resolved
      // `workmanager_android` 0.10.8 Kotlin
      // (`WorkManagerUtils.toAndroidWorkPolicy`), it maps to Android's
      // APPEND_OR_REPLACE — the variant that starts a fresh chain rather than
      // inheriting a CANCELLED or FAILED one. That is what makes it safe to
      // enqueue from inside the running worker.
      //
      // `keep` would be wrong here and silently so: the worker asking for its
      // own successor *is* itself uncompleted work under that unique name, so
      // KEEP would discard the request and the backlog would sit until some
      // other trigger came along.
      expect(
        await scheduler.scheduleContinuation(),
        SchedulingOutcome.requested,
      );

      expect(
        registrations.single.existingWorkPolicy,
        ExistingWorkPolicy.append,
      );
    });

    test('shares the unique name, so ordering is preserved', () async {
      // A pending continuation already is a scheduled drain. Sharing the name
      // keeps every request on one serial chain instead of creating a second
      // one (`RS-03`).
      await scheduler.scheduleContinuation();

      expect(
        registrations.single.uniqueName,
        WorkManagerSyncScheduler.uniqueName,
      );
      expect(registrations.single.taskName, WorkManagerSyncScheduler.taskName);
    });

    test('carries the same constraint and backoff as an entry drain', () async {
      await scheduler.scheduleDrain();
      await scheduler.scheduleContinuation();

      final _RecordedRegistration drain = registrations.first;
      final _RecordedRegistration continuation = registrations.last;

      expect(
        continuation.constraints?.networkType,
        drain.constraints?.networkType,
      );
      expect(continuation.backoffPolicy, drain.backoffPolicy);
      expect(continuation.backoffPolicyDelay, drain.backoffPolicyDelay);
    });
  });

  group('backoff', () {
    test('is exponential, starting above the platform floor', () async {
      // The configured value is an *initial* delay, not the floor. Android's
      // floor is `WorkRequest.MIN_BACKOFF_MILLIS` = 10 seconds (read from
      // androidx.work:work-runtime:2.11.2, the version this project resolves);
      // the maximum is 5 hours and the platform default is 30 seconds.
      await scheduler.scheduleDrain();

      expect(registrations.single.backoffPolicy, BackoffPolicy.exponential);
      expect(
        registrations.single.backoffPolicyDelay,
        const Duration(seconds: 15),
      );
      expect(
        WorkManagerSyncScheduler.backoffDelay,
        const Duration(seconds: 15),
      );
      expect(
        WorkManagerSyncScheduler.backoffDelay,
        greaterThan(const Duration(seconds: 10)),
        reason: 'a value below the floor would be silently raised by Android',
      );
    });
  });

  group('failure is safe but not silent', () {
    test('a plugin failure does not escape to the caller', () async {
      // Scheduling is an accelerator, not the queue. A capture that is already
      // durable must not be reported as failed because the scheduler could not
      // be reached.
      final WorkManagerSyncScheduler failing = WorkManagerSyncScheduler(
        registerOneOffTask: recorder(
          throws: Exception('the workmanager plugin is not available'),
        ),
      );

      await expectLater(failing.scheduleDrain(), completes);
    });

    test('but the caller can tell that it failed', () async {
      // The regression this guards is a scheduler that swallows so thoroughly
      // that nothing can ever notice, which is how a queue quietly stops being
      // drained.
      final WorkManagerSyncScheduler failing = WorkManagerSyncScheduler(
        registerOneOffTask: recorder(throws: Exception('no plugin')),
      );

      expect(await failing.scheduleDrain(), SchedulingOutcome.unavailable);
      expect(failing.lastSchedulingError, isNotNull);
    });

    test('a continuation failure is reported the same way', () async {
      final WorkManagerSyncScheduler failing = WorkManagerSyncScheduler(
        registerOneOffTask: recorder(throws: Exception('no plugin')),
      );

      expect(
        await failing.scheduleContinuation(),
        SchedulingOutcome.unavailable,
      );
    });

    test('a later success clears the recorded error', () async {
      bool shouldThrow = true;
      final WorkManagerSyncScheduler flaky = WorkManagerSyncScheduler(
        registerOneOffTask:
            (
              String uniqueName,
              String taskName, {
              Constraints? constraints,
              ExistingWorkPolicy? existingWorkPolicy,
              BackoffPolicy? backoffPolicy,
              Duration? backoffPolicyDelay,
            }) async {
              if (shouldThrow) {
                throw Exception('not yet');
              }
            },
      );

      expect(await flaky.scheduleDrain(), SchedulingOutcome.unavailable);
      expect(flaky.lastSchedulingError, isNotNull);

      shouldThrow = false;
      expect(await flaky.scheduleDrain(), SchedulingOutcome.requested);
      expect(flaky.lastSchedulingError, isNull);
    });
  });

  group('the background isolate scheduler', () {
    test('suppresses a request for entry work', () async {
      // The worker's lever for "come back and retry" is its return value.
      // Registering entry work from inside it would run a second scheduler
      // against WorkManager's own backoff (`RS-04`).
      final RecordingScheduler delegate = RecordingScheduler();
      final BackgroundSyncScheduler background = BackgroundSyncScheduler(
        delegate,
      );

      expect(await background.scheduleDrain(), SchedulingOutcome.suppressed);
      expect(delegate.scheduleCount, 0);
    });

    test('forwards a continuation', () async {
      final RecordingScheduler delegate = RecordingScheduler();
      final BackgroundSyncScheduler background = BackgroundSyncScheduler(
        delegate,
      );

      expect(
        await background.scheduleContinuation(),
        SchedulingOutcome.requested,
      );
      expect(delegate.continuationCount, 1);
    });

    test('reports a forwarded failure honestly', () async {
      final RecordingScheduler delegate = RecordingScheduler(
        continuationOutcome: SchedulingOutcome.unavailable,
      );
      final BackgroundSyncScheduler background = BackgroundSyncScheduler(
        delegate,
      );

      expect(
        await background.scheduleContinuation(),
        SchedulingOutcome.unavailable,
      );
    });
  });
}
