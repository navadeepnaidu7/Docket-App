import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/pass_code.dart';
import 'pass_code_view.dart';
import 'pass_typography.dart';

/// The same route and feedback for every category's scan view.
Future<void> showPassCodeScreen(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  HapticService.tap();
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: builder),
  );
}

/// Shared scan layout. Category adapters supply content, not separate chrome.
class PassCodeScreen extends StatelessWidget {
  const PassCodeScreen({
    super.key,
    required this.code,
    required this.title,
    this.subtitle = '',
    this.reference = '',
    this.referenceLabel = 'Booking ID',
    this.emptyLabel = 'This ticket has no scannable code',
  });

  final PassCode? code;
  final String title;
  final String subtitle;
  final String reference;
  final String referenceLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(theme.colorScheme);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? Colors.black
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Align(alignment: Alignment.centerLeft, child: CloseButton()),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints bounds) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: bounds.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (title.trim().isNotEmpty)
                                  Text(
                                    title.trim(),
                                    textAlign: TextAlign.center,
                                    style: PassType.screenTitle(ink),
                                  ),
                                if (subtitle.trim().isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle.trim(),
                                    textAlign: TextAlign.center,
                                    style: PassType.caption(muted),
                                  ),
                                ],
                                const SizedBox(height: 36),
                                LayoutBuilder(
                                  builder: (context, plateBounds) => PassCodePlate(
                                    code: code,
                                    // The white plate adds 18 dp on each side.
                                    width: math.min(
                                      260,
                                      plateBounds.maxWidth - 36,
                                    ),
                                    emptyLabel: emptyLabel,
                                  ),
                                ),
                                if (reference.trim().isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 28),
                                  Text(
                                    reference.trim(),
                                    textAlign: TextAlign.center,
                                    style: PassType.code(ink),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    referenceLabel,
                                    textAlign: TextAlign.center,
                                    style: PassType.caption(muted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
