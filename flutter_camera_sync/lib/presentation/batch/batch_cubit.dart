import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/capture_batch.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/ports/upload_queue.dart';
import '../../domain/usecases/finish_batch.dart';
import 'batch_state.dart';

/// Owns the open draft batch: what is in it, and the act of finishing it.
///
/// **Cubit, not Bloc** (`ARCHITECTURE.md` §3). There are two operations —
/// re-read, and finish — and neither carries meaning beyond "do this now".
///
/// **It does not count captures itself.** Every number here is re-read from the
/// database, which is what makes the count survive process death and what stops
/// it drifting from the camera's own read-back (`FLT-BAT-001`, `FLT-BAT-007`).
/// The rule about *when* a batch opens lives in `CaptureIntoBatch`, and the rule
/// about the transaction that closes one lives in [FinishBatch]; neither is
/// restated here.
class BatchCubit extends Cubit<BatchState> {
  /// Creates the cubit.
  BatchCubit({required UploadQueue queue, required FinishBatch finishBatch})
    : _queue = queue,
      _finishBatch = finishBatch,
      super(const BatchState());

  final UploadQueue _queue;
  final FinishBatch _finishBatch;

  StreamSubscription<void>? _subscription;

  /// Starts watching the queue and takes a first reading.
  ///
  /// The subscription is what makes a capture show up here: `CameraCubit` writes
  /// through `CaptureIntoBatch`, the DAO announces the change, and this re-reads.
  /// The alternative — having the camera tell the batch what it just did —
  /// would be two components maintaining the same number.
  Future<void> start() async {
    _subscription ??= _queue.changes.listen((void _) {
      unawaited(refresh());
    });
    await refresh();
  }

  /// Re-reads the open draft batch and its most recent capture.
  Future<void> refresh() async {
    final CaptureBatch? draft;
    try {
      draft = await _queue.openDraftBatch();
    } catch (_) {
      // A read that failed is not a batch that vanished. The previous state is
      // kept rather than blanked, because blanking it would tell the user their
      // captures are gone on the strength of one failed query.
      return;
    }
    if (isClosed) {
      return;
    }
    if (draft == null) {
      emit(state.copyWith(clearDraft: true, clearLatestCapture: true));
      return;
    }

    QueuedImage? latest;
    try {
      final List<QueuedImage> images = await _queue.imagesInBatch(draft.id);
      latest = images.isEmpty ? null : images.last;
    } catch (_) {
      latest = state.latestCapture;
    }
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        draft: draft,
        latestCapture: latest,
        clearLatestCapture: latest == null,
      ),
    );
  }

  /// Closes the open batch (`FLT-BAT-005`).
  ///
  /// **A local, durable act.** It needs no network, and it is offered — and
  /// works — while the device is offline, which is exactly what the wording
  /// "Finish batch" promises and "Upload batch" would not (`ADR-F14`).
  ///
  /// Returns the batch id that was closed, or `null` if nothing was.
  Future<String?> finish() async {
    final CaptureBatch? draft = state.draft;
    if (draft == null || draft.imageCount == 0) {
      emit(state.copyWith(failure: BatchActionFailure.emptyBatch));
      return null;
    }
    if (state.isFinishing) {
      // The second of two presses. Dropped rather than queued: `enqueueBatch`
      // refuses a batch that is no longer a draft, so the duplicate would
      // surface as an error for an action that actually succeeded.
      return null;
    }

    emit(state.copyWith(isFinishing: true, clearFailure: true));

    final FinishBatchResult result;
    try {
      result = await _finishBatch(draft.id);
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isFinishing: false,
            failure: BatchActionFailure.finishFailed,
          ),
        );
      }
      return null;
    }

    if (isClosed) {
      return result.batch.id;
    }
    // The draft is cleared from the state directly rather than waited for: the
    // transaction has committed, so there is no open batch any more, and the
    // control must disappear now rather than one stream tick later.
    emit(
      state.copyWith(
        isFinishing: false,
        clearDraft: true,
        clearLatestCapture: true,
        lastScheduling: result.scheduling,
        lastFinishedBatchId: result.batch.id,
      ),
    );
    return result.batch.id;
  }

  /// Clears the last failure once it has been shown.
  void acknowledgeFailure() {
    if (state.failure != null) {
      emit(state.copyWith(clearFailure: true));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
