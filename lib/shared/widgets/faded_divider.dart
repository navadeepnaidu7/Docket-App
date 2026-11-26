import 'package:flutter/material.dart';

/// A hairline that fades out at its ends instead of stopping square.
///
/// Two weights, so a reader can tell a change of section from the next item
/// in a list:
///
/// - [FadedDivider.section] spans the container and fades at both ends. It
///   separates groups ("Departure" from the headline above it).
/// - [FadedDivider.item] starts at [indent], under the text rather than the
///   icon, and fades only towards the trailing edge. It separates rows in one
///   list.
class FadedDivider extends StatelessWidget {
  const FadedDivider.section({super.key, this.color})
    : indent = 0,
      _section = true;

  const FadedDivider.item({super.key, this.indent = 0, this.color})
    : _section = false;

  /// Leading space before the line starts. Items only.
  final double indent;

  /// Line colour at full strength; defaults to the theme's onSurface at a
  /// hairline alpha.
  final Color? color;

  final bool _section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color base =
        color ??
        theme.colorScheme.onSurface.withValues(
          alpha: _section ? (isDark ? 0.14 : 0.12) : (isDark ? 0.09 : 0.08),
        );
    final Color clear = base.withValues(alpha: 0);
    final Gradient gradient = _section
        ? LinearGradient(
            colors: <Color>[clear, base, base, clear],
            stops: const <double>[0, 0.14, 0.86, 1],
          )
        : LinearGradient(
            colors: <Color>[base, base, clear],
            stops: const <double>[0, 0.7, 1],
          );
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
      ),
    );
  }
}
