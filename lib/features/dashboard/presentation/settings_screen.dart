import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/haptics/haptics_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../application/card_shine_border_provider.dart';
import '../application/wallet_filter_provider.dart';
import '../application/nav_icon_style_provider.dart';
import '../application/nav_labels_provider.dart';

/// Fraction of the available body height reserved for the profile hero.
const double kSettingsProfileHeightFraction = 0.20;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color surface = theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double profileHeight =
                      constraints.maxHeight * kSettingsProfileHeightFraction;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: SizedBox(
                          height: profileHeight,
                          child: _ProfileHeroCard(
                            passports: passports,
                            idDocs: idDocs,
                            isDark: isDark,
                            gradient: settingsProfileGradient(isDark: isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          children: [
                            _SettingsSection(
                              title: 'Appearance',
                              surface: surface,
                              borderColor: borderColor,
                              isDark: isDark,
                              children: [
                                _SettingsToggleRow(
                                  icon: isDark
                                      ? Icons.dark_mode_rounded
                                      : Icons.light_mode_rounded,
                                  iconColor: const Color(0xFF6E40C9),
                                  title: 'Dark mode',
                                  value: isDark,
                                  onChanged: (_) {
                                    HapticService.select();
                                    ref.read(themeModeProvider.notifier).toggle();
                                  },
                                ),
                                const _SettingsDivider(),
                                _SettingsToggleRow(
                                  icon: Icons.vibration_rounded,
                                  iconColor: const Color(0xFFE07A2F),
                                  title: 'Haptics',
                                  value: ref.watch(hapticsEnabledProvider),
                                  onChanged: (_) {
                                    final bool enabled =
                                        ref.read(hapticsEnabledProvider);
                                    if (enabled) HapticService.select();
                                    ref
                                        .read(hapticsEnabledProvider.notifier)
                                        .toggle();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _SettingsSection(
                              title: 'Navigation',
                              surface: surface,
                              borderColor: borderColor,
                              isDark: isDark,
                              children: [
                                _SettingsToggleRow(
                                  icon: CupertinoIcons.textformat_abc,
                                  iconColor: const Color(0xFF2F6FED),
                                  title: 'Labels',
                                  value: ref.watch(showNavLabelsProvider),
                                  onChanged: (_) {
                                    HapticService.select();
                                    ref
                                        .read(showNavLabelsProvider.notifier)
                                        .toggle();
                                  },
                                ),
                                const _SettingsDivider(),
                                _NavIconStyleRow(
                                  icon: CupertinoIcons.creditcard_fill,
                                  iconColor: const Color(0xFF2A9D6B),
                                  title: 'IDs icons',
                                  style: ref.watch(navIconStylesProvider).ids,
                                  onTap: () {
                                    HapticService.select();
                                    final NavIconStyle current =
                                        ref.read(navIconStylesProvider).ids;
                                    ref
                                        .read(navIconStylesProvider.notifier)
                                        .setIdsStyle(
                                          current == NavIconStyle.classic
                                              ? NavIconStyle.vertical
                                              : NavIconStyle.classic,
                                        );
                                  },
                                ),
                                const _SettingsDivider(),
                                _NavIconStyleRow(
                                  icon: CupertinoIcons.ticket_fill,
                                  iconColor: const Color(0xFF1A9BB5),
                                  title: 'Passes icons',
                                  style:
                                      ref.watch(navIconStylesProvider).passes,
                                  onTap: () {
                                    HapticService.select();
                                    final NavIconStyle current =
                                        ref.read(navIconStylesProvider).passes;
                                    ref
                                        .read(navIconStylesProvider.notifier)
                                        .setPassesStyle(
                                          current == NavIconStyle.classic
                                              ? NavIconStyle.vertical
                                              : NavIconStyle.classic,
                                        );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _SettingsSection(
                              title: 'Experimental',
                              surface: surface,
                              borderColor: borderColor,
                              isDark: isDark,
                              children: [
                                _SettingsToggleRow(
                                  icon: Icons.auto_awesome_rounded,
                                  iconColor: const Color(0xFF5E5CE6),
                                  title: 'Card shine border',
                                  subtitle:
                                      'After 3.5s on ID cards, a soft iridescent border appears',
                                  value: ref.watch(cardShineBorderProvider),
                                  onChanged: (_) {
                                    HapticService.select();
                                    ref
                                        .read(cardShineBorderProvider.notifier)
                                        .toggle();
                                  },
                                ),
                                const _SettingsDivider(),
                                _SettingsToggleRow(
                                  icon: Icons.filter_list_rounded,
                                  iconColor: const Color(0xFF2F6FED),
                                  title: 'Card category filter',
                                  subtitle:
                                      'Filter menu on Home — pick a type or clear with ×',
                                  value: ref.watch(walletFilterEnabledProvider),
                                  onChanged: (_) {
                                    HapticService.select();
                                    ref
                                        .read(walletFilterEnabledProvider.notifier)
                                        .toggle();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _SettingsSection(
                              title: 'General',
                              surface: surface,
                              borderColor: borderColor,
                              isDark: isDark,
                              children: [
                                _SettingsLinkRow(
                                  icon: Icons.info_outline_rounded,
                                  iconColor: const Color(0xFF8E8E93),
                                  title: 'About',
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const AboutSlickPortScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// Default profile backdrop — swap or override [gradient] on [_ProfileHeroCard]
/// for custom themes later.
Gradient settingsProfileGradient({required bool isDark}) {
  if (isDark) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF142238),
        Color(0xFF1A3055),
        Color(0xFF243B6E),
      ],
      stops: [0.0, 0.55, 1.0],
    );
  }
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A3A6B),
      Color(0xFF254E8C),
      Color(0xFF3A6BB5),
    ],
    stops: [0.0, 0.5, 1.0],
  );
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.passports,
    required this.idDocs,
    required this.isDark,
    required this.gradient,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final bool isDark;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final PassportProfile? primaryPassport =
        passports.isNotEmpty ? passports.first : null;
    final IdDocument? primaryId = idDocs.isNotEmpty ? idDocs.first : null;

    final String name = _resolveName(primaryPassport, primaryId);
    final String? imageBase64 = _resolveImage(primaryPassport, primaryId);
    final String detail = _resolveDetail(passports, idDocs);
    final String? secondary = _resolveSecondary(primaryPassport, primaryId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF1A3A6B).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -6,
                  ),
                ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ProfileAvatar(
                        name: name,
                        imageBase64: imageBase64,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            if (secondary != null &&
                                secondary.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (detail.isNotEmpty)
                    _ProfileStatPill(label: detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveName(PassportProfile? passport, IdDocument? id) {
    if (passport != null && passport.name.trim().isNotEmpty) {
      return passport.name.trim();
    }
    if (id != null && id.holderName.trim().isNotEmpty) {
      return id.holderName.trim();
    }
    return 'Your wallet';
  }

  String? _resolveImage(PassportProfile? passport, IdDocument? id) {
    if (passport != null && passport.imagePath.isNotEmpty) {
      return passport.imagePath;
    }
    if (id != null && id.imagePath.isNotEmpty) {
      return id.imagePath;
    }
    return null;
  }

  String _resolveDetail(
    List<PassportProfile> passports,
    List<IdDocument> idDocs,
  ) {
    final int total = passports.length + idDocs.length;
    if (total == 0) return 'No cards yet';

    final List<String> parts = <String>[];
    if (idDocs.isNotEmpty) {
      parts.add('${idDocs.length} ID${idDocs.length == 1 ? '' : 's'}');
    }
    if (passports.isNotEmpty) {
      parts.add(
        '${passports.length} pass${passports.length == 1 ? '' : 'es'}',
      );
    }
    return parts.join('  ·  ');
  }

  String? _resolveSecondary(PassportProfile? passport, IdDocument? id) {
    if (passport != null && passport.nationality.trim().isNotEmpty) {
      return passport.nationality.trim();
    }
    if (id != null) {
      final String type =
          id.type == IdDocumentType.pan ? 'PAN' : 'Aadhaar';
      if (id.documentNumber.trim().isNotEmpty) {
        return '$type · ${id.documentNumber.trim()}';
      }
      return type;
    }
    return null;
  }
}

class _ProfileStatPill extends StatelessWidget {
  const _ProfileStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.imageBase64,
    required this.size,
  });

  final String name;
  final String? imageBase64;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String initial = name.isNotEmpty && name != 'Your wallet'
        ? name.trim()[0].toUpperCase()
        : '?';

    Widget inner;
    if (imageBase64 != null && _isBase64Image(imageBase64!)) {
      inner = ClipOval(
        child: Image.memory(
          base64Decode(imageBase64!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.16),
        ),
        child: Center(
          child: Text(
            initial,
            style: GoogleFonts.inter(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: inner,
    );
  }

  bool _isBase64Image(String path) {
    return !path.startsWith('/') && path.length > 100;
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
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
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: muted,
            ),
          ),
        ),
        _SettingsCard(
          surface: surface,
          borderColor: borderColor,
          isDark: isDark,
          children: children,
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
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
    final Widget content = child ??
        (children != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: children!,
              )
            : const SizedBox.shrink());

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: padding != null
              ? Padding(padding: padding!, child: content)
              : content,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final Color dividerColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
        );

    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(height: 1, thickness: 0.5, color: dividerColor),
    );
  }
}

class _SettingsRowIcon extends StatelessWidget {
  const _SettingsRowIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
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
      height: subtitle == null ? 54 : 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _SettingsRowIcon(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
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
                activeTrackColor: Theme.of(context).colorScheme.primary,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIconStyleRow extends StatelessWidget {
  const _NavIconStyleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final NavIconStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final String value =
        style == NavIconStyle.classic ? 'Classic' : 'Vertical';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: muted,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsLinkRow extends StatelessWidget {
  const _SettingsLinkRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticService.tap();
        onTap();
      },
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutSlickPortScreen extends StatelessWidget {
  const AboutSlickPortScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final Color surface = theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'SlickPort',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 20),
                  _SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Built with Flutter and Riverpod.\n\n'
                      'ID card icon by haritselarif on the Noun Project (CC BY 3.0).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '© 2026 SlickPort',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}