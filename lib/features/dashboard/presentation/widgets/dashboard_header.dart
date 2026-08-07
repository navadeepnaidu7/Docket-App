import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/dev/dev_flags.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../dashboard_screen.dart' show DashboardViewMode;
import 'membership_mesh.dart';

TextStyle dashboardNavTitleStyle(Color ink, {required bool selected}) {
  return GoogleFonts.inter(
    color: selected ? ink : ink.withValues(alpha: 0.38),
    fontSize: 32,
    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
    letterSpacing: -1.2,
    height: 1.0,
  );
}

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
    required this.meshSeed,
    required this.washes,
    required this.isMenuOpen,
    required this.currentMode,
    required this.onHomeTap,
    required this.onAvatarTap,
    required this.headerTitleLink,
    this.showHistoryButton = false,
    this.historySelected = false,
    this.onHistoryTap,
  });

  /// Stable identity string for a user-unique mesh (email, name, or fallback).
  final String meshSeed;
  final List<Color> washes;
  final bool isMenuOpen;
  final DashboardViewMode currentMode;
  final VoidCallback onHomeTap;
  final VoidCallback onAvatarTap;
  final LayerLink headerTitleLink;

  /// Passes-tab History control, shown left of the profile mesh.
  final bool showHistoryButton;
  final bool historySelected;
  final VoidCallback? onHistoryTap;

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
                      style: dashboardNavTitleStyle(ink, selected: true),
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
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showHistoryButton && onHistoryTap != null) ...<Widget>[
                HistoryHeaderButton(
                  selected: historySelected,
                  onTap: onHistoryTap!,
                ),
                const SizedBox(width: 10),
              ],
              ProfileMeshButton(
                meshSeed: meshSeed,
                washes: washes,
                onTap: onAvatarTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact History control for the top bar (moved off the Passes tab row).
class HistoryHeaderButton extends StatelessWidget {
  const HistoryHeaderButton({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color idleBg =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final Color idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.10);
    final Color idleFg =
        isDark ? const Color(0xFFE8E8ED) : const Color(0xFF1C1C1E);

    final Color selectedBg =
        isDark ? const Color(0xFFE8E8ED) : const Color(0xFF1F3A60);
    final Color selectedFg =
        isDark ? const Color(0xFF0A0A0D) : Colors.white;

    final Color bg = selected ? selectedBg : idleBg;
    final Color border = selected ? selectedBg : idleBorder;
    final Color fg = selected ? selectedFg : idleFg;

    return BounceTap(
      onTap: onTap,
      scaleFactor: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: selected ? 10 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            AppAssets.passesHistory,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

/// Squircle membership-mesh profile control (Top Bar design reference).
///
/// Always paints the mesh. [AuthSession.photoBase64] may be stored for later
/// but must not be rendered here until product chooses to use it.
class ProfileMeshButton extends StatefulWidget {
  const ProfileMeshButton({
    super.key,
    required this.meshSeed,
    required this.washes,
    required this.onTap,
  });

  final String meshSeed;
  final List<Color> washes;
  final VoidCallback onTap;

  @override
  State<ProfileMeshButton> createState() => _ProfileMeshButtonState();
}

class _ProfileMeshButtonState extends State<ProfileMeshButton> {
  bool _pressed = false;

  static const double _size = 44;
  static const double _radius = 13;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> baseWashes = widget.washes.isEmpty
        ? walletWashColors(
            passports: const <PassportProfile>[],
            idDocs: const <IdDocument>[],
            scheme: CardFluidScheme.auto,
          )
        : widget.washes;
    final List<Color> washes = personalizeWashes(baseWashes, widget.meshSeed);
    final double phase = meshPhaseForSeed(widget.meshSeed);

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
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MembershipMeshBackground(
                  washes: washes,
                  phase: phase,
                  empty: widget.washes.isEmpty,
                  richAvatar: true,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.22 : 0.55,
                      ),
                      width: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
