// `WIDGET` tier — Pending Uploads.
//
// The screen exists to answer one question — "did I lose my photos?" — so these
// tests assert the *copy* as carefully as the structure. Wording that promises a
// schedule the OS controls, or a retry ceiling that does not exist, is a defect
// here and is asserted against explicitly.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/failure_category.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/presentation/uploads/upload_manager_screen.dart';
import 'package:presence_lens_capture/presentation/uploads/widgets/upload_manager_widgets.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

/// Builds the Upload Manager over the harness, with time pinned.
Future<void> _pumpUploads(
  WidgetTester tester,
  AppHarness harness, {
  bool reducedMotion = false,
}) async {
  harness.startSync();
  await tester.pumpWidget(
    harness.app(
      reducedMotion: reducedMotion,
      home: UploadManagerScreen(
        clock: MutableClock(
          harness.clock.nowUtc().add(const Duration(hours: 1)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Seeds one finished batch holding [statuses], in order.
Future<void> _seedBatch(
  AppHarness harness,
  String batchId,
  List<({ImageStatus status, int attempts, FailureCategory? failure})> images,
) async {
  await harness.queue.createDraftBatch(
    id: batchId,
    createdAt: harness.clock.nowUtc(),
  );
  for (int i = 0; i < images.length; i++) {
    await harness.seedCapture(
      batchId,
      '$batchId-IMG_00$i',
      offset: Duration(minutes: i),
    );
  }
  await harness.queue.enqueueBatch(batchId, queuedAt: harness.clock.nowUtc());
  for (int i = 0; i < images.length; i++) {
    final ({ImageStatus status, int attempts, FailureCategory? failure}) spec =
        images[i];
    final String id = '$batchId-IMG_00$i';
    switch (spec.status) {
      case ImageStatus.uploaded:
        await harness.queue.recordSuccess(id, now: harness.clock.nowUtc());
      case ImageStatus.uploading:
        await harness.queue.claimNext(
          now: harness.clock.nowUtc(),
          leaseCutoff: harness.clock.nowUtc(),
          skip: <String>{},
        );
      case ImageStatus.failedPermanent:
        await harness.queue.recordPermanentFailure(
          id,
          category: spec.failure ?? FailureCategory.missingLocalFile,
          now: harness.clock.nowUtc(),
        );
      case ImageStatus.pending:
        for (int a = 0; a < spec.attempts; a++) {
          await harness.queue.recordRetryableFailure(
            id,
            category: spec.failure ?? FailureCategory.serverTransient,
            now: harness.clock.nowUtc(),
          );
        }
      case ImageStatus.draft:
        break;
    }
  }
}

void main() {
  testWidgets('an empty queue is a success, not an error', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _pumpUploads(tester, harness);

    expect(find.text(UploadsEmptyView.headline), findsOneWidget);
    expect(find.text('Open camera'), findsOneWidget);
    // Not "0 items", and nothing styled as a warning.
    expect(find.textContaining('0 items'), findsNothing);
    expect(find.byType(ConnectivityChip), findsNothing);
  });

  testWidgets('a draining batch renders every state with icon and words', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (status: ImageStatus.uploaded, attempts: 0, failure: null),
        (status: ImageStatus.pending, attempts: 0, failure: null),
        (
          status: ImageStatus.pending,
          attempts: 3,
          failure: FailureCategory.serverTransient,
        ),
      ],
    );

    await _pumpUploads(tester, harness);

    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('In queue'), findsOneWidget);
    expect(find.text('Retrying · attempt 3'), findsOneWidget);
    // Count-based progress, never a fabricated byte percentage.
    expect(find.text('1 of 3'), findsOneWidget);
    // Every state carries a glyph as well as its words (`FLT-UX-005`).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('the connected chip promises automatic, never immediate', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (status: ImageStatus.pending, attempts: 0, failure: null),
      ],
    );

    await _pumpUploads(tester, harness);

    expect(find.text(ConnectivityChip.connectedText), findsOneWidget);
    expect(find.textContaining('Uploading now'), findsNothing);
    expect(find.textContaining('STABLE'), findsNothing);
    expect(find.textContaining('stable'), findsNothing);
    expect(find.text(UploadManagerScreen.reassurance), findsOneWidget);
  });

  testWidgets('the offline chip leads with the reassurance', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create(hasLink: false);
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (
          status: ImageStatus.pending,
          attempts: 2,
          failure: FailureCategory.offline,
        ),
        (
          status: ImageStatus.failedPermanent,
          attempts: 1,
          failure: FailureCategory.missingLocalFile,
        ),
      ],
    );

    await _pumpUploads(tester, harness);

    expect(find.text(ConnectivityChip.offlineText), findsOneWidget);
    expect(find.text('Waiting for connection'), findsOneWidget);
    expect(find.text("Can't upload · file missing"), findsOneWidget);
    // The permanently failed row is visibly distinct from the waiting one, and
    // not by colour alone.
    expect(find.byIcon(Icons.cloud_off_outlined), findsWidgets);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('multiple batches each carry their own progress', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (status: ImageStatus.uploaded, attempts: 0, failure: null),
        (status: ImageStatus.pending, attempts: 0, failure: null),
      ],
    );
    await _seedBatch(
      harness,
      'b2',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (status: ImageStatus.pending, attempts: 0, failure: null),
      ],
    );

    await _pumpUploads(tester, harness);

    expect(find.byType(BatchSection), findsNWidgets(2));
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);
  });

  testWidgets('a row reads as one sentence to a screen reader', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (
          status: ImageStatus.pending,
          attempts: 3,
          failure: FailureCategory.serverTransient,
        ),
      ],
    );

    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpUploads(tester, harness);

    final SemanticsNode node = tester.getSemantics(find.byType(QueueItemRow));
    expect(node.label, 'b1-IMG_000.jpg, retrying · attempt 3');
    semantics.dispose();
  });

  testWidgets('"Try now" is an accelerator hidden in the overflow', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (status: ImageStatus.pending, attempts: 0, failure: null),
      ],
    );

    await _pumpUploads(tester, harness);

    // Not a primary control. Automatic recovery must never look like it depends
    // on the user pressing something (`FLT-SYNC-014`).
    expect(find.text('Try now'), findsNothing);

    final int before = harness.scheduler.scheduleCount;
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try now'));
    await tester.pumpAndSettle();

    expect(harness.scheduler.scheduleCount, greaterThan(before));
  });

  testWidgets('the Upload Manager renders in the dark scheme too', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.create();
    addTearDown(harness.dispose);
    usePhoneSurface(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await _seedBatch(
      harness,
      'b1',
      <({ImageStatus status, int attempts, FailureCategory? failure})>[
        (status: ImageStatus.pending, attempts: 0, failure: null),
      ],
    );

    await _pumpUploads(tester, harness);

    // `FLT-UX-008`: role-based colour means both brightnesses are one
    // definition, and neither is a special case with its own literals.
    expect(find.text('In queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
