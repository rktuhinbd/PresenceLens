import 'package:flutter/material.dart';

import '../queue_item_view.dart';

/// The icon and colour role each queue state renders with.
///
/// **Every state has an icon and a word** (`FLT-UX-005`). The colour is a third
/// signal, never the only one: a row read in greyscale, or by someone who cannot
/// distinguish the roles, still says what it is in text. The colours themselves
/// are Material scheme *roles* rather than literals, so light and dark are one
/// definition (`FLT-UX-008`).
abstract final class UploadStatusStyle {
  /// The glyph for [tone].
  static IconData iconFor(QueueItemTone tone) {
    switch (tone) {
      case QueueItemTone.queued:
        return Icons.schedule;
      case QueueItemTone.awaitingLink:
        return Icons.cloud_off_outlined;
      case QueueItemTone.uploading:
        return Icons.arrow_upward;
      case QueueItemTone.retrying:
        return Icons.refresh;
      case QueueItemTone.synced:
        return Icons.check_circle;
      case QueueItemTone.failed:
        return Icons.error_outline;
    }
  }

  /// The scheme role for [tone].
  static Color colorFor(QueueItemTone tone, ColorScheme scheme) {
    switch (tone) {
      case QueueItemTone.queued:
      case QueueItemTone.awaitingLink:
        return scheme.onSurfaceVariant;
      case QueueItemTone.uploading:
      case QueueItemTone.synced:
        return scheme.primary;
      case QueueItemTone.retrying:
        return scheme.tertiary;
      case QueueItemTone.failed:
        // The only place `error` is used. Reserved for an item that has left
        // the work set, so it keeps meaning "this one will not resolve itself".
        return scheme.error;
    }
  }
}
