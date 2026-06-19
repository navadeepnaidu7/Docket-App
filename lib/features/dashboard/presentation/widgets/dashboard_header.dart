import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/bounce_tap.dart';
import '../dashboard_screen.dart' show DashboardViewMode;

class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1.0,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.60),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 0.5,
                ),
              ),
              child: Icon(
                widget.icon,
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.80),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.name,
    required this.isMenuOpen,
    required this.currentMode,
    required this.onHomeTap,
    required this.onAvatarTap,
    required this.headerTitleLink,
  });

  final String name;
  final bool isMenuOpen;
  final DashboardViewMode currentMode;
  final VoidCallback onHomeTap;
  final VoidCallback onAvatarTap;
  final LayerLink headerTitleLink;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark
        ? const Color(0xFFE8EEFF)
        : const Color(0xFF0D1B2A);
    final Color muted = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFF6B7280);

    final String titleText;
    switch (currentMode) {
      case DashboardViewMode.home:
        titleText = 'Home';
        break;
      case DashboardViewMode.manage:
        titleText = 'Manage';
        break;
      case DashboardViewMode.trash:
        titleText = 'Trash';
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BounceTap(
          onTap: isMenuOpen ? null : onHomeTap,
          child: CompositedTransformTarget(
            link: headerTitleLink,
            child: IgnorePointer(
              ignoring: isMenuOpen,
              child: Opacity(
                opacity: isMenuOpen ? 0.0 : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: GoogleFonts.inter(
                        color: ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isMenuOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 20,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        AvatarButton(name: name, onTap: onAvatarTap),
      ],
    );
  }
}

class AvatarButton extends StatefulWidget {
  const AvatarButton({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  State<AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<AvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final String initial = widget.name.isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : '?';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1.0,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF0F4FF)
                        : const Color(0xFF1C1C1E),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
