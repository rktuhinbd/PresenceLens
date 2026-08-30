import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ports/clock.dart';
import 'sync_bloc.dart';
import 'sync_event.dart';
import 'sync_state.dart';
import 'widgets/upload_manager_widgets.dart';

/// Pending Uploads (`FLT-BAT-003`).
///
/// **Every string on this screen answers one question: "did I lose my photos?"**
/// The answer is no, and it is said before anything about the network — which is
/// why the reassurance line is persistent, why the offline chip leads with
/// "captures are safe", and why the empty state is a success rather than a
/// warning (`UX_SPEC.md` §4.1, `FLT-UX-007`).
///
/// It renders in the Material scheme, light and dark alike (`FLT-UX-008`). Only
/// the camera route is fixed dark, and for a reason that does not apply here.
///
/// Back navigation is ordinary and means exactly one thing: return to the
/// camera. Nothing is at risk — the draft batch is durable and is not touched by
/// leaving or entering this screen (`UX_SPEC.md` §3.1).
class UploadManagerScreen extends StatelessWidget {
  /// Creates the screen.
  const UploadManagerScreen({this.clock = const SystemClock(), super.key});

  /// Where relative times are measured from. Injected so a test can pin them.
  final Clock clock;

  /// The persistent reassurance line — the most important sentence here
  /// (`FLT-UX-007`).
  static const String reassurance =
      'Saved on this device. Uploads resume automatically '
      "when you're connected.";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending uploads'),
        actions: <Widget>[
          BlocBuilder<SyncBloc, SyncState>(
            buildWhen: (SyncState previous, SyncState current) =>
                previous.hasPendingWork != current.hasPendingWork,
            builder: (BuildContext context, SyncState state) {
              if (!state.hasPendingWork) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (String _) =>
                    context.read<SyncBloc>().add(const SyncDrainRequested()),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  // **An accelerator, never the mechanism** — automatic
                  // recovery does not depend on this existing
                  // (`FLT-SYNC-014`). It is in the overflow precisely so it
                  // does not read as the way uploads happen.
                  const PopupMenuItem<String>(
                    value: 'retry',
                    child: Text('Try now'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<SyncBloc, SyncState>(
        builder: (BuildContext context, SyncState state) {
          if (state.isEmpty) {
            return UploadsEmptyView(
              onOpenCamera: () => Navigator.of(context).maybePop(),
            );
          }
          return _QueueList(state: state, now: clock.nowUtc());
        },
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.state, required this.now});

  final SyncState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          // Capped so the list stays readable on a tablet instead of stretching
          // a two-column row across a foot of glass (`UX_SPEC.md` §8).
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              ConnectivityChip(
                hasLink: state.hasLink,
                hasPendingWork: state.hasPendingWork,
              ),
              if (state.hasPendingWork) const SizedBox(height: 20),
              for (final SyncBatchView view in state.batches) ...<Widget>[
                BatchSection(view: view, hasLink: state.hasLink, now: now),
                // The grouping is carried by whitespace, not by borders: a
                // noticeably larger gap between batches than between rows.
                const SizedBox(height: 24),
              ],
              if (state.hasPendingWork) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  UploadManagerScreen.reassurance,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Start new batch'),
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(0, 48)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
