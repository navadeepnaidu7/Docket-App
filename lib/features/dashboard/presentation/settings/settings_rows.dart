import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';

// Shared Settings row primitives: section shell, card, divider, rows, press scale.

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.surface,
    required this.borderColor,
    required this.isDark,
    required this.children,
  });

  final String title;
  final Color surface;
  final Color borderColor;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.42 : 0.50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title,
            style: AppFonts.ui(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: muted,
            ),
          ),
        ),
        SettingsCard(
          surface: surface,
          borderColor: borderColor,
          isDark: isDark,
          children: children,
        ),
      ],
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.surface,
    required this.borderColor,
    required this.isDark,
    this.padding,
    this.child,
    this.children,
  });

  final Color surface;
  final Color borderColor;
  final bool isDark;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final Widget content =
        child ??
        (children != null
            ? Column(mainAxisSize: MainAxisSize.min, children: children!)
            : const SizedBox.shrink());

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22.0)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(22.0),
          ),
          child: padding != null
              ? Padding(padding: padding!, child: content)
              : content,
        ),
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final Color dividerColor = Theme.of(context).colorScheme.onSurface
        .withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
        );

    // Align under text after bare icon (14 pad + 24 icon + 12 gap).
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Divider(height: 1, thickness: 0.5, color: dividerColor),
    );
  }
}

class SettingsRowIcon extends StatelessWidget {
  const SettingsRowIcon({
    super.key,
    required this.icon,
    // Kept for call-site compatibility; all row icons use a neutral tint.
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Same default ink for every row in both modes (no accent colors).
    final Color iconTint = isDark
        ? const Color(0xFFE5E5EA)
        : const Color(0xFF3A3A3C);

    // Bare glyph only — no squircle / plate behind the icon.
    return SizedBox(
      width: 24,
      height: 24,
      child: Icon(icon, size: 22, color: iconTint),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return SizedBox(
      height: subtitle == null ? 58 : 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            SettingsRowIcon(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppFonts.ui(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.ui(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: CupertinoSwitch(
                value: value,
                // System green — avoids electric-blue chrome in dark mode.
                activeTrackColor: const Color(0xFF34C759),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPressScale extends StatefulWidget {
  const SettingsPressScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<SettingsPressScale> createState() => _SettingsPressScaleState();
}

class _SettingsPressScaleState extends State<SettingsPressScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return SettingsPressScale(
      onTap: () {
        HapticService.tap();
        onTap();
      },
      child: SizedBox(
        height: subtitle == null ? 58 : 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: subtitle == null
                    ? Text(
                        title,
                        style: AppFonts.ui(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: ink,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: AppFonts.ui(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.ui(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
