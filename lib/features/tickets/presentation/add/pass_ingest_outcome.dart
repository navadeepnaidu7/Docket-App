import 'package:flutter/material.dart';

import '../../application/pass_ingest_controller.dart';
import '../../domain/pass_ingest.dart';

/// A failed import stays on screen until the user chooses what to do next.
///
/// Success is not a page. The particle field says what was added, then clears.
class PassIngestOutcome extends StatelessWidget {
  const PassIngestOutcome({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onReplace,
    required this.onDismiss,
  });

  final PassIngestUiState state;
  final VoidCallback onRetry;
  final VoidCallback onReplace;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (state is! PassIngestFailed) return const SizedBox.shrink();
    final PassIngestFailed failure = state as PassIngestFailed;
    final ThemeData theme = Theme.of(context);
    final bool canRetry = switch (failure.error.code) {
      PassIngestCode.failed ||
      PassIngestCode.unreadable ||
      PassIngestCode.rateLimited => true,
      _ => false,
    };
    final bool offerReplace =
        failure.error.code != PassIngestCode.needsRemote &&
        failure.error.code != PassIngestCode.needsAuth;

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
                    Icons.info_outline_rounded,
                    size: 36,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _failureTitle(failure.error.code),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _failureMessage(failure.error),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (canRetry)
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  if (offerReplace) ...[
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
