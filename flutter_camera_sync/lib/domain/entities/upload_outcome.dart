import 'package:equatable/equatable.dart';

import 'failure_category.dart';

/// The result of one upload attempt.
///
/// This is the **only** authority on whether an image reached the server. Link
/// state is not (`ADR-F05`): a captive portal, a saturated cell link and a
/// router with no upstream all report a healthy connection.
sealed class UploadOutcome extends Equatable {
  /// Const base constructor.
  const UploadOutcome();
}

/// The server accepted the image.
final class UploadSucceeded extends UploadOutcome {
  /// Creates a success outcome.
  const UploadSucceeded({required this.idempotencyKey});

  /// The key the transport sent, echoed back.
  ///
  /// Always the image's own id. Asserting on it is how the tests prove the
  /// client did its half of duplicate-suppression (`RS-06`).
  final String idempotencyKey;

  @override
  List<Object?> get props => <Object?>[idempotencyKey];
}

/// The attempt did not succeed.
final class UploadFailed extends UploadOutcome {
  /// Creates a failure outcome in the given [category].
  const UploadFailed(this.category, {this.detail});

  /// The app's classification of what went wrong.
  final FailureCategory category;

  /// Optional human-readable detail, for logs and diagnosis only.
  final String? detail;

  @override
  List<Object?> get props => <Object?>[category, detail];
}
