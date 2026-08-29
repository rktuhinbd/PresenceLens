import '../../domain/entities/failure_category.dart';
import '../../domain/entities/image_status.dart';
import '../../domain/entities/queued_image.dart';
import '../../domain/entities/upload_outcome.dart';
import '../../domain/policies/failure_classifier.dart';
import '../../domain/policies/retention_policy.dart';
import '../../domain/policies/stale_claim_policy.dart';
import '../../domain/ports/capture_store.dart';
import '../../domain/ports/clock.dart';
import '../../domain/ports/upload_api.dart';
import '../../domain/ports/upload_queue.dart';
import 'drain_outcome.dart';

/// Drains the upload queue: claim, attempt, classify, transition.
///
/// There is exactly **one** implementation of "drain the queue", and both the
/// foreground and the WorkManager isolate use it. That is the simplification
/// the whole sync design rests on: the two are not a primary and a fallback,
/// they are two claimants of the same queue, and the atomic claim is what makes
/// running both at once safe (`ARCHITECTURE.md` §5).
///
/// It knows nothing about widgets, Blocs, `Result` values or connectivity. The
/// decisions it makes are delegated to the pure policies in `domain/policies`.
class QueueProcessor {
  /// Creates a processor over the ports it needs.
  QueueProcessor({
    required UploadQueue queue,
    required UploadApi api,
    required CaptureStore store,
    required Clock clock,
    StaleClaimPolicy stalePolicy = const StaleClaimPolicy(),
    FailureClassifier classifier = const FailureClassifier(),
    RetentionPolicy retentionPolicy = const RetentionPolicy(),
  }) : _queue = queue,
       _api = api,
       _store = store,
       _clock = clock,
       _stalePolicy = stalePolicy,
       _classifier = classifier,
       _retentionPolicy = retentionPolicy;

  /// How many images one [drain] will process before returning.
  ///
  /// A background invocation has a limited execution window, so an unbounded
  /// loop over a large queue risks being killed part-way through an item rather
  /// than finishing cleanly and reporting honestly. Stopping at the bound and
  /// reporting `continuationRequired` hands the decision back to the OS, which
  /// is already the component that owns scheduling — **without** claiming
  /// anything failed.
  static const int defaultMaxItemsPerDrain = 25;

  /// How long one [drain] will keep working before returning.
  ///
  /// An item count is a poor proxy for a *time* limit, and time is what Android
  /// actually enforces: WorkManager stops a worker after roughly ten minutes.
  /// Twenty-five slow uploads could exceed that, and a worker killed mid-item
  /// reports nothing at all — the pass would be cut off rather than finish and
  /// ask for a continuation.
  ///
  /// Eight minutes leaves roughly two minutes of headroom for the item in
  /// flight when the budget is reached, plus the transitions that follow it.
  /// The budget is checked between items, never inside one: abandoning an
  /// upload half-way would leave a claim to expire rather than a clean result.
  static const Duration defaultMaxDrainDuration = Duration(minutes: 8);

  final UploadQueue _queue;
  final UploadApi _api;
  final CaptureStore _store;
  final Clock _clock;
  final StaleClaimPolicy _stalePolicy;
  final FailureClassifier _classifier;
  final RetentionPolicy _retentionPolicy;

