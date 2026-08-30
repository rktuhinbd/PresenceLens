// DATA tier — schema, indices, referential integrity and migration
// (FLT-GEN-003, FLT-ERR-006).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:presence_lens_capture/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late Database db;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('presencelens_schema_');
    db = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      path: p.join(directory.path, AppDatabase.fileName),
    );
  });

  tearDown(() async {
    await db.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('opens at the declared schema version', () async {
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect(AppDatabase.schemaVersion, 1);
  });

  test('creates both tables', () async {
    final List<Map<String, Object?>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final Set<String> names = tables
        .map((Map<String, Object?> r) => r['name']! as String)
        .toSet();

    expect(names, contains(AppDatabase.batchesTable));
    expect(names, contains(AppDatabase.imagesTable));
  });

  test('creates the indices the claim query depends on', () async {
    // Without these the drain — the query that runs most often — is a full
    // table scan every time the worker wakes.
    final List<Map<String, Object?>> indices = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final Set<String> names = indices
        .map((Map<String, Object?> r) => r['name']! as String)
        .toSet();

    expect(names, contains('idx_queued_images_work'));
    expect(names, contains('idx_queued_images_batch'));
  });

  test('enforces foreign keys on this connection', () async {
    // Off by default in SQLite, which would silently make the cascade below
    // decoration rather than behaviour.
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'PRAGMA foreign_keys',
    );
    expect(rows.first.values.first, 1);
  });

  test('configures a five-second busy timeout on this connection', () async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'PRAGMA busy_timeout',
    );

    expect(rows.first.values.first, 5000);
  });

  test('uses the query API Android requires for busy_timeout', () {
    final String source = File(
      'lib/data/database/app_database.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("await db.rawQuery('PRAGMA busy_timeout = 5000');"),
    );
    expect(source, isNot(contains("db.execute('PRAGMA busy_timeout")));
  });

  test('rejects an image whose batch does not exist', () async {
    await expectLater(
      db.insert(AppDatabase.imagesTable, <String, Object?>{
        'id': 'orphan',
        'batch_id': 'nope',
        'local_path': '/tmp/orphan.jpg',
        'captured_at': 0,
        'status': 'PENDING',
        'attempt_count': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('deleting a batch cascades to its images', () async {
    await db.insert(AppDatabase.batchesTable, <String, Object?>{
      'id': 'b1',
      'created_at': 0,
      'status': 'DRAFT',
      'image_count': 1,
    });
    await db.insert(AppDatabase.imagesTable, <String, Object?>{
      'id': 'i1',
      'batch_id': 'b1',
      'local_path': '/tmp/i1.jpg',
      'captured_at': 0,
      'status': 'DRAFT',
      'attempt_count': 0,
    });

    await db.delete(
      AppDatabase.batchesTable,
      where: 'id = ?',
      whereArgs: <Object?>['b1'],
    );

    expect(await db.query(AppDatabase.imagesTable), isEmpty);
  });

  test('reopening an existing database keeps its data and version', () async {
    // The persistence claim the whole task rests on: the queue is still there
    // after the process that created it is gone (`FLT-SYNC-001`).
    await db.insert(AppDatabase.batchesTable, <String, Object?>{
      'id': 'survivor',
      'created_at': 42,
      'status': 'QUEUED',
      'image_count': 0,
    });
    await db.close();

    db = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      path: p.join(directory.path, AppDatabase.fileName),
    );

    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect(await db.query(AppDatabase.batchesTable), hasLength(1));
  });

  group('migration scaffold', () {
    test('is a no-op at v1, where there is no history to migrate', () async {
      await AppDatabase.migrate(db, 1, 1);
      expect(await db.query(AppDatabase.batchesTable), isEmpty);
    });

    test('registers no steps yet, which is correct at v1', () {
      expect(AppDatabase.migrations, isEmpty);
      expect(AppDatabase.schemaVersion, 1);
    });

    test('refuses a version bump that has no registered step', () async {
      // The failure this prevents: sqflite records the new version whenever
      // `onUpgrade` completes, so an empty callback would let someone raise
      // `schemaVersion`, ship it, and have every existing install record the
      // new version against the old tables. The first symptom would be a query
      // failing on a user's device rather than in CI.
      await expectLater(
        AppDatabase.migrate(db, 1, 2),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('No migration registered'),
          ),
        ),
      );
    });

    test('refuses to open a database newer than this build', () async {
      // The alternative sqflite offers deletes the user's data. For a queue
      // whose purpose is not losing captures, that is the one outcome worse
      // than failing to open.
      await expectLater(
        AppDatabase.refuseDowngrade(db, 2, 1),
        throwsA(isA<StateError>()),
      );
    });
  });
}
