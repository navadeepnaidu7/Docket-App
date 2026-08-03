import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/prompt_typography.dart';
import '../domain/nfc_failure.dart';

/// What the chip step is currently doing.
enum NfcPhase { idle, waiting, reading, success, failed }

/// The body of the in-flow chip step.
///
/// In-flow rather than a modal sheet, so a failure can hand the user back to
/// the field that caused it. The sheet this replaces could only offer "Try
/// again", which re-ran the identical failing call, and could only be
/// dismissed by swiping it away.
class NfcPromptBody extends StatelessWidget {
  const NfcPromptBody({
    super.key,
    required this.phase,
    this.failure,
    this.statusLine,
  });

  final NfcPhase phase;
  final NfcFailure? failure;

  /// Live progress from the platform channel, e.g. "Reading photo".
  final String? statusLine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (phase == NfcPhase.failed && failure != null) {
      return _Failure(failure: failure!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(child: _Pulse(phase: phase)),
        const SizedBox(height: Space.x8),
        Center(
          child: Text(
            switch (phase) {
              NfcPhase.success => 'Chip read',
              NfcPhase.reading => statusLine ?? 'Reading the chip',
              _ => 'Waiting for the chip',
            },
            style: theme.textTheme.promptInput.copyWith(fontSize: 17),
          ),
        ),
        const SizedBox(height: Space.x2),
        Center(
          child: Text(
            phase == NfcPhase.success
                ? 'Everything below came straight off the chip.'
                : 'Most passports read from the back cover. Keep still.',
            textAlign: TextAlign.center,
            style: theme.textTheme.promptHelper(scheme),
          ),
        ),
      ],
    );
  }
}

/// A slow breathing ring. Deliberately not a spinner: the phone is waiting for
/// the user to hold still, not working on something.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.phase});

  final NfcPhase phase;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool done = widget.phase == NfcPhase.success;
    final Color tint = done ? AppTokens.success(scheme) : scheme.primary;

    return SizedBox(
      width: 132,
      height: 132,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, Widget? _) {
          final double t = _ctrl.value;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (!done)
                for (int i = 0; i < 2; i++)
                  Opacity(
                    opacity: (1.0 - ((t + i * 0.5) % 1.0)) * 0.35,
                    child: Container(
                      width: 76 + ((t + i * 0.5) % 1.0) * 56,
                      height: 76 + ((t + i * 0.5) % 1.0) * 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tint, width: 1.5),
                      ),
                    ),
                  ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.12),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.nfc_rounded,
                  size: 32,
                  color: tint,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A failure with an explanation and a way out.
class _Failure extends StatelessWidget {
  const _Failure({required this.failure});

  final NfcFailure failure;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.danger.withValues(alpha: 0.12),
          ),
          child: Icon(
            Icons.nfc_rounded,
            size: 26,
            color: AppTheme.danger,
          ),
        ),
        const SizedBox(height: Space.x5),
        Text(failure.title, style: theme.textTheme.promptQuestion),
        const SizedBox(height: Space.x2),
        Text(failure.body, style: theme.textTheme.promptHelper(scheme)),
      ],
    );
  }
}
