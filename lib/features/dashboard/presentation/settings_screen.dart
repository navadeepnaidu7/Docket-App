import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/haptics/haptics_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/wallet/wallet_palette.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../application/card_shine_border_provider.dart';
import '../application/wallet_filter_provider.dart';
import '../application/nav_icon_style_provider.dart';
import '../application/nav_labels_provider.dart';

/// Apple Card–like hero dimensions (scrolls with the settings list).
const double kSettingsHeroHeight = 200.0;
const double kSettingsHeroRadius = 22.0;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    // Effective brightness (respects ThemeMode.system), not just stored mode.
    final bool isDark = theme.brightness == Brightness.dark;
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
              // Single scroll: card is a normal list item (not sticky).
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  SizedBox(
                    height: kSettingsHeroHeight,
                    child: _WalletMembershipCard(
                      passports: passports,
                      idDocs: idDocs,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                        onChanged: (bool enableDark) {
                          HapticService.select();
                          ref.read(themeModeProvider.notifier).setMode(
                                enableDark
                                    ? ThemeMode.dark
                                    : ThemeMode.light,
                              );
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
                          ref.read(hapticsEnabledProvider.notifier).toggle();
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
                          ref.read(showNavLabelsProvider.notifier).toggle();
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
                          ref.read(navIconStylesProvider.notifier).setIdsStyle(
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
                        style: ref.watch(navIconStylesProvider).passes,
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
                          ref.read(cardShineBorderProvider.notifier).toggle();
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
                              builder: (_) => const AboutDocketScreen(),
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
        ),
      ),
    );
  }
}

// ── Apple Card–inspired wallet membership surface ────────────────────────────
//
// Light: white titanium + soft pastel washes.
// Dark: deep slate titanium + richer luminous washes.
// Motion: slow drifting gradient angle + orbiting color blooms.

Color _toWashAccent(Color source, {required bool isDark}) {
  final HSLColor hsl = HSLColor.fromColor(source);
  if (isDark) {
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0.28, 0.62))
        .withLightness(0.52)
        .toColor();
  }
  return hsl
      .withSaturation((hsl.saturation * 0.40).clamp(0.22, 0.52))
      .withLightness(0.78)
      .toColor();
}

List<Color> _walletWashColors({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
  required bool isDark,
}) {
  final List<Object> items = <Object>[...passports, ...idDocs];
  if (items.isEmpty) {
    return isDark
        ? const <Color>[Color(0xFF3A4A68), Color(0xFF2C3A55)]
        : const <Color>[Color(0xFFE8E8ED), Color(0xFFD1D1D6)];
  }

  final List<Color> washes = <Color>[];
  final Set<int> seenHueBuckets = <int>{};

  for (final Object item in items) {
    final Color raw = WalletPalette.forItem(item).primary;
    final Color wash = _toWashAccent(raw, isDark: isDark);
    final int bucket = (HSLColor.fromColor(wash).hue / 28).round();
    if (seenHueBuckets.add(bucket) || washes.length < 2) {
      washes.add(wash);
    }
    if (washes.length >= 5) break;
  }

  if (washes.length < 2 && items.length > 1) {
    for (final Object item in items) {
      washes.add(
        _toWashAccent(WalletPalette.forItem(item).secondary, isDark: isDark),
      );
      if (washes.length >= 3) break;
    }
  }

  return washes;
}

List<Color> _membershipBaseColors(List<Color> washes, {required bool isDark}) {
  if (isDark) {
    const Color deep = Color(0xFF141820);
    const Color mid = Color(0xFF1A2230);
    const Color lift = Color(0xFF243044);
    if (washes.isEmpty) return const <Color>[deep, mid, lift];
    return <Color>[
      Color.lerp(deep, washes.first, 0.28)!,
      Color.lerp(mid, washes.length > 1 ? washes[1] : washes.first, 0.24)!,
      Color.lerp(lift, washes.length > 2 ? washes[2] : washes.first, 0.20)!,
    ];
  }

  const Color a = Color(0xFFFFFFFF);
  const Color b = Color(0xFFF7F7F8);
  const Color c = Color(0xFFEEEEF0);
  if (washes.isEmpty) return const <Color>[a, b, c];
  return <Color>[
    Color.lerp(a, washes.first, 0.30)!,
    Color.lerp(b, washes.length > 1 ? washes[1] : washes.first, 0.24)!,
    Color.lerp(c, washes.length > 2 ? washes[2] : washes.first, 0.18)!,
  ];
}

