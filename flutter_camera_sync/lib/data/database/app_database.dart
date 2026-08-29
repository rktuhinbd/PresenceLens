import 'package:sqflite/sqflite.dart';

/// One schema step, keyed in [AppDatabase.migrations] by the version it
/// upgrades **to**.
typedef MigrationStep = Future<void> Function(Database db);

/// Opens the queue database and owns its schema.
///
/// SQLite holds **metadata only**. Image bytes are on the filesystem
/// ([root ADR-005], `ADR-F02`, `RESEARCH.md` `FR-09`): blobs here would inflate
/// the database, make every queue read expensive, and collide with sqflite's
/// exclusive-transaction model.
abstract final class AppDatabase {
  /// Current schema version.
  static const int schemaVersion = 1;

  /// File name inside the app's databases directory.
  static const String fileName = 'presence_lens_capture.db';

  /// Table of capture batches.
  static const String batchesTable = 'capture_batches';

  /// Table of queued images.
  static const String imagesTable = 'queued_images';

  /// Opens (creating or migrating as needed) the database at [path].
  ///
  /// [databaseFactory] is injected so the same code runs against the platform
  /// engine on a device and against the real SQLite engine on the host under
  /// `flutter test` (`sqflite_common_ffi`). The alternative — a hand-written
  /// in-memory fake — would happily pass a claim implementation that is not
  /// actually atomic, which is the one bug that matters most here.
  /// [singleInstance] must stay `true` in the app: within one isolate, sqflite
  /// then hands back the same connection for the same path instead of opening a
  /// second one. Tests set it to `false` to obtain *genuinely independent*
  /// connections to one file, which is what reproduces on the host what the UI
  /// isolate and the WorkManager isolate do on a device — and without that, a
  /// contention test would be two calls on one connection and would prove
  /// nothing.
  static Future<Database> open({
    required DatabaseFactory databaseFactory,
    required String path,
    bool singleInstance = true,
  }) {
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: configure,
        onCreate: createSchema,
        onUpgrade: migrate,
        onDowngrade: refuseDowngrade,
        singleInstance: singleInstance,
      ),
    );
  }

  /// Per-connection settings, applied before any other statement.
  static Future<void> configure(Database db) async {
    // Off by default in SQLite, so the queued_images -> capture_batches
    // constraint and its ON DELETE CASCADE would otherwise be decoration.
    await db.execute('PRAGMA foreign_keys = ON');

    // Two connections exist by design (the UI isolate and the WorkManager
    // isolate), so a write can genuinely find the database locked. Waiting
    // briefly is correct; failing instantly would surface as a spurious
    // "database is locked" error on a perfectly ordinary drain.
    await db.execute('PRAGMA busy_timeout = 5000');
  }

  /// Builds schema v1.
  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
CREATE TABLE $batchesTable (
  id          TEXT    PRIMARY KEY,
  created_at  INTEGER NOT NULL,
  queued_at   INTEGER,
  status      TEXT    NOT NULL,
  image_count INTEGER NOT NULL DEFAULT 0
)''');

    await db.execute('''
CREATE TABLE $imagesTable (
  id              TEXT    PRIMARY KEY,
  batch_id        TEXT    NOT NULL,
  local_path      TEXT    NOT NULL,
  captured_at     INTEGER NOT NULL,
  status          TEXT    NOT NULL,
  attempt_count   INTEGER NOT NULL DEFAULT 0,
  last_attempt_at INTEGER,
  claimed_at      INTEGER,
  last_failure    TEXT,
  FOREIGN KEY (batch_id) REFERENCES $batchesTable (id) ON DELETE CASCADE
)''');

    // Serves the claim query's candidate selection. Without it every drain
    // scans the whole table, which is the one query that runs most often.
    await db.execute('''
CREATE INDEX idx_queued_images_work
  ON $imagesTable (status, captured_at)''');

    // Serves batch membership: the Pending Uploads list reads per batch.
    await db.execute('''
CREATE INDEX idx_queued_images_batch
  ON $imagesTable (batch_id)''');
  }

  /// Every registered schema step.
  ///
  /// Empty at v1, which is correct — there is no history to migrate. It exists
  /// as a *registry* rather than as an empty method body because of the failure
  /// it prevents: sqflite records the new version whenever `onUpgrade`
  /// completes, so an empty callback would let someone bump [schemaVersion],
  /// ship it, and have every existing install silently record the new version
  /// against the old tables. The next query then fails on a device, not in CI.
  ///
  /// Adding a step here is the only way to make a version bump succeed.
  static const Map<int, MigrationStep> migrations = <int, MigrationStep>{};

  /// Migrates an existing database from [oldVersion] to [newVersion].
  ///
  /// Applies each registered step in order, and **refuses** a version bump that
  /// has no step: better a loud, reproducible failure at open time than a
  /// database whose recorded version is a lie.
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (int target = oldVersion + 1; target <= newVersion; target++) {
      final MigrationStep? step = migrations[target];
      if (step == null) {
        throw StateError(
          'No migration registered for schema v${target - 1} -> v$target. '
          'Register one in AppDatabase.migrations before raising '
          'AppDatabase.schemaVersion, or an existing install will record the '
          'new version against the old tables.',
        );
      }
      await step(db);
    }
  }

  /// Refuses to open a database newer than this build understands.
  ///
  /// The alternative sqflite offers is `onDatabaseDowngradeDelete`, which
  /// deletes the user's data. For a queue whose entire purpose is not losing
  /// captures, deleting it to resolve a version mismatch is the one outcome
  /// worse than failing to open.
  static Future<void> refuseDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'The stored database is schema v$oldVersion, newer than the v$newVersion '
      'this build supports. Refusing to open it: downgrading would mean '
      'discarding captures that have not been uploaded.',
    );
  }
}
