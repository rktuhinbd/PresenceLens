import 'package:equatable/equatable.dart';

import '../../domain/entities/capture_batch.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/ports/sync_scheduler.dart';

/// Why a finish attempt did not produce a queued batch.
///
/// Two cases, because they lead to different sentences. Neither is a lost
/// photo: the batch is still `DRAFT` and every file is still on disk.
enum BatchActionFailure {
  /// There was nothing to finish.
  emptyBatch,

  /// The durable transaction itself was refused.
  finishFailed,
}

/// What the camera screen knows about the batch currently being filled.
///
/// Read from the database rather than tallied in memory, which is what makes it
/// survive process death: a `DRAFT` batch left behind by a killed app is found
/// again on the next launch with its true count (`DATA_MODEL.md` §5).
class BatchState extends Equatable {
  /// Creates a batch state.
  const BatchState({
    this.draft,
    this.latestCapture,
    this.isFinishing = false,
    this.lastScheduling,
    this.lastFinishedBatchId,
    this.failure,
  });

  /// The open draft batch, or `null` when none is open.
  final CaptureBatch? draft;

  /// The most recent capture in the open batch, for the thumbnail.
  final QueuedImage? latestCapture;

  /// Whether a finish is in flight, so the action cannot be pressed twice.
  final bool isFinishing;

  /// What the platform said about the drain request the last finish made.
  ///
  /// Carried so a scheduling failure is *visible* rather than merely survived
  /// (`RS-11`). It says nothing about whether the photos are safe — they are,
  /// unconditionally, because the transaction committed first.
  final SchedulingOutcome? lastScheduling;

  /// The batch the last successful finish closed.
  final String? lastFinishedBatchId;

  /// Why the last finish attempt failed, or `null`.
  final BatchActionFailure? failure;

  /// How many images the open batch holds.
  int get imageCount => draft?.imageCount ?? 0;

  /// Whether there is anything to finish.
  bool get hasCaptures => imageCount > 0;

  /// A copy with the given fields replaced.
  ///
  /// [draft], [latestCapture] and [failure] take explicit clear flags because
  /// `null` here means "unchanged", and all three genuinely need clearing —
  /// finishing a batch leaves no draft, and a new attempt must not inherit the
  /// previous attempt's error.
  BatchState copyWith({
    CaptureBatch? draft,
    QueuedImage? latestCapture,
    bool? isFinishing,
    SchedulingOutcome? lastScheduling,
    String? lastFinishedBatchId,
    BatchActionFailure? failure,
    bool clearDraft = false,
    bool clearLatestCapture = false,
    bool clearFailure = false,
  }) {
    return BatchState(
      draft: clearDraft ? null : (draft ?? this.draft),
      latestCapture: clearLatestCapture
          ? null
          : (latestCapture ?? this.latestCapture),
      isFinishing: isFinishing ?? this.isFinishing,
      lastScheduling: lastScheduling ?? this.lastScheduling,
      lastFinishedBatchId: lastFinishedBatchId ?? this.lastFinishedBatchId,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    draft,
    latestCapture,
    isFinishing,
    lastScheduling,
    lastFinishedBatchId,
    failure,
  ];
}
