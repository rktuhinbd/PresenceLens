import 'package:equatable/equatable.dart';

/// Everything the sync presentation reacts to.
///
/// A sealed hierarchy because this is the one component in the app whose inputs
/// genuinely fan in from several independent asynchronous sources, and which
/// must behave *differently* depending on which one arrived. That is the
/// distinction that earns a Bloc rather than a Cubit here
/// (`ARCHITECTURE.md` §3).
sealed class SyncEvent extends Equatable {
  /// Creates an event.
  const SyncEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Start watching, take a first snapshot, and reconcile.
///
/// The startup half of `FLT-SYNC-012`: durable work left behind by a previous
/// process — including work whose drain request was lost — is found and
/// rescheduled here rather than waiting for the user to do something (`RS-11`).
class SyncStarted extends SyncEvent {
  /// Creates the event.
  const SyncStarted();
}

/// The durable queue changed. Re-read; schedule nothing.
///
/// Deliberately not a scheduling trigger. A capture writes a `DRAFT` row and
/// announces a change, and a `DRAFT` image is not uploadable — waking a worker
/// for it would be twenty idle wake-ups per capture session (`ADR-F21`).
class SyncQueueChanged extends SyncEvent {
  /// Creates the event.
  const SyncQueueChanged();
}

/// The advisory link signal changed.
class SyncLinkChanged extends SyncEvent {
  /// Creates the event.
  const SyncLinkChanged(this.hasLink);

  /// Whether the platform now reports a link.
  final bool hasLink;

  @override
  List<Object?> get props => <Object?>[hasLink];
}

/// The app came back to the foreground.
///
/// The resume half of `FLT-SYNC-012`.
class SyncResumed extends SyncEvent {
  /// Creates the event.
  const SyncResumed();
}

/// A batch was just finished, so uploadable work now exists.
class SyncBatchFinished extends SyncEvent {
  /// Creates the event.
  const SyncBatchFinished();
}

/// The user pressed "Try now".
///
/// An accelerator and nothing more. Automatic recovery does not depend on it and
/// never has — removing this event would change how *soon* the queue drains and
/// nothing else (`FLT-SYNC-014`).
class SyncDrainRequested extends SyncEvent {
  /// Creates the event.
  const SyncDrainRequested();
}

/// A completed batch has been shown as "Synced" for long enough.
class SyncCompletionExpired extends SyncEvent {
  /// Creates the event.
  const SyncCompletionExpired(this.batchId);

  /// The batch to stop showing.
  final String batchId;

  @override
  List<Object?> get props => <Object?>[batchId];
}
