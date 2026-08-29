import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/batch_status.dart';
import '../../domain/entities/capture_batch.dart';
import '../../domain/entities/failure_category.dart';
import '../../domain/entities/image_status.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/policies/batch_policy.dart';
import '../../domain/ports/upload_queue.dart';
import 'app_database.dart';

/// SQLite implementation of the durable upload queue.
///
/// The load-bearing method is [claimNext]. Everything else here is ordinary
/// persistence; that one is what stops two isolates uploading the same image.
class UploadQueueDao implements UploadQueue {
  /// Wraps an already-open [database].
  UploadQueueDao(
    Database database, {
    BatchPolicy batchPolicy = const BatchPolicy(),
  }) : _db = database,
       _batchPolicy = batchPolicy;

  /// How many candidates one [claimNext] call will try before giving up.
  ///
  /// A losing claimant has not run out of work — the row it wanted was taken,
  /// but another may be free — so it looks again. The bound exists so a
  /// pathological race cannot become an unbounded spin inside a background
  /// worker with a limited execution window. Five is far beyond the two
  /// claimants this app actually has.
  static const int maxClaimAttempts = 5;

  final Database _db;
  final BatchPolicy _batchPolicy;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  // ----------------------------------------------------------------- batches

  @override
  Future<CaptureBatch?> openDraftBatch() async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppDatabase.batchesTable,
      where: 'status = ?',
      whereArgs: <Object?>[BatchStatus.draft.wireName],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : _batchFrom(rows.first);
  }

  @override
  Future<CaptureBatch> createDraftBatch({
    required String id,
    required DateTime createdAt,
  }) async {
    // Read-then-insert, deliberately without a transaction or a UNIQUE index.
    // Draft batches have a single creator — the foreground capture flow — so
    // there is no second writer to race with. Contrast the *claim*, which has
    // two writers by design and is therefore enforced in SQL (`ADR-F20`).
    final bool hasOpenDraft = await openDraftBatch() != null;
    if (!_batchPolicy.canOpenBatch(hasOpenDraft: hasOpenDraft)) {
      throw StateError(
        'A draft batch is already open; finish it before opening another.',
      );
    }
    final CaptureBatch batch = CaptureBatch(
      id: id,
      createdAt: createdAt.toUtc(),
      status: BatchStatus.draft,
    );
    await _db.insert(AppDatabase.batchesTable, _batchToRow(batch));
    _notify();
    return batch;
  }

  @override
  Future<CaptureBatch> enqueueBatch(
    String batchId, {
    required DateTime queuedAt,
  }) async {
    final CaptureBatch? existing = await batchById(batchId);
    if (existing == null) {
      throw StateError('No such batch: $batchId');
    }
    final EnqueueRefusal? refusal = _batchPolicy.refuseEnqueue(existing);
    if (refusal != null) {
      throw StateError(refusal.message);
    }

    // One transaction, so a crash can never expose a queued batch holding draft
    // images, or a draft batch holding pending ones (invariant I2). No network
    // is involved: finishing a batch is a local durable act (`ADR-F14`).
    await _db.transaction((Transaction txn) async {
      await txn.update(
        AppDatabase.imagesTable,
        <String, Object?>{'status': ImageStatus.pending.wireName},
        where: 'batch_id = ? AND status = ?',
        whereArgs: <Object?>[batchId, ImageStatus.draft.wireName],
      );
      await txn.update(
        AppDatabase.batchesTable,
        <String, Object?>{
          'status': BatchStatus.queued.wireName,
          'queued_at': queuedAt.toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: <Object?>[batchId, BatchStatus.draft.wireName],
      );
    });

    _notify();
    final CaptureBatch? updated = await batchById(batchId);
    return updated!;
  }

  @override
  Future<CaptureBatch?> batchById(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppDatabase.batchesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : _batchFrom(rows.first);
  }

  @override
  Future<List<CaptureBatch>> allBatches() async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppDatabase.batchesTable,
      orderBy: 'created_at DESC',
    );
    return rows.map(_batchFrom).toList(growable: false);
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    // The images go with it through ON DELETE CASCADE. Rows first, files after
    // (`DATA_MODEL.md` §6): a crash between the two leaves an orphan file, not
    // a queue row pointing at nothing.
    await _db.delete(
      AppDatabase.batchesTable,
      where: 'id = ?',
      whereArgs: <Object?>[batchId],
    );
    _notify();
  }

  // ------------------------------------------------------------------ images

  @override
  Future<void> addCapture(QueuedImage image) async {
    await _db.transaction((Transaction txn) async {
      await txn.insert(AppDatabase.imagesTable, _imageToRow(image));
      // Same transaction as the insert, which is the whole reason the
      // denormalised count is allowed to exist (invariant I9).
      await txn.rawUpdate(
        'UPDATE ${AppDatabase.batchesTable} '
        'SET image_count = image_count + 1 WHERE id = ?',
        <Object?>[image.batchId],
      );
    });
    _notify();
  }

  @override
  Future<QueuedImage?> imageById(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppDatabase.imagesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : _imageFrom(rows.first);
  }

  @override
  Future<List<QueuedImage>> imagesInBatch(String batchId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      AppDatabase.imagesTable,
      where: 'batch_id = ?',
      whereArgs: <Object?>[batchId],
      orderBy: 'captured_at ASC, id ASC',
    );
    return rows.map(_imageFrom).toList(growable: false);
  }

  @override
  Future<int> outstandingCount() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${AppDatabase.imagesTable} '
      'WHERE status IN (?, ?, ?)',
      <Object?>[
        ImageStatus.draft.wireName,
        ImageStatus.pending.wireName,
        ImageStatus.uploading.wireName,
      ],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // --------------------------------------------------------------- the claim

  @override
  Future<QueuedImage?> claimNext({
    required DateTime now,
    required DateTime leaseCutoff,
    Set<String> skip = const <String>{},
  }) async {
    final int nowMs = now.toUtc().millisecondsSinceEpoch;
    final int cutoffMs = leaseCutoff.toUtc().millisecondsSinceEpoch;

    for (int attempt = 0; attempt < maxClaimAttempts; attempt++) {
      final String? candidateId = await _nextClaimableId(cutoffMs, skip);
      if (candidateId == null) {
        return null;
      }

      // THE claim. A single conditional UPDATE whose WHERE clause re-tests the
      // precondition, so the statement *is* the lock: if two processors picked
      // the same row, only the first matches and the second affects zero rows.
      // It is deliberately not wrapped in a transaction — the statement already
      // is one, and a deferred read-then-write transaction held across two
      // connections would add a lock-upgrade deadlock to defend against without
      // making anything safer.
      //
      // No Dart mutex could do this job. The UI isolate and the WorkManager
      // isolate share no memory, only this file (`ADR-F04`, `FR-08`).
      final int changed = await _db.rawUpdate(
        'UPDATE ${AppDatabase.imagesTable} '
        'SET status = ?, claimed_at = ? '
        'WHERE id = ? '
        'AND (status = ? OR (status = ? AND claimed_at < ?))',
        <Object?>[
          ImageStatus.uploading.wireName,
          nowMs,
          candidateId,
          ImageStatus.pending.wireName,
          ImageStatus.uploading.wireName,
          cutoffMs,
        ],
      );

      if (changed == 1) {
        _notify();
        return imageById(candidateId);
      }
      // Lost this row to another claimant. Another row may still be free, so
      // look again rather than reporting an empty queue.
    }
    return null;
  }

  /// The oldest capture that is either pending or holding an expired lease.
  ///
  /// The stale branch is what makes process-death recovery a property of the
  /// claim itself, rather than of a startup sweep somebody has to remember to
  /// call (`FLT-SYNC-009`). Ordering is `captured_at` then `id`, so the queue
  /// drains oldest-capture-first across every batch, deterministically
  /// (`FLT-SYNC-013`).
  Future<String?> _nextClaimableId(int cutoffMs, Set<String> skip) async {
    final String exclusion = skip.isEmpty
        ? ''
        : 'AND id NOT IN (${List<String>.filled(skip.length, '?').join(', ')}) ';

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM ${AppDatabase.imagesTable} '
      'WHERE (status = ? OR (status = ? AND claimed_at < ?)) '
      '$exclusion'
      'ORDER BY captured_at ASC, id ASC LIMIT 1',
      <Object?>[
        ImageStatus.pending.wireName,
        ImageStatus.uploading.wireName,
        cutoffMs,
        ...skip,
      ],
    );
    return rows.isEmpty ? null : rows.first['id']! as String;
  }

  // --------------------------------------------------------- outcome records

  @override
  Future<bool> recordSuccess(String imageId, {required DateTime now}) async {
    final int nowMs = now.toUtc().millisecondsSinceEpoch;
    bool changed = false;

    await _db.transaction((Transaction txn) async {
      // Guarded on UPLOADING, so success is recordable only from a live claim.
      // A repeat affects zero rows and cannot re-complete a batch (invariant
      // I7), and a terminal row can never be overwritten by a late caller.
      final int rows = await txn.update(
        AppDatabase.imagesTable,
        <String, Object?>{
          'status': ImageStatus.uploaded.wireName,
          'claimed_at': null,
          'last_attempt_at': nowMs,
          'last_failure': null,
        },
        where: 'id = ? AND status = ?',
        whereArgs: <Object?>[imageId, ImageStatus.uploading.wireName],
      );
      if (rows == 0) {
        return;
      }
      changed = true;
      await _completeBatchIfDone(txn, imageId);
    });

    if (changed) {
      _notify();
    }
    return changed;
  }

  @override
  Future<bool> recordRetryableFailure(
    String imageId, {
    required FailureCategory category,
    required DateTime now,
  }) async {
    // Back to PENDING, attempt count up, row and file untouched. This single
    // transition is what makes "the images must remain in the local queue" true
    // (`FLT-SYNC-003`, invariant I6). There is no separate resting state for
    // failures, and no attempt ceiling that would discard the capture
    // (`ADR-F12`).
    final int rows = await _db.rawUpdate(
      'UPDATE ${AppDatabase.imagesTable} '
      'SET status = ?, attempt_count = attempt_count + 1, '
      'last_attempt_at = ?, last_failure = ?, claimed_at = NULL '
      'WHERE id = ? AND status = ?',
      <Object?>[
        ImageStatus.pending.wireName,
        now.toUtc().millisecondsSinceEpoch,
        category.wireName,
        imageId,
        ImageStatus.uploading.wireName,
      ],
    );
    if (rows > 0) {
      _notify();
    }
    return rows > 0;
  }

  @override
  Future<bool> recordPermanentFailure(
    String imageId, {
    required FailureCategory category,
    required DateTime now,
  }) async {
    final int rows = await _db.rawUpdate(
      'UPDATE ${AppDatabase.imagesTable} '
      'SET status = ?, attempt_count = attempt_count + 1, '
      'last_attempt_at = ?, last_failure = ?, claimed_at = NULL '
      'WHERE id = ? AND status = ?',
      <Object?>[
        ImageStatus.failedPermanent.wireName,
        now.toUtc().millisecondsSinceEpoch,
        category.wireName,
        imageId,
        ImageStatus.uploading.wireName,
      ],
    );
    if (rows > 0) {
      _notify();
    }
    return rows > 0;
  }

  /// Promotes the batch owning [imageId] to completed when nothing is left.
  ///
  /// Evaluated from the rows themselves, inside the same transaction as the
  /// success that might have finished it, so it is safe to re-evaluate and
  /// cannot double-count. A batch holding a permanently failed image never
  /// completes: it was not fully delivered, and saying otherwise in the UI
  /// would be untrue.
  Future<void> _completeBatchIfDone(Transaction txn, String imageId) async {
    final List<Map<String, Object?>> owner = await txn.query(
      AppDatabase.imagesTable,
      columns: <String>['batch_id'],
      where: 'id = ?',
      whereArgs: <Object?>[imageId],
      limit: 1,
    );
    if (owner.isEmpty) {
      return;
    }
    final String batchId = owner.first['batch_id']! as String;

    final List<Map<String, Object?>> counts = await txn.rawQuery(
      'SELECT COUNT(*) AS total, '
      'SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS uploaded '
      'FROM ${AppDatabase.imagesTable} WHERE batch_id = ?',
      <Object?>[ImageStatus.uploaded.wireName, batchId],
    );
    final int total = (counts.first['total'] as int?) ?? 0;
    final int uploaded = (counts.first['uploaded'] as int?) ?? 0;

    if (!_batchPolicy.isComplete(imageCount: total, uploadedCount: uploaded)) {
      return;
    }
    await txn.update(
      AppDatabase.batchesTable,
      <String, Object?>{'status': BatchStatus.completed.wireName},
      where: 'id = ? AND status = ?',
      whereArgs: <Object?>[batchId, BatchStatus.queued.wireName],
    );
  }

  /// Releases the change stream. The database itself is closed by its owner.
  Future<void> close() async {
    await _changes.close();
  }

  // -------------------------------------------------------------- conversion

  static Map<String, Object?> _batchToRow(CaptureBatch batch) =>
      <String, Object?>{
        'id': batch.id,
        'created_at': batch.createdAt.toUtc().millisecondsSinceEpoch,
        'queued_at': batch.queuedAt?.toUtc().millisecondsSinceEpoch,
        'status': batch.status.wireName,
        'image_count': batch.imageCount,
      };

  static CaptureBatch _batchFrom(Map<String, Object?> row) => CaptureBatch(
    id: row['id']! as String,
    createdAt: _utc(row['created_at']! as int),
    queuedAt: _utcOrNull(row['queued_at'] as int?),
    status: BatchStatus.fromWireName(row['status']! as String),
    imageCount: row['image_count']! as int,
  );

  static Map<String, Object?> _imageToRow(QueuedImage image) =>
      <String, Object?>{
        'id': image.id,
        'batch_id': image.batchId,
        'local_path': image.localPath,
        'captured_at': image.capturedAt.toUtc().millisecondsSinceEpoch,
        'status': image.status.wireName,
        'attempt_count': image.attemptCount,
        'last_attempt_at': image.lastAttemptAt?.toUtc().millisecondsSinceEpoch,
        'claimed_at': image.claimedAt?.toUtc().millisecondsSinceEpoch,
        'last_failure': image.lastFailure?.wireName,
      };

  static QueuedImage _imageFrom(Map<String, Object?> row) => QueuedImage(
    id: row['id']! as String,
    batchId: row['batch_id']! as String,
    localPath: row['local_path']! as String,
    capturedAt: _utc(row['captured_at']! as int),
    status: ImageStatus.fromWireName(row['status']! as String),
    attemptCount: row['attempt_count']! as int,
    lastAttemptAt: _utcOrNull(row['last_attempt_at'] as int?),
    claimedAt: _utcOrNull(row['claimed_at'] as int?),
    lastFailure: row['last_failure'] == null
        ? null
        : FailureCategory.fromWireName(row['last_failure']! as String),
  );

  static DateTime _utc(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

  static DateTime? _utcOrNull(int? millis) =>
      millis == null ? null : _utc(millis);
}
