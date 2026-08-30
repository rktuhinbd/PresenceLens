import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/entities/queued_image.dart';
import '../queue_item_view.dart';
import '../sync_state.dart';
import 'upload_status_style.dart';

/// The connectivity hint (`FLT-UX-010`).
///
/// **A hint, never a guarantee.** Link presence is not reachability, so the copy
/// says "Connected", not "Connection stable"; and it says "uploading
/// automatically", not "uploading now", because the OS owns the schedule and the
/// app cannot promise a moment (`UX_SPEC.md` §4.1).
///
/// Offline leads with the reassurance rather than the problem: the user's actual
/// question is "did I lose them?", and the first three words answer it.
class ConnectivityChip extends StatelessWidget {
  /// Creates the chip.
  const ConnectivityChip({
    required this.hasLink,
    required this.hasPendingWork,
    super.key,
  });

  /// The advisory link signal.
  final bool hasLink;

  /// Whether anything is still owed an upload.
  final bool hasPendingWork;

  /// The exact wording used when a link is reported.
  static const String connectedText = 'Connected · uploading automatically';

  /// The exact wording used when no link is reported.
  static const String offlineText = 'Offline · captures are safe';

  @override
  Widget build(BuildContext context) {
    if (!hasPendingWork) {
      // Nothing to reassure anyone about.
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool connected = hasLink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: connected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.bolt : Icons.cloud_off_outlined,
            size: 18,
            color: connected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              connected ? connectedText : offlineText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: connected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One batch and its images.
///
/// Progress is `n of m` — count-based and read from the rows. The app has no
/// byte-level progress and will not invent one (`UX_SPEC.md` §4).
class BatchSection extends StatelessWidget {
  /// Creates a section.
  const BatchSection({
    required this.view,
    required this.hasLink,
    required this.now,
    super.key,
  });

  /// The batch to render.
  final SyncBatchView view;

  /// The advisory link signal, which changes wording only.
  final bool hasLink;

  /// The instant relative times are measured from.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'BATCH · ${_relativeTime(view.batch.queuedAt ?? view.batch.createdAt, now)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${view.uploadedCount} of ${view.totalCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    // Determinate and bounded. A looping shimmer would read as
                    // a queue that is stuck (`UX_SPEC.md` §7.2).
                    value: view.totalCount == 0
                        ? 0
                        : view.uploadedCount / view.totalCount,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (final QueuedImage image in view.images)
                QueueItemRow(view: QueueItemView.of(image, hasLink: hasLink)),
            ],
          ),
        ),
      ],
    );
  }

  /// A human relative time. Absolute times are never shown: "14:03" answers a
  /// question nobody asked of a queue.
  static String _relativeTime(DateTime at, DateTime now) {
    final Duration elapsed = now.difference(at.toUtc());
    if (elapsed.inMinutes < 1) {
      return 'just now';
    }
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes} min ago';
    }
    if (elapsed.inHours < 24) {
      return '${elapsed.inHours} hr ago';
    }
    return '${elapsed.inDays} d ago';
  }
}

/// One image in the queue (`FLT-UX-011`).
class QueueItemRow extends StatelessWidget {
  /// Creates a row.
  const QueueItemRow({required this.view, super.key});

  /// The resolved presentation of the durable row.
  final QueueItemView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = UploadStatusStyle.colorFor(view.tone, theme.colorScheme);

    return Semantics(
      // One label for the whole row rather than four separate nodes
      // (`UX_SPEC.md` §6).
      label: view.semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              _Thumbnail(path: view.image.localPath),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  view.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Icon(UploadStatusStyle.iconFor(view.tone), size: 16, color: tone),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 168),
                child: Text(
                  view.statusLine,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: tone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        color: scheme.surfaceContainerHighest,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          // A file the queue has already uploaded and cleaned up, or one the
          // user removed, must not throw inside a list. The row's own status is
          // the fact; the picture is a courtesy.
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
        ),
      ),
    );
  }
}

/// The empty state (`FLT-UX-006`).
///
/// Not an error and not styled like one. An empty queue is the good outcome.
class UploadsEmptyView extends StatelessWidget {
  /// Creates the empty state.
  const UploadsEmptyView({required this.onOpenCamera, super.key});

  /// Called by the primary action.
  final VoidCallback onOpenCamera;

  /// The headline, asserted by test so the tone cannot regress to "0 items".
  static const String headline = "Everything's uploaded";

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_done_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(headline, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Photos you capture will appear here until '
              "they're safely uploaded.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Open camera'),
              style: ButtonStyle(
                minimumSize: WidgetStateProperty.all(const Size(0, 48)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
