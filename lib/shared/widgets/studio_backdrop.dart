import 'package:flutter/material.dart';

/// Subtle branded gradient background for capture studio screens.
class StudioBackdrop extends StatelessWidget {
  const StudioBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Color> colors = isDark
        ? const <Color>[
            Color(0xFF080E1A),
            Color(0xFF0F1829),
            Color(0xFF0A0F1D),
          ]
        : const <Color>[
            Color(0xFFEFF4F9),
            Color(0xFFF8FAFC),
            Color(0xFFEDE7DD),
          ];

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