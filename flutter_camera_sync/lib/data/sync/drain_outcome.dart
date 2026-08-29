import 'package:equatable/equatable.dart';

/// What the platform should be told after a drain pass.
///
/// The distinction that matters is between **"we could not deliver"** and
/// **"we delivered, and there is more"**. Collapsing those two into one
/// "reschedule me" answer makes a large healthy backlog attract exponential
/// backoff, so a hundred queued photos drain more and more slowly the more
/// successfully they upload (`ADR-F19`).
enum DrainDisposition {
  /// Nothing was eligible and nothing is outstanding. The task is done.
  idle,

  /// Everything outstanding was resolved. The task is done.
  drained,

  /// The pass made progress and healthy work remains.
  ///
  /// A **continuation**, not a retry: the previous slice succeeded, so it must
  /// not attract backoff.
  continuationRequired,

  /// The pass could not make progress. Backoff is the right answer.
  ///
  /// Either the transport is failing, or every outstanding item is claimed by
  /// another processor whose lease has not lapsed — in both cases coming back
  /// later, less often, is correct.
  retryLater,
}

/// Why a drain pass stopped.
enum DrainStop {
  /// Nothing claimable was left.
  queueExhausted,

  /// The per-invocation item bound was reached.
  itemBudget,

  /// The per-invocation time budget was reached.
  timeBudget,

  /// The database was busy — another connection held a write lock.
  ///
  /// Contention between this app's own two isolates is an ordinary condition,
  /// not an error: the pass ends with whatever it achieved and the platform
  /// comes back. Nothing is stranded, because nothing was claimed by the
  /// attempt that lost, and anything already claimed is released by its lease.
  databaseBusy,
}

/// What one pass of the queue processor achieved.
///
/// The scheduling layer reads [disposition] and nothing else: the processor
/// does not know what a WorkManager `Result` is, and the worker does not know
/// what a claim is.
class DrainOutcome extends Equatable {
  /// Creates an outcome.
  const DrainOutcome({
    required this.uploaded,
    required this.retryable,
    required this.permanentlyFailed,
    required this.outstanding,
    required this.stop,
  });

  /// A pass that found nothing to do.
  static const DrainOutcome idle = DrainOutcome(
    uploaded: 0,
    retryable: 0,
    permanentlyFailed: 0,
    outstanding: 0,
    stop: DrainStop.queueExhausted,
  );

  /// Images confirmed uploaded during this pass.
  final int uploaded;

  /// Images returned to the queue after a retryable failure.
  final int retryable;

  /// Images that left the work set as unprocessable.
  final int permanentlyFailed;

  /// How many images anywhere are still outstanding.
  ///
  /// Read from the database at the end of the pass, not inferred from the
  /// counters: another isolate may have added or claimed work while this pass
  /// ran, and the queue's own state is the honest answer.
  final int outstanding;

  /// Why the pass ended.
  final DrainStop stop;

  /// How many images this pass acted on.
  int get processed => uploaded + retryable + permanentlyFailed;

  /// Whether anything is still outstanding.
  bool get workRemaining => outstanding > 0;

  /// Whether the pass moved any item out of the work set.
  ///
  /// A permanent failure counts. It is not a *good* outcome, but it is
  /// progress: that item will never be attempted again, so the queue is
  /// strictly closer to drained and there is no reason to back off.
  bool get madeProgress => uploaded > 0 || permanentlyFailed > 0;

  /// What the platform should be told.
  ///
  /// The order of these tests is the whole design:
  ///
  /// 1. nothing outstanding → the task is finished;
  /// 2. **progress was made** → continue, without backoff, however much is
  ///    left. This is the case that used to be reported as a failure;
  /// 3. no progress and something failed retryably → back off;
  /// 4. no progress and nothing failed → the outstanding items are claimed by
  ///    someone else, so there is nothing this pass could have done; back off
  ///    rather than spin, and rely on the lease to release them if that
  ///    claimant is dead.
  ///
  /// Requiring *progress* for a continuation is what stops a chain of
  /// zero-work continuations: each link must actually have moved an item, so
  /// the chain is bounded by the size of the queue.
  DrainDisposition get disposition {
    if (outstanding == 0) {
      return processed == 0 ? DrainDisposition.idle : DrainDisposition.drained;
    }
    if (madeProgress) {
      return DrainDisposition.continuationRequired;
    }
    return DrainDisposition.retryLater;
  }

  @override
  List<Object?> get props => <Object?>[
    uploaded,
    retryable,
    permanentlyFailed,
    outstanding,
    stop,
  ];

  @override
  String toString() =>
      'DrainOutcome(${disposition.name}: uploaded $uploaded, '
      'retryable $retryable, permanentlyFailed $permanentlyFailed, '
      'outstanding $outstanding, stopped on ${stop.name})';
}
