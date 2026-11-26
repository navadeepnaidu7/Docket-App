import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/pass_list_provider.dart';
import '../application/pending_pass_queue.dart';

/// Quiet status above the passes: offline, waiting uploads, and refusals.
/// Renders nothing when the wallet is online and the queue is empty.
class PassSyncBanner extends ConsumerWidget {
  const PassSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool offline = ref.watch(
      passSyncStatusProvider.select((s) => s.offline),
    );
    final List<PendingPass> queue = ref.watch(pendingPassQueueProvider);
    final bool draining = ref.read(pendingPassQueueProvider.notifier).draining;
    final int waiting = queue.where((p) => !p.failed).length;
    final List<PendingPass> failed = queue
        .where((p) => p.failed)
        .toList(growable: false);

    final List<Widget> lines = <Widget>[
      if (offline)
        const _Line(
          icon: Icons.cloud_off_rounded,
          text: 'You’re offline. Passes update when you reconnect.',
        ),
      if (waiting > 0)
        _Line(
          icon: Icons.cloud_upload_outlined,
          text: draining && !offline
              ? 'Adding ${_passes(waiting)}…'
              : '${_passes(waiting)} will be added when you’re online.',
        ),
      for (final PendingPass item in failed)
        _Line(
          icon: Icons.error_outline_rounded,
          text: '${item.pnr ?? 'A ticket'} couldn’t be added. ${item.error}',
          onDismiss: () =>
              ref.read(pendingPassQueueProvider.notifier).dismiss(item.id),
        ),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  static String _passes(int n) => n == 1 ? '1 pass' : '$n passes';
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.onDismiss});

  final IconData icon;
  final String text;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
              icon: Icon(Icons.close_rounded, size: 16, color: muted),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
