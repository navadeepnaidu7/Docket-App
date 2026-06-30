import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StudioOrDivider extends StatelessWidget {
  const StudioOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color lineColor = AppTokens.separator(scheme);
    final Color textColor = AppTokens.secondaryLabel(scheme);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sectionPadding,
        vertical: 14,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: lineColor, thickness: 0.5, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or enter manually',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor, thickness: 0.5, height: 1)),
        ],
      ),
    );
  }
}