class _WalletMembershipCard extends StatefulWidget {
  const _WalletMembershipCard({
    required this.passports,
    required this.idDocs,
    required this.isDark,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final bool isDark;

  @override
  State<_WalletMembershipCard> createState() => _WalletMembershipCardState();
}

const String _kWalletJoinedAtKey = 'wallet_joined_at';

const List<String> _kShortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatJoinedLabel(DateTime date) {
  final String month = _kShortMonths[date.month - 1];
  return 'Joined  $month ${date.year}';
}

/// Loads or stamps the wallet join date (first open for legacy installs).
Future<DateTime> _ensureWalletJoinedAt() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? raw = prefs.getString(_kWalletJoinedAtKey);
  if (raw != null) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  final DateTime now = DateTime.now();
  await prefs.setString(_kWalletJoinedAtKey, now.toIso8601String());
  return now;
}

class _WalletMembershipCardState extends State<_WalletMembershipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  String? _joinedLabel;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _loadJoinedDate();
  }

  Future<void> _loadJoinedDate() async {
    final DateTime joined = await _ensureWalletJoinedAt();
    if (!mounted) return;
    setState(() => _joinedLabel = _formatJoinedLabel(joined));
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final PassportProfile? primaryPassport =
        widget.passports.isNotEmpty ? widget.passports.first : null;
    final IdDocument? primaryId =
        widget.idDocs.isNotEmpty ? widget.idDocs.first : null;

    final String name = _resolveName(primaryPassport, primaryId);
    final String detail = _resolveDetail(widget.passports, widget.idDocs);
    final List<Color> washes = _walletWashColors(
      passports: widget.passports,
      idDocs: widget.idDocs,
      isDark: isDark,
    );
    final List<Color> baseColors =
        _membershipBaseColors(washes, isDark: isDark);

    final Color ink = isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final Color inkMuted =
        isDark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final bool hasDocs =
        widget.passports.isNotEmpty || widget.idDocs.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kSettingsHeroRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSettingsHeroRadius),
        child: AnimatedBuilder(
          animation: _motion,
          builder: (BuildContext context, Widget? child) {
            final double t = _motion.value;
            // Slow elliptical drift of the base gradient angle.
            final double angle = t * 6.28318530718;
            final Alignment begin = Alignment(
              -0.95 + 0.18 * math.sin(angle),
              -0.90 + 0.14 * math.cos(angle * 0.85),
            );
            final Alignment end = Alignment(
              0.95 + 0.12 * math.cos(angle * 0.7),
              1.05 + 0.10 * math.sin(angle * 0.9),
            );

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: begin,
                      end: end,
                      colors: baseColors,
                      stops: const <double>[0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _MembershipWashPainter(
                    washes: washes,
                    phase: t,
                    isDark: isDark,
                    empty: !hasDocs,
                  ),
                ),
                // Specular sheen that drifts with motion
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1.0 + 0.35 * math.sin(angle * 0.6),
                        -1.0,
                      ),
                      end: Alignment(
                        0.5 + 0.25 * math.cos(angle * 0.5),
                        0.6,
                      ),
                      colors: <Color>[
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.45),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const <double>[0.0, 0.55],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kSettingsHeroRadius),
                    border: Border.all(color: border, width: 0.5),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Join date left · logo right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (_joinedLabel != null)
                      Expanded(
                        child: Text(
                          _joinedLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            color: inkMuted,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    _DocketLogoMark(size: 34, isDark: isDark),
                  ],
                ),
                const Spacer(),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.12,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    color: inkMuted,
                  ),
                ),
              ],
            ),
          ),
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
}

/// Docket logo — solid on light; slightly lifted on dark for contrast.
class _DocketLogoMark extends StatelessWidget {
  const _DocketLogoMark({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDark ? 0.95 : 0.92,
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          AppAssets.docketLogo,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Soft radial color washes with slow orbital motion.
class _MembershipWashPainter extends CustomPainter {
  _MembershipWashPainter({
    required this.washes,
    required this.phase,
    required this.isDark,
    required this.empty,
  });

  final List<Color> washes;
  final double phase;
  final bool isDark;
  final bool empty;

  static const List<Alignment> _anchors = <Alignment>[
    Alignment(0.85, -0.40),
    Alignment(-0.80, 0.70),
    Alignment(0.65, 0.85),
    Alignment(-0.45, -0.75),
    Alignment(0.10, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> layers = washes.take(5).toList();
    if (layers.isEmpty) return;

    final double twoPi = 6.28318530718;
    final double angle = phase * twoPi;

    for (int i = 0; i < layers.length; i++) {
      final Alignment base = _anchors[i % _anchors.length];
      // Each bloom orbits at a slightly different rate/radius.
      final double speed = 0.55 + i * 0.18;
      final double orbit = 0.10 + i * 0.02;
      final double ax =
          (base.x + orbit * math.sin(angle * speed + i)).clamp(-1.15, 1.15);
      final double ay =
          (base.y + orbit * math.cos(angle * speed * 0.85 + i * 0.7))
              .clamp(-1.15, 1.15);

      final Offset center = Offset(
        size.width * (ax * 0.5 + 0.5),
        size.height * (ay * 0.5 + 0.5),
      );

      final double pulse =
          0.92 + 0.08 * math.sin(angle * (0.9 + i * 0.15) + i);
      final double richness = empty
          ? (isDark ? 0.22 : 0.16)
          : ((isDark ? 0.38 : 0.34) + layers.length * 0.04).clamp(0.30, 0.58);
      final double radius = size.shortestSide *
          lerpDouble(0.95, 0.52, i / layers.length.clamp(1, 5))! *
          pulse;

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            layers[i].withValues(alpha: richness),
            layers[i].withValues(alpha: richness * 0.42),
            layers[i].withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MembershipWashPainter oldDelegate) {
    if (oldDelegate.phase != phase ||
        oldDelegate.isDark != isDark ||
        oldDelegate.empty != empty ||
        oldDelegate.washes.length != washes.length) {
      return true;
    }
    for (int i = 0; i < washes.length; i++) {
      if (oldDelegate.washes[i] != washes[i]) return true;
    }
    return false;
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

class AboutDocketScreen extends StatelessWidget {
  const AboutDocketScreen({super.key});

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
                    'Docket',
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
                      '© 2026 Docket',
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