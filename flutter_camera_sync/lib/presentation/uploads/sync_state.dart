import 'package:equatable/equatable.dart';

import '../../domain/entities/batch_status.dart';
import '../../domain/entities/capture_batch.dart';
import '../../domain/entities/image_status.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/ports/sync_scheduler.dart';

/// One batch as the Upload Manager renders it: the batch row and its images.
///
/// Progress here is **count-based and read from the rows** — `n of m` — never a
/// byte percentage. The app has no byte-level progress to report and inventing
/// one would be a fabricated measurement on a screen whose entire purpose is to
/// be believed (`UX_SPEC.md` §4).
class SyncBatchView extends Equatable {
  /// Creates a batch view.
  const SyncBatchView({required this.batch, required this.images});

  /// The batch itself.
  final CaptureBatch batch;

  /// Its images, in capture order.
  final List<QueuedImage> images;

  /// The batch id.
  String get id => batch.id;

  /// How many images are confirmed uploaded.
  int get uploadedCount =>
      images.where((QueuedImage i) => i.status == ImageStatus.uploaded).length;

  /// How many images the batch holds.
  int get totalCount => images.length;

  /// How many images still owe an upload.
  int get outstandingCount =>
      images.where((QueuedImage i) => i.status.isOutstanding).length;

  /// Whether every image in the batch is confirmed uploaded.
  bool get isSynced =>
      batch.status == BatchStatus.completed ||
      (totalCount > 0 && uploadedCount == totalCount);

  @override
  List<Object?> get props => <Object?>[batch, images];
}

/// How far the sync presentation has got.
enum SyncStatus {
  /// Nothing has been read yet.
  initial,

  /// The first snapshot is being taken.
  loading,

  /// A snapshot is on screen.
  ready,
}

/// What the Upload Manager and the camera's chrome render from.
///
/// **This is a view of the queue, not the queue.** Nothing here decides whether
/// an upload may be attempted, and nothing here is authoritative about
/// durability — the database is. It exists so a screen can be built from one
/// value rather than from four subscriptions (`ARCHITECTURE.md` §3).
class SyncState extends Equatable {
  /// Creates a sync state.
  const SyncState({
    this.status = SyncStatus.initial,
    this.batches = const <SyncBatchView>[],
    this.hasLink = true,
    this.isDraining = false,
    this.lastScheduling,
  });

  /// How far the presentation has got.
  final SyncStatus status;

  /// Handed-over batches, newest first. Open drafts are not here: a draft has
  /// not been handed to the sync engine, so it is not a pending upload.
  final List<SyncBatchView> batches;

  /// The **advisory** link signal (`ADR-F05`).
  ///
  /// It may change the copy on screen and it may prompt an earlier attempt. It
  /// never gates an upload, and the uploader's own outcome remains the only
  /// authority on whether one worked (`FLT-SYNC-011`).
  final bool hasLink;

  /// Whether a foreground drain pass is running.
  final bool isDraining;

  /// What the platform said about the most recent drain request.
  final SchedulingOutcome? lastScheduling;

  /// How many images across every batch still owe an upload.
  int get pendingCount =>
      batches.fold(0, (int sum, SyncBatchView b) => sum + b.outstandingCount);

  /// Whether anything is still owed.
  bool get hasPendingWork => pendingCount > 0;

  /// Whether there is nothing at all to show.
  bool get isEmpty => batches.isEmpty;

  /// A copy with the given fields replaced.
  SyncState copyWith({
    SyncStatus? status,
    List<SyncBatchView>? batches,
    bool? hasLink,
    bool? isDraining,
    SchedulingOutcome? lastScheduling,
  }) {
    return SyncState(
      status: status ?? this.status,
      batches: batches ?? this.batches,
      hasLink: hasLink ?? this.hasLink,
      isDraining: isDraining ?? this.isDraining,
      lastScheduling: lastScheduling ?? this.lastScheduling,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    batches,
    hasLink,
    isDraining,
    lastScheduling,
  ];
}
