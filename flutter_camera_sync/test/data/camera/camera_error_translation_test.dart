// FLT-ERR-001, FLT-ERR-004, §29, §34.
//
// The codes asserted here were read out of the resolved plugin sources in this
// project's pub cache, and the reason they matter is not tidiness: which
// platform emits which code decides what the UI is allowed to offer the user.
// If a future plugin upgrade changes them, this file is what says so.

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/camera/camera_error_translation.dart';
import 'package:presence_lens_capture/domain/entities/camera_error.dart';

void main() {
  CameraFailure classify(
    String code, [
    CameraErrorKind fallback = CameraErrorKind.initializationFailed,
  ]) => CameraErrorTranslation.classify(
    CameraException(code, 'message'),
    fallback,
  );

  group('permission codes', () {
    test('CameraAccessDenied is a retryable refusal', () {
      final CameraFailure failure = classify('CameraAccessDenied');
      expect(failure.kind, CameraErrorKind.permissionDenied);
      expect(failure.kind.isPermissionProblem, isTrue);
      expect(failure.kind.isFatalToSession, isTrue);
    });

    test('CameraAccessDeniedWithoutPrompt is the permanent variant', () {
      expect(
        classify('CameraAccessDeniedWithoutPrompt').kind,
        CameraErrorKind.permissionPermanentlyDenied,
      );
    });

    test('CameraAccessRestricted is policy, not a user choice', () {
      expect(
        classify('CameraAccessRestricted').kind,
        CameraErrorKind.permissionRestricted,
      );
    });

    test('the permanent code is NOT in the set Android can emit — FR-12', () {
      // The load-bearing fact. `CameraPermissionsManager.java` constructs
      // exactly two errors and neither is the "WithoutPrompt" variant, so
      // `permissionPermanentlyDenied` is unreachable on the mandated
      // platform and the UI must not depend on it (`ADR-F22`).
      expect(
        CameraErrorTranslation.deniedCodes,
        contains('CameraAccessDenied'),
      );
      expect(
        CameraErrorTranslation.permanentlyDeniedCodes,
        isNot(contains('CameraAccessDenied')),
      );
      expect(CameraErrorTranslation.permanentlyDeniedCodes, <String>{
        'CameraAccessDeniedWithoutPrompt',
      });
    });
  });

  group('hardware and session codes', () {
    test('a permissions request already in flight is not a hardware fault', () {
      expect(
        classify('CameraPermissionsRequestOngoing').kind,
        CameraErrorKind.cameraUnavailable,
      );
    });

    test('a disposed controller is a race in our own sequencing', () {
      // Must never reach the user: it means the app tore the session down
      // while a call was in flight, which the generation guard already handles.
      final CameraFailure failure = classify('Disposed CameraController');
      expect(failure.kind, CameraErrorKind.sessionDisposed);
      expect(failure.kind.isFatalToSession, isFalse);
    });

    test('an uninitialised controller classifies the same way', () {
      expect(
        classify('Uninitialized CameraController').kind,
        CameraErrorKind.sessionDisposed,
      );
    });
  });

  group('the fallback carries the operation, not a generic error', () {
    test('an unknown code during zoom is a zoom failure', () {
      final CameraFailure failure = classify(
        'setZoomLevelFailed',
        CameraErrorKind.zoomFailed,
      );
      expect(failure.kind, CameraErrorKind.zoomFailed);
      expect(
        failure.kind.isFatalToSession,
        isFalse,
        reason: 'a rejected zoom must not tear down a live preview',
      );
    });

    test('the same unknown code during initialisation IS fatal', () {
      // The point of passing the operation in: one code, two consequences.
      final CameraFailure failure = CameraErrorTranslation.classify(
        CameraException('setZoomLevelFailed', 'message'),
        CameraErrorKind.initializationFailed,
      );
      expect(failure.kind, CameraErrorKind.initializationFailed);
      expect(failure.kind.isFatalToSession, isTrue);
    });

    test('an unknown code during capture is a capture failure', () {
      expect(
        classify('captureFailure', CameraErrorKind.captureFailed).kind,
        CameraErrorKind.captureFailed,
      );
    });
  });

  group('non-plugin errors', () {
    test('an arbitrary error takes the operation fallback', () {
      final CameraFailure failure = CameraErrorTranslation.classify(
        StateError('channel closed'),
        CameraErrorKind.captureFailed,
      );
      expect(failure.kind, CameraErrorKind.captureFailed);
      expect(failure.platformCode, isNull);
      expect(failure.cause, isA<StateError>());
    });

    test('an already-classified failure passes straight through', () {
      const CameraFailure original = CameraFailure(
        CameraErrorKind.noBackCamera,
      );
      expect(
        CameraErrorTranslation.classify(
          original,
          CameraErrorKind.captureFailed,
        ),
        same(original),
      );
    });
  });

  group('diagnostics are preserved but never presented', () {
    test('the platform code is retained for logs', () {
      final CameraFailure failure = classify('CameraAccessDenied');
      expect(failure.platformCode, 'CameraAccessDenied');
      expect(failure.cause, isA<CameraException>());
    });

    test('toString names the kind, so a log is readable', () {
      expect(
        classify('CameraAccessDenied').toString(),
        contains('permissionDenied'),
      );
    });
  });

  group('severity partitions the whole enum', () {
    test('every kind has a severity and a permission verdict', () {
      // A new kind added without a branch would fail to compile in the
      // extension; this asserts the resulting partition is what was intended.
      final Iterable<CameraErrorKind> fatal = CameraErrorKind.values.where(
        (CameraErrorKind k) => k.isFatalToSession,
      );
      final Iterable<CameraErrorKind> local = CameraErrorKind.values.where(
        (CameraErrorKind k) => !k.isFatalToSession,
      );
      expect(fatal, isNotEmpty);
      expect(local, isNotEmpty);
      expect(fatal.length + local.length, CameraErrorKind.values.length);

      for (final CameraErrorKind kind in CameraErrorKind.values) {
        if (kind.isPermissionProblem) {
          expect(
            kind.isFatalToSession,
            isTrue,
            reason: 'a permission problem always ends the session',
          );
        }
      }
    });
  });
}
