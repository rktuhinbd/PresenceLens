import 'dart:async';

import 'package:presence_lens_capture/domain/entities/queued_image.dart';
import 'package:presence_lens_capture/domain/entities/upload_outcome.dart';
import 'package:presence_lens_capture/domain/ports/capture_store.dart';
import 'package:presence_lens_capture/domain/ports/clock.dart';
import 'package:presence_lens_capture/domain/ports/connectivity_port.dart';
import 'package:presence_lens_capture/domain/ports/id_generator.dart';
import 'package:presence_lens_capture/domain/ports/sync_scheduler.dart';
import 'package:presence_lens_capture/domain/ports/upload_api.dart';

/// A clock the test moves by hand, so ten-minute leases do not need ten-minute
/// tests.
class MutableClock implements Clock {
  MutableClock(this._now);

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Moves the clock forward.
  void advance(Duration by) => _now = _now.add(by);

  /// Sets the clock to an exact instant.
  set now(DateTime value) => _now = value;
}

/// Hands out predictable ids so paths and keys can be asserted.
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id'});

  /// Prefix of every generated id.
  final String prefix;

  int _next = 0;

  /// Every id handed out so far.
  final List<String> issued = <String>[];

  @override
  String newId() {
    final String id = '$prefix-${_next++}';
    issued.add(id);
    return id;
  }
}

/// An in-memory capture store with injectable faults.
class FakeCaptureStore implements CaptureStore {
  /// Durable paths this store believes exist.
  final Set<String> files = <String>{};

  /// Paths passed to [delete], in order.
  final List<String> deleted = <String>[];

  /// When set, [persist] throws this.
  CaptureStoreException? persistFailure;

  /// When true, [delete] throws.
  bool failDelete = false;

  /// When true, [exists] throws.
  bool failExists = false;

  @override
  Future<String> persist({
    required String batchId,
    required String imageId,
    required String sourcePath,
    String extension = 'jpg',
  }) async {
    final CaptureStoreException? failure = persistFailure;
    if (failure != null) {
      throw failure;
    }
    final String path = 'durable/$batchId/$imageId.$extension';
    files.add(path);
    return path;
  }

  @override
  Future<bool> exists(String localPath) async {
    if (failExists) {
      throw const CaptureStoreException(CaptureStoreFailure.writeFailed);
    }
    return files.contains(localPath);
  }

  @override
  Future<bool> delete(String localPath) async {
    deleted.add(localPath);
    if (failDelete) {
      throw const CaptureStoreException(CaptureStoreFailure.writeFailed);
    }
    return files.remove(localPath);
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    files.removeWhere((String path) => path.startsWith('durable/$batchId/'));
  }
}

/// An upload API driven by a script the test writes.
class ScriptedUploadApi implements UploadApi {
  ScriptedUploadApi(this._respond);

  final FutureOr<UploadOutcome> Function(QueuedImage image, int callIndex)
  _respond;

  /// Every image handed to [upload], in order.
  final List<QueuedImage> calls = <QueuedImage>[];

  /// How many times [upload] was invoked.
  int get callCount => calls.length;

  /// How many times [upload] saw a given image id.
  int callsFor(String imageId) =>
      calls.where((QueuedImage i) => i.id == imageId).length;

  @override
  Future<UploadOutcome> upload(QueuedImage image) async {
    final int index = calls.length;
    calls.add(image);
    return _respond(image, index);
  }
}

/// A connectivity port the test drives.
class FakeConnectivity implements ConnectivityPort {
  FakeConnectivity({bool hasLinkNow = true}) : _hasLink = hasLinkNow;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _hasLink;

  /// When true, [hasLink] throws.
  bool failHasLink = false;

  @override
  Future<bool> hasLink() async {
    if (failHasLink) {
      throw StateError('connectivity unavailable');
    }
    return _hasLink;
  }

  @override
  Stream<bool> get linkChanges => _controller.stream;

  /// Pushes a new link state to listeners.
  void emit(bool value) {
    _hasLink = value;
    _controller.add(value);
  }

  /// Closes the stream.
  Future<void> dispose() => _controller.close();
}

/// Records scheduling requests instead of talking to the platform.
class RecordingScheduler implements SyncScheduler {
  RecordingScheduler({
    this.drainOutcome = SchedulingOutcome.requested,
    this.continuationOutcome = SchedulingOutcome.requested,
  });

  /// What [scheduleDrain] should report.
  SchedulingOutcome drainOutcome;

  /// What [scheduleContinuation] should report.
  SchedulingOutcome continuationOutcome;

  /// How many entry drains were requested.
  int scheduleCount = 0;

  /// How many continuations were requested.
  int continuationCount = 0;

  @override
  Future<SchedulingOutcome> scheduleDrain() async {
    scheduleCount++;
    return drainOutcome;
  }

  @override
  Future<SchedulingOutcome> scheduleContinuation() async {
    continuationCount++;
    return continuationOutcome;
  }
}
