import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/database/app_database.dart';
import 'package:presence_lens_capture/data/database/upload_queue_dao.dart';
import 'package:presence_lens_capture/domain/entities/image_status.dart';
import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A real SQLite database on a real temporary file, for the `DATA` tier.
///
/// The file is real rather than in-memory on purpose: several of these tests
/// open **more than one connection to the same database**, which is the only
/// way to reproduce on the host what two isolates do on a device.
class QueueHarness {
  QueueHarness._(this.directory, this.databasePath);

  /// Prepares a fresh database directory and opens the first connection.
  static Future<QueueHarness> create() async {
    sqfliteFfiInit();
    final Directory directory = await Directory.systemTemp.createTemp(
      'presencelens_queue_',
    );
    final QueueHarness harness = QueueHarness._(
      directory,
      p.join(directory.path, AppDatabase.fileName),
    );
    // Opened first and on its own, so the schema is created exactly once before
    // any contending connection arrives.
    harness.primary = await harness.openConnection();
    harness.dao = UploadQueueDao(harness.primary);
    return harness;
  }

  /// The temporary directory holding the database file.
  final Directory directory;

  /// Absolute path of the database file.
  final String databasePath;

  /// The first connection, used by most tests.
  late final Database primary;

  /// A DAO over [primary].
  late final UploadQueueDao dao;

  final List<Database> _connections = <Database>[];
  final List<UploadQueueDao> _daos = <UploadQueueDao>[];

  /// Opens an additional, genuinely independent connection to the same file.
  Future<Database> openConnection() async {
    final Database db = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      path: databasePath,
      singleInstance: false,
    );
    _connections.add(db);
    return db;
  }

  /// A DAO over its own private connection — one simulated isolate.
  Future<UploadQueueDao> independentDao() async {
    final UploadQueueDao dao = UploadQueueDao(await openConnection());
    _daos.add(dao);
    return dao;
  }

  /// Closes everything and removes the temporary directory.
  Future<void> dispose() async {
    await dao.close();
    for (final UploadQueueDao d in _daos) {
      await d.close();
    }
    for (final Database db in _connections) {
      try {
        await db.close();
      } catch (_) {
        // A test may legitimately have closed its own connection already — the
        // worker entry point closes the layer it built, for instance.
      }
    }
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  /// Seeds a queued batch holding [count] pending images.
  ///
  /// Capture times are one minute apart in ascending order, so ordering
  /// assertions are unambiguous.
  Future<List<QueuedImage>> seedQueuedBatch({
    required String batchId,
    required int count,
    DateTime? firstCapturedAt,
  }) async {
    final DateTime base = firstCapturedAt ?? DateTime.utc(2026, 8, 29, 9);
    await dao.createDraftBatch(id: batchId, createdAt: base);
    final List<QueuedImage> images = <QueuedImage>[];
    for (int i = 0; i < count; i++) {
      final QueuedImage image = QueuedImage(
        id: '$batchId-image-$i',
        batchId: batchId,
        localPath: p.join(directory.path, 'captures', batchId, '$i.jpg'),
        capturedAt: base.add(Duration(minutes: i)),
        status: ImageStatus.draft,
      );
      await dao.addCapture(image);
      images.add(image);
    }
    await dao.enqueueBatch(
      batchId,
      queuedAt: base.add(const Duration(hours: 1)),
    );
    return images;
  }

  /// The raw status string stored for [imageId].
  Future<String> rawStatusOf(String imageId) async {
    final List<Map<String, Object?>> rows = await primary.query(
      AppDatabase.imagesTable,
      columns: <String>['status'],
      where: 'id = ?',
      whereArgs: <Object?>[imageId],
    );
    return rows.single['status']! as String;
  }

  /// How many rows currently hold [status].
  Future<int> countWithStatus(ImageStatus status) async {
    final List<Map<String, Object?>> rows = await primary.rawQuery(
      'SELECT COUNT(*) AS c FROM ${AppDatabase.imagesTable} WHERE status = ?',
      <Object?>[status.wireName],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
