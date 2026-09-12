import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/pass_ingest_controller.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_display.dart';
import '../../domain/pass_ingest.dart';
import '../../domain/pass_status.dart';

/// Outcomes remain actionable until the user chooses what to do next.
class PassIngestOutcome extends StatelessWidget {
  const PassIngestOutcome({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onReplace,
    required this.onDismiss,
    required this.onView,
  });
  final PassIngestUiState state;
  final VoidCallback onRetry;
  final VoidCallback onReplace;
  final VoidCallback onDismiss;
  final ValueChanged<WalletPassItem> onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failure = state is PassIngestFailed
        ? state as PassIngestFailed
        : null;
    final item = state is PassIngestSucceeded
        ? (state as PassIngestSucceeded).item
        : null;
    if (failure == null && item == null) return const SizedBox.shrink();
    final title = failure != null
        ? _failureTitle(failure.error.code)
        : item!.status == TicketStatus.expired
        ? 'Added to Archive'
        : 'Pass added';
    final canRetry =
        failure != null &&
        switch (failure.error.code) {
          PassIngestCode.failed ||
          PassIngestCode.unreadable ||
          PassIngestCode.rateLimited => true,
          _ => false,
        };
    return Material(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.97),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    failure != null
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 36,
                    color: scheme.onSurface,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    failure != null
                        ? _failureMessage(failure.error)
                        : passTitle(item!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (item != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      item.passCode == null
                          ? 'No boarding code was found. Keep your original ticket available.'
                          : 'Boarding code saved with your pass.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTokens.secondaryLabel(scheme),
                      ),
                    ),
                    if (item.status == TicketStatus.expired) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Its date has passed, so you’ll find it in Archive.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  if (item != null)
                    FilledButton(
                      onPressed: () => onView(item),
                      child: const Text('View pass'),
                    ),
                  if (canRetry)
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  if (failure != null &&
                      failure.error.code != PassIngestCode.needsRemote &&
                      failure.error.code != PassIngestCode.needsAuth) ...[
                    if (canRetry) const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onReplace,
                      child: Text(
                        failure.request is FilePassIngestRequest
                            ? 'Choose another file'
                            : 'Change input',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _failureTitle(PassIngestCode code) => switch (code) {
  PassIngestCode.needsRemote => 'You’re exploring sample passes',
  PassIngestCode.needsAuth => 'Pass import is unavailable',
  PassIngestCode.invalidPnr => 'Check your PNR',
  PassIngestCode.fileTooLarge => 'Choose a smaller file',
  PassIngestCode.unsupportedFile => 'Choose a photo or PDF',
  PassIngestCode.rateLimited => 'Try again later',
  PassIngestCode.unreadable => 'We couldn’t read this ticket',
  PassIngestCode.failed => 'Your pass couldn’t be added',
};

String _failureMessage(PassIngestException error) => switch (error.code) {
  PassIngestCode.needsRemote =>
    'This preview contains sample tickets. Importing your own tickets isn’t available in demo mode.',
  PassIngestCode.needsAuth =>
    'Your connection to pass import needs to be restored. Your documents are still available.',
  _ => error.message,
};