  /// Processes claimable images until a budget is reached or nothing is left,
  /// and reports what happened.
  ///
  /// **Never throws for an ordinary failure.** An item that cannot be uploaded
  /// is recorded as a failure and the pass continues, so one bad image cannot
  /// prevent unrelated batches from draining. A database that is momentarily
  /// locked by the app's other isolate ends the pass cleanly rather than
  /// escaping as an exception — contention between two claimants is the
  /// designed situation, not an error.
  Future<DrainOutcome> drain({
    int maxItems = defaultMaxItemsPerDrain,
    Duration maxDuration = defaultMaxDrainDuration,
  }) async {
    final DateTime startedAt = _clock.nowUtc();
    int uploaded = 0;
    int retryable = 0;
    int permanent = 0;
    DrainStop stop = DrainStop.queueExhausted;

    // Items this pass has already tried and returned to the queue. A retryable
    // failure makes a row `PENDING` again and therefore immediately claimable,
    // so without this the very next iteration would pick the same item back up
    // and hammer it until the bound — the app running its own retry loop, in
    // competition with the backoff that belongs to WorkManager (`RS-04`). They
    // stay queued and are picked up by a *later* invocation, which is what
    // "retry automatically" is supposed to mean.
    final Set<String> deferred = <String>{};

    for (int processed = 0; ; processed++) {
      if (processed >= maxItems) {
        stop = DrainStop.itemBudget;
        break;
      }

      final DateTime now = _clock.nowUtc();
      if (now.difference(startedAt) >= maxDuration) {
        stop = DrainStop.timeBudget;
        break;
      }

      final QueuedImage? claimed;
      final _ItemResult result;
      try {
        claimed = await _queue.claimNext(
          now: now,
          leaseCutoff: _stalePolicy.cutoffFrom(now),
          skip: deferred,
        );
        if (claimed == null) {
          // Nothing pending, nothing whose lease has lapsed, and nothing left
          // that this pass has not already tried. Not an error — this is what a
          // drained queue looks like.
          break;
        }
        result = await _process(claimed);
      } on Object {
        // The database refused a write, almost always because the app's *other*
        // isolate holds a lock. That is contention, not failure, and this method
        // promises not to throw for an ordinary condition — so the pass ends
        // with what it achieved and the platform comes back.
        //
        // Nothing is stranded either way: a claim that lost the race never
        // happened, and an item already claimed is released by its lease
        // (`FLT-SYNC-009`). Deliberately *not* retried in a loop here — that
        // would be an app-side retry schedule, which is `RS-04`.
        stop = DrainStop.databaseBusy;
        break;
      }

      switch (result) {
        case _ItemResult.uploaded:
          uploaded++;
        case _ItemResult.retryable:
          retryable++;
          deferred.add(claimed.id);
        case _ItemResult.permanent:
          permanent++;
      }
    }

    int outstanding;
    try {
      outstanding = await _queue.outstandingCount();
    } on Object {
      // Even the closing read can hit a locked database. Reporting "work
      // remains" is the safe assumption: it asks the platform to come back,
      // where reporting zero would end the chain on a queue that may not be
      // empty.
      outstanding = 1;
      stop = DrainStop.databaseBusy;
    }

    return DrainOutcome(
      uploaded: uploaded,
      retryable: retryable,
      permanentlyFailed: permanent,
      outstanding: outstanding,
      stop: stop,
    );
  }

  Future<_ItemResult> _process(QueuedImage image) async {
    // The row promises a file. If the promise is broken — an external deletion,
    // a restore from a backup that carried the database but not the images —
    // then no number of retries can help, and treating it as a network problem
    // would leave an item that blocks the queue forever (`FLT-ERR-007`, I10).
    if (!await _fileStillExists(image)) {
      return _record(image, FailureCategory.missingLocalFile);
    }

    final UploadOutcome outcome;
    try {
      outcome = await _api.upload(image);
    } catch (error) {
      // The transport threw instead of classifying. Unknown faults fail open,
      // toward keeping the photo.
      return _record(image, FailureCategory.unexpected);
    }

    switch (outcome) {
      case UploadSucceeded():
        return _recordSuccess(image);
      case UploadFailed(:final FailureCategory category):
        return _record(image, category);
    }
  }

  Future<bool> _fileStillExists(QueuedImage image) async {
    try {
      return await _store.exists(image.localPath);
    } catch (_) {
      // A filesystem that cannot answer is not the same as a missing file, and
      // treating it as one would discard a capture on a transient IO fault.
      return true;
    }
  }

  Future<_ItemResult> _recordSuccess(QueuedImage image) async {
    final DateTime now = _clock.nowUtc();

    // Durable first. Only once the database says UPLOADED is the local file
    // allowed to be touched — the reverse order can delete the only copy of a
    // photo whose success was never recorded.
    await _queue.recordSuccess(image.id, now: now);

    if (_retentionPolicy.shouldDeleteLocalFile(ImageStatus.uploaded)) {
      try {
        await _store.delete(image.localPath);
      } catch (_) {
        // Housekeeping, not delivery. The upload happened; a file that would
        // not delete is disk to reclaim later, and must never send the item
        // back to the queue to be uploaded a second time.
      }
    }

    return _ItemResult.uploaded;
  }

  Future<_ItemResult> _record(QueuedImage image, FailureCategory category) {
    final DateTime now = _clock.nowUtc();
    return switch (_classifier.classify(category)) {
      FailureDisposition.retryable =>
        _queue
            .recordRetryableFailure(image.id, category: category, now: now)
            .then((_) => _ItemResult.retryable),
      FailureDisposition.permanent =>
        _queue
            .recordPermanentFailure(image.id, category: category, now: now)
            .then((_) => _ItemResult.permanent),
    };
  }
}

enum _ItemResult { uploaded, retryable, permanent }
