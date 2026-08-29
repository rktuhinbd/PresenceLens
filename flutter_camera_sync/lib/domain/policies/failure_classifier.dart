import '../entities/failure_category.dart';

/// Turns a failure category into a decision about the queue.
///
/// Kept pure and separate from the processor so the retry rule can be read in
/// one place and tested without a database, a file or a transport
/// (`FLT-SYNC-006`, `FLT-ERR-008`).
class FailureClassifier {
  /// Creates the classifier. It carries no state.
  const FailureClassifier();

  /// Decides what should happen to an item that failed with [category].
  FailureDisposition classify(FailureCategory category) {
    return switch (category) {
      // The link, the transfer, or the server. All three can succeed later.
      FailureCategory.offline => FailureDisposition.retryable,
      FailureCategory.timeout => FailureDisposition.retryable,
      FailureCategory.serverTransient => FailureDisposition.retryable,

      // The server understood the request and refused it. Sending the same
      // bytes again cannot change that answer.
      FailureCategory.serverRejected => FailureDisposition.permanent,

      // There is nothing left to upload. Retrying would keep an item that can
      // never succeed in the work set, and the queue would never drain (I10).
      FailureCategory.missingLocalFile => FailureDisposition.permanent,

      // Fail open, toward keeping the photo: an unrecognised fault is far more
      // likely to be transient than to be a genuine rejection, and the cost of
      // guessing wrong in this direction is a wasted retry rather than a lost
      // capture.
      FailureCategory.unexpected => FailureDisposition.retryable,
    };
  }
}
