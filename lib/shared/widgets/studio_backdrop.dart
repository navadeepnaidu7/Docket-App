import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Subtle branded gradient background for capture studio screens.
class StudioBackdrop extends StatelessWidget {
  const StudioBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final List<Color> colors = AppTheme.studioGradient(brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
