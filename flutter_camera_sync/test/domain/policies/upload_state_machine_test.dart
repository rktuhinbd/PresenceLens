// UNIT tier — the image lifecycle (FLT-SYNC-001, FLT-TEST-001).

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/policies/upload_state_machine.dart';

void main() {
  const UploadStateMachine machine = UploadStateMachine();

  group('legal transitions', () {
    test('a draft capture becomes pending when its batch is finished', () {
      expect(machine.isLegal(ImageStatus.draft, ImageStatus.pending), isTrue);
    });

    test('a pending image may be claimed', () {
      expect(
        machine.isLegal(ImageStatus.pending, ImageStatus.uploading),
        isTrue,
      );
    });

    test('a claimed image may succeed', () {
      expect(
        machine.isLegal(ImageStatus.uploading, ImageStatus.uploaded),
        isTrue,
      );
    });

    test('a retryable failure returns it to pending', () {
      expect(
        machine.isLegal(ImageStatus.uploading, ImageStatus.pending),
        isTrue,
        reason: 'this is why there is no RETRYABLE_FAILURE resting state',
      );
    });

    test('a permanent failure leaves the work set', () {
      expect(
        machine.isLegal(ImageStatus.uploading, ImageStatus.failedPermanent),
        isTrue,
      );
    });

    test('an abandoned claim may be taken over by another processor', () {
      expect(
        machine.isLegal(ImageStatus.uploading, ImageStatus.uploading),
        isTrue,
        reason: 'lease reclaim is a real transition, not an accident',
      );
    });
  });

  group('illegal transitions', () {
    test('an uploaded image is never returned to the queue', () {
      // The regression this pins: an "upload everything pending" sweep that
      // re-queues terminal rows and uploads a photo the server already has.
      expect(
        machine.isLegal(ImageStatus.uploaded, ImageStatus.pending),
        isFalse,
      );
      expect(
        machine.isLegal(ImageStatus.uploaded, ImageStatus.uploading),
        isFalse,
      );
    });

    test('a permanently failed image cannot move anywhere', () {
      for (final ImageStatus target in ImageStatus.values) {
        expect(
          machine.isLegal(ImageStatus.failedPermanent, target),
          isFalse,
          reason: 'failedPermanent -> ${target.name} must be refused',
        );
      }
    });

    test('a draft image is never claimed directly', () {
      expect(
        machine.isLegal(ImageStatus.draft, ImageStatus.uploading),
        isFalse,
        reason: 'an unfinished batch is not work',
      );
    });

    test('a pending image cannot jump straight to uploaded', () {
      expect(
        machine.isLegal(ImageStatus.pending, ImageStatus.uploaded),
        isFalse,
      );
    });

    test('nothing may return to draft', () {
      for (final ImageStatus from in ImageStatus.values) {
        expect(machine.isLegal(from, ImageStatus.draft), isFalse);
      }
    });

    test('requireLegal throws with both statuses named', () {
      expect(
        () => machine.requireLegal(ImageStatus.uploaded, ImageStatus.pending),
        throwsA(
          isA<IllegalStateTransition>()
              .having(
                (IllegalStateTransition e) => e.from,
                'from',
                ImageStatus.uploaded,
              )
              .having(
                (IllegalStateTransition e) => e.to,
                'to',
                ImageStatus.pending,
              ),
        ),
      );
    });

    test('requireLegal permits a legal move', () {
      expect(
        () => machine.requireLegal(ImageStatus.pending, ImageStatus.uploading),
        returnsNormally,
      );
    });
  });

  group('terminal statuses', () {
    test('uploaded and failedPermanent are terminal, nothing else is', () {
      expect(machine.isTerminal(ImageStatus.uploaded), isTrue);
      expect(machine.isTerminal(ImageStatus.failedPermanent), isTrue);
      expect(machine.isTerminal(ImageStatus.draft), isFalse);
      expect(machine.isTerminal(ImageStatus.pending), isFalse);
      expect(machine.isTerminal(ImageStatus.uploading), isFalse);
    });

    test('every terminal status has no outgoing transition', () {
      for (final ImageStatus status in UploadStateMachine.terminalStatuses) {
        expect(machine.transitionsFrom(status), isEmpty);
      }
    });

    test('outstanding work is exactly draft, pending and uploading', () {
      // Drives the worker's "come back later" decision, so getting it wrong
      // either strands the queue or retries a terminal item forever.
      expect(
        ImageStatus.values.where((ImageStatus s) => s.isOutstanding).toSet(),
        <ImageStatus>{
          ImageStatus.draft,
          ImageStatus.pending,
          ImageStatus.uploading,
        },
      );
    });
  });

  group('persisted names', () {
    test('every status round-trips through its stored string', () {
      for (final ImageStatus status in ImageStatus.values) {
        expect(ImageStatus.fromWireName(status.wireName), status);
      }
    });

    test('an unknown stored string is rejected rather than defaulted', () {
      expect(
        () => ImageStatus.fromWireName('RETRYABLE_FAILURE'),
        throwsArgumentError,
      );
    });
  });
}
