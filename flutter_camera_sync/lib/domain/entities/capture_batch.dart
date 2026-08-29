import 'package:equatable/equatable.dart';

import 'batch_status.dart';

/// A group of images captured together and enqueued together.
///
/// "Batch" is not defined by the assessment (root `AMB-10`); the rule this app
/// applies is `FLT-BAT-004` — a batch opens on the first capture after the
/// previous batch was enqueued, and closes when the user finishes it.
class CaptureBatch extends Equatable {
  /// Creates a batch record.
  const CaptureBatch({
    required this.id,
    required this.createdAt,
    required this.status,
    this.queuedAt,
    this.imageCount = 0,
  });

  /// Client-generated identifier; the primary key.
  final String id;

  /// When the batch was opened. UTC.
  final DateTime createdAt;

  /// When the user finished the batch, or `null` while it is still a draft.
  final DateTime? queuedAt;

  /// Where the batch is in its lifecycle.
  final BatchStatus status;

  /// How many images belong to this batch.
  ///
  /// Denormalised on purpose (`DATA_MODEL.md` §5): the Pending Uploads list
  /// renders per batch, and recomputing a `COUNT(*)` on every queue change is
  /// wasteful for a value that only moves inside transactions that already hold
  /// the write lock. Invariant I9 is the price, and it is paid with a test.
  final int imageCount;

  /// A copy with the given fields replaced.
  CaptureBatch copyWith({
    DateTime? queuedAt,
    BatchStatus? status,
    int? imageCount,
  }) {
    return CaptureBatch(
      id: id,
      createdAt: createdAt,
      queuedAt: queuedAt ?? this.queuedAt,
      status: status ?? this.status,
      imageCount: imageCount ?? this.imageCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    createdAt,
    queuedAt,
    status,
    imageCount,
  ];
}
