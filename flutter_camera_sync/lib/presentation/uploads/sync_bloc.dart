import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync/connectivity_drain_trigger.dart';
import '../../data/sync/queue_processor.dart';
import '../../domain/entities/batch_status.dart';
import '../../domain/entities/capture_batch.dart';
import '../../domain/entities/image_status.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/ports/connectivity_port.dart';
import '../../domain/ports/sync_scheduler.dart';
import '../../domain/ports/upload_queue.dart';
import '../theme/app_motion.dart';
import 'sync_event.dart';
import 'sync_state.dart';

/// Reconciles the durable queue with what the user is looking at.
///
/// **Bloc, and this is the one place it is earned** (`ARCHITECTURE.md` §3). Four
/// independent asynchronous sources fan in — the queue's own change stream, the
/// advisory link signal, app-lifecycle resume, and local actions — and the
/// component must behave *differently* depending on which arrived. A queue
/// change re-reads and schedules nothing; a resume re-reads **and** reconciles.
/// That difference is the design, and a sealed event type is what makes it
/// legible and separately testable.
///
/// **What it is not.** It holds no database correctness: every invariant lives
/// in the DAO and the pure policies, and this reads what they decided. It runs
/// no retry timer — the OS owns scheduling, and an app-side timer would fight
/// the backoff that already exists (`RS-04`). It never gates an upload on the
/// link signal (`FLT-SYNC-011`).
///
/// **`FLT-SYNC-012` and `RS-11` close here.** On startup and on resume, if
/// durable uploadable work exists, a drain is requested. Idempotent,
/// non-throwing, and safe to repeat: a request may be refused by the platform,
/// and the next reconciliation asks again — which is exactly the residual risk
/// F1 recorded and had no foreground in which to close.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  /// Creates the bloc.
  ///
  /// [queueProcessor] is optional. When present, a reconciliation also drains in
  /// the foreground, so a user watching the screen sees progress rather than
  /// waiting on OS scheduling. That is safe **only** because the claim is
  /// atomic: the foreground pass and the worker are two claimants of one queue,
  /// not a primary and a fallback (`SYNC_ENGINE.md` §8).
  SyncBloc({
    required UploadQueue queue,
    required SyncScheduler scheduler,
    required ConnectivityPort connectivity,
    QueueProcessor? queueProcessor,
    ConnectivityDrainTrigger? drainTrigger,
    Duration completionHold = AppMotion.completionHold,
  }) : _queue = queue,
       _scheduler = scheduler,
       _connectivity = connectivity,
       _processor = queueProcessor,
       _drainTrigger = drainTrigger,
       _completionHold = completionHold,
       super(const SyncState()) {
    on<SyncStarted>(_onStarted);
    on<SyncQueueChanged>(_onQueueChanged);
    on<SyncLinkChanged>(_onLinkChanged);
    on<SyncResumed>(_onResumed);
    on<SyncBatchFinished>(_onBatchFinished);
    on<SyncDrainRequested>(_onDrainRequested);
    on<SyncCompletionExpired>(_onCompletionExpired);
  }

  final UploadQueue _queue;
  final SyncScheduler _scheduler;
  final ConnectivityPort _connectivity;
  final QueueProcessor? _processor;

  /// The F1 accelerator, reused rather than reimplemented.
  ///
  /// It owns the *platform* request on a regained link; this bloc owns the
  /// foreground pass and the copy on screen. Splitting them that way means one
  /// signal is not registered with the scheduler twice, and the component that
  /// was already tested against that behaviour stays the one doing it.
  final ConnectivityDrainTrigger? _drainTrigger;

  final Duration _completionHold;

  StreamSubscription<void>? _queueSubscription;
  StreamSubscription<bool>? _linkSubscription;

  /// Batch ids seen with outstanding work, so a batch that was *already*
  /// complete before this session started is never announced as a fresh success.
  final Set<String> _seenOutstanding = <String>{};

  /// Completed batches inside their "Synced" hold, and the timers ending it.
  final Map<String, Timer> _completionTimers = <String, Timer>{};

  /// Completed batches whose hold has elapsed.
  final Set<String> _collapsedBatches = <String>{};

  bool _draining = false;

  Future<void> _onStarted(SyncStarted event, Emitter<SyncState> emit) async {
    _queueSubscription ??= _queue.changes.listen((void _) {
      add(const SyncQueueChanged());
    });
    _linkSubscription ??= _connectivity.linkChanges.listen((bool hasLink) {
      add(SyncLinkChanged(hasLink));
    });
    await _drainTrigger?.start();

    emit(state.copyWith(status: SyncStatus.loading, hasLink: await _link()));
    await _reconcile(emit);
  }

  Future<void> _onQueueChanged(
    SyncQueueChanged event,
    Emitter<SyncState> emit,
  ) async {
    // Re-read only. A queue change is caused as often by a `DRAFT` capture as by
    // anything uploadable, and waking the OS for a draft is the mistake
    // `ADR-F21` exists to prevent.
    await _publishSnapshot(emit);
  }

  Future<void> _onLinkChanged(
    SyncLinkChanged event,
    Emitter<SyncState> emit,
  ) async {
    final bool regained = event.hasLink && !state.hasLink;
    emit(state.copyWith(hasLink: event.hasLink));
    if (!regained) {
      return;
    }
    // The platform request belongs to `ConnectivityDrainTrigger`, which is
    // already listening to the same stream. What is added here is the
    // *foreground* pass, so a user watching when the link returns sees it move.
    await _drainInForeground(emit);
    await _publishSnapshot(emit);
  }

  Future<void> _onResumed(SyncResumed event, Emitter<SyncState> emit) =>
      _reconcile(emit);

  Future<void> _onBatchFinished(
    SyncBatchFinished event,
    Emitter<SyncState> emit,
  ) async {
    // `FinishBatch` has already asked the platform — asking again would put a
    // second node on the chain for one user action. What is left is to show the
    // new work and, while the user is here, start moving it.
    await _publishSnapshot(emit);
    await _drainInForeground(emit);
    await _publishSnapshot(emit);
  }

  Future<void> _onDrainRequested(
    SyncDrainRequested event,
    Emitter<SyncState> emit,
  ) => _reconcile(emit);

  Future<void> _onCompletionExpired(
    SyncCompletionExpired event,
    Emitter<SyncState> emit,
  ) async {
    _completionTimers.remove(event.batchId)?.cancel();
    _collapsedBatches.add(event.batchId);
    await _publishSnapshot(emit);
  }

  /// Snapshot, then ask for a drain if — and only if — there is uploadable work.
  ///
  /// Requesting unconditionally would wake a worker for an empty queue on every
  /// launch and every resume.
  Future<void> _reconcile(Emitter<SyncState> emit) async {
    final _Snapshot snapshot = await _snapshot();
    _emitSnapshot(emit, snapshot);
    if (snapshot.uploadableCount == 0) {
      return;
    }

    // Never throws, by the port's contract, and a refusal here is deliberately
    // survivable: the batch stays queued, its images stay pending, and the next
    // resume or link change asks again. A lost wake-up costs a delay, never a
    // photograph (`RS-11`).
    final SchedulingOutcome outcome = await _scheduler.scheduleDrain();
    if (emit.isDone) {
      return;
    }
    emit(state.copyWith(lastScheduling: outcome));

    await _drainInForeground(emit);
    await _publishSnapshot(emit);
  }

  /// Runs one drain pass while the app is visible.
  ///
  /// One pass per trigger, never a loop. The pass is already bounded internally
  /// by an item and a time budget; chaining passes here would be an app-side
  /// schedule competing with WorkManager's (`RS-04`).
  Future<void> _drainInForeground(Emitter<SyncState> emit) async {
    final QueueProcessor? processor = _processor;
    if (processor == null || _draining) {
      return;
    }
    _draining = true;
    if (!emit.isDone) {
      emit(state.copyWith(isDraining: true));
    }
    try {
      // `drain` does not throw for an ordinary failure; this guard is for the
      // extraordinary one, and it must not take the screen down with it.
      await processor.drain();
    } catch (_) {
      // Nothing was lost: every transition the pass made was committed as it
      // went, and anything it did not reach is still queued.
    } finally {
      _draining = false;
      if (!emit.isDone) {
        emit(state.copyWith(isDraining: false));
      }
    }
  }

  Future<void> _publishSnapshot(Emitter<SyncState> emit) async {
    final _Snapshot snapshot = await _snapshot();
    _emitSnapshot(emit, snapshot);
  }

  void _emitSnapshot(Emitter<SyncState> emit, _Snapshot snapshot) {
    if (emit.isDone) {
      return;
    }
    emit(state.copyWith(status: SyncStatus.ready, batches: snapshot.batches));
  }

  /// Reads every handed-over batch and its images.
  ///
  /// Deliberately a full re-read rather than an incremental patch. The queue has
  /// **two** writers in two isolates, so a model maintained by applying local
  /// deltas would drift from the database the moment the worker ran. Re-reading
  /// is the only view that cannot be wrong.
  Future<_Snapshot> _snapshot() async {
    final List<CaptureBatch> all;
    try {
      all = await _queue.allBatches();
    } catch (_) {
      // A failed read is not an empty queue, and rendering it as one would tell
      // the user their photographs are gone on the strength of one query.
      return _Snapshot(state.batches, 0);
    }

    final List<SyncBatchView> views = <SyncBatchView>[];
    int uploadable = 0;

    for (final CaptureBatch batch in all) {
      if (batch.status == BatchStatus.draft) {
        // Not handed over yet, so not a pending upload. The camera owns it.
        continue;
      }

      final List<QueuedImage> images;
      try {
        images = await _queue.imagesInBatch(batch.id);
      } catch (_) {
        continue;
      }

      for (final QueuedImage image in images) {
        if (image.status == ImageStatus.pending ||
            image.status == ImageStatus.uploading) {
          uploadable++;
        }
      }

      final SyncBatchView view = SyncBatchView(batch: batch, images: images);
      if (view.outstandingCount > 0) {
        _seenOutstanding.add(batch.id);
        views.add(view);
        continue;
      }

      if (_shouldHoldCompleted(batch.id)) {
        views.add(view);
      }
    }

    return _Snapshot(List<SyncBatchView>.unmodifiable(views), uploadable);
  }

  /// Whether a finished batch is still inside its "Synced" hold.
  ///
  /// A batch that was already complete when this session started is not shown at
  /// all: that success has been seen, and a queue screen listing every batch ever
  /// uploaded stops being a queue. A batch that completes **while the user is
  /// here** holds briefly, so the success is witnessed rather than glimpsed as a
  /// row disappearing (`UX_SPEC.md` §4).
  bool _shouldHoldCompleted(String batchId) {
    if (!_seenOutstanding.contains(batchId)) {
      return false;
    }
    if (_collapsedBatches.contains(batchId)) {
      return false;
    }
    _completionTimers.putIfAbsent(
      batchId,
      () => Timer(_completionHold, () {
        if (!isClosed) {
          add(SyncCompletionExpired(batchId));
        }
      }),
    );
    return true;
  }

  Future<bool> _link() async {
    try {
      return await _connectivity.hasLink();
    } catch (_) {
      // An unavailable connectivity plugin must not stop the screen rendering.
      // Assuming a link is the safe default: it changes only the copy, and the
      // upload attempt remains the authority either way.
      return true;
    }
  }

  @override
  Future<void> close() async {
    for (final Timer timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    await _queueSubscription?.cancel();
    await _linkSubscription?.cancel();
    await _drainTrigger?.stop();
    return super.close();
  }
}

class _Snapshot {
  const _Snapshot(this.batches, this.uploadableCount);

  final List<SyncBatchView> batches;
  final int uploadableCount;
}
