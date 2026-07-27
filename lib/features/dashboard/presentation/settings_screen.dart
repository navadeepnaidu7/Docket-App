import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/dev/dev_config.dart';
import '../../../core/dev/dev_flags.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/haptics/haptics_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/wallet/wallet_palette.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../application/card_shine_border_provider.dart';
import '../application/wallet_filter_provider.dart';
import '../application/nav_icon_style_provider.dart';
import '../application/nav_labels_provider.dart';
import 'user_card_detail_screen.dart';

/// Apple Card–like hero dimensions (scrolls with the settings list).
const double kSettingsHeroHeight = 226.0;
const double kSettingsHeroRadius = 22.0;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color scaffoldBg = isDark ? const Color(0xFF0A0A0D) : const Color(0xFFF8F8FA);
    final Color surface = isDark ? const Color(0xFF16161A) : const Color(0xFFFFFFFF);
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.05);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
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
                  _AnimatedPressScale(
                    onTap: () {
                      HapticService.select();
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const UserCardDetailScreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      height: kSettingsHeroHeight,
                      child: WalletMembershipCard(
                        passports: passports,
                        idDocs: idDocs,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Tap to open',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: ink.withValues(alpha: isDark ? 0.45 : 0.55),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: ink.withValues(alpha: isDark ? 0.45 : 0.55),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
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
                  if (DevConfig.showDevMenu) ...[
                    const SizedBox(height: 20),
                    _DeveloperSection(
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                    ),
                  ],
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
  return hsl
      .withSaturation((hsl.saturation * 0.70).clamp(0.40, 0.85))
      .withLightness(0.68)
      .toColor();
}

List<Color> _walletWashColors({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
  required CardFluidScheme scheme,
}) {
  switch (scheme) {
    case CardFluidScheme.titaniumClassic:
      return const <Color>[Color(0xFF8E8E93), Color(0xFF636366), Color(0xFFAEAEE2)];
    case CardFluidScheme.emerald:
      return const <Color>[Color(0xFF2A9D6B), Color(0xFF34D399), Color(0xFF059669)];
    case CardFluidScheme.vibrantSunset:
      return const <Color>[Color(0xFFE07A2F), Color(0xFFEC4899), Color(0xFF8B5CF6)];
    case CardFluidScheme.neonAurora:
      return const <Color>[Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)];
    case CardFluidScheme.goldenHour:
      return const <Color>[Color(0xFFF59E0B), Color(0xFFF43F5E), Color(0xFFD97706)];
    case CardFluidScheme.auto:
      final List<Object> items = <Object>[...passports, ...idDocs];
      if (items.isEmpty) {
        // Iconic Apple Card spending heatmap colors (coral orange, magenta pink, cyan, lime mint, violet)
        return const <Color>[
          Color(0xFFFF7A00),
          Color(0xFFEC4899),
          Color(0xFF00C8FF),
          Color(0xFF10B981),
          Color(0xFF8B5CF6),
        ];
      }

      final List<Color> washes = <Color>[];
      final Set<int> seenHueBuckets = <int>{};

      for (final Object item in items) {
        final Color raw = WalletPalette.forItem(item).primary;
        final Color wash = _toWashAccent(raw, isDark: false);
        final int bucket = (HSLColor.fromColor(wash).hue / 28).round();
        if (seenHueBuckets.add(bucket) || washes.length < 2) {
          washes.add(wash);
        }
        if (washes.length >= 5) break;
      }

      if (washes.length < 2 && items.length > 1) {
        for (final Object item in items) {
          washes.add(
            _toWashAccent(WalletPalette.forItem(item).secondary, isDark: false),
          );
          if (washes.length >= 3) break;
        }
      }

      return washes;
  }
}

List<Color> _membershipBaseColors(List<Color> washes) {
  const Color whiteBase = Color(0xFFFAFAFC);
  const Color silverMid = Color(0xFFF2F3F7);
  const Color titaniumLift = Color(0xFFE8EBF0);
  if (washes.isEmpty) return const <Color>[whiteBase, silverMid, titaniumLift];
  return <Color>[
    Color.lerp(whiteBase, washes.first, 0.12)!,
    Color.lerp(silverMid, washes.length > 1 ? washes[1] : washes.first, 0.10)!,
    Color.lerp(titaniumLift, washes.length > 2 ? washes[2] : washes.first, 0.08)!,
  ];
}

class WalletMembershipCard extends ConsumerStatefulWidget {
  const WalletMembershipCard({
    super.key,
    required this.passports,
    required this.idDocs,
    required this.isDark,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final bool isDark;

  @override
  ConsumerState<WalletMembershipCard> createState() => _WalletMembershipCardState();
}

class _WalletMembershipCardState extends ConsumerState<WalletMembershipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryAnimation;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..addListener(_onMotionTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);

    final Animation<double>? nextPrimary = route?.animation;
    if (!identical(nextPrimary, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteChanged);
      _routeAnimation = nextPrimary;
      _routeAnimation?.addStatusListener(_onRouteChanged);
    }

    final Animation<double>? nextSecondary = route?.secondaryAnimation;
    if (!identical(nextSecondary, _secondaryAnimation)) {
      _secondaryAnimation?.removeListener(_onSecondaryTick);
      _secondaryAnimation = nextSecondary;
      _secondaryAnimation?.addListener(_onSecondaryTick);
    }

    _syncMotion();
  }

  void _onRouteChanged(AnimationStatus status) => _syncMotion();

  void _onSecondaryTick() => _syncMotion();

  void _onMotionTick() {
    // ~12 unique frames per controller cycle — not 60/120.
    final double next = (_motion.value * 12).floorToDouble() / 12.0;
    if (next != _phase.value) {
      _phase.value = next;
    }
  }

  void _syncMotion() {
    if (!mounted) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final bool routeVisible = route == null ||
        (route.isCurrent && (route.secondaryAnimation?.value ?? 0) == 0);
    final bool shouldRun =
        routeVisible && TickerMode.valuesOf(context).enabled;
    if (shouldRun) {
      if (!_motion.isAnimating) _motion.repeat();
    } else if (_motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteChanged);
    _secondaryAnimation?.removeListener(_onSecondaryTick);
    _motion
      ..removeListener(_onMotionTick)
      ..dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DevFlags devFlags = ref.watch(devFlagsProvider);
    final PassportProfile? primaryPassport =
        widget.passports.isNotEmpty ? widget.passports.first : null;
    final IdDocument? primaryId =
        widget.idDocs.isNotEmpty ? widget.idDocs.first : null;

    final String name = _resolveName(primaryPassport, primaryId);
    final List<Color> washes = _walletWashColors(
      passports: widget.passports,
      idDocs: widget.idDocs,
      scheme: devFlags.cardFluidScheme,
    );
    final List<Color> baseColors = _membershipBaseColors(washes);

    // Crisp Light Titanium Apple Card styling (dark charcoal text for maximum contrast on white titanium)
    const Color ink = Color(0xFF1C1C1E);
    const Color inkMuted = Color(0xFF636366);
    final Color border = Colors.black.withValues(alpha: 0.08);
    final bool hasDocs =
        widget.passports.isNotEmpty || widget.idDocs.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kSettingsHeroRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSettingsHeroRadius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Animated wash layer only — face text stays static.
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _phase,
                builder: (BuildContext context, double phase, _) {
                  final double angle = phase * 6.28318530718;
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
                          phase: phase,
                          isDark: false,
                          empty: !hasDocs,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kSettingsHeroRadius),
                border: Border.all(color: border, width: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'July 2026',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: inkMuted,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.12,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '#4377',
                        style: GoogleFonts.robotoMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: inkMuted,
                          letterSpacing: 0.5,
                        ),
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

  String _resolveName(PassportProfile? passport, IdDocument? id) {
    if (passport != null && passport.name.trim().isNotEmpty) {
      return passport.name.trim();
    }
    if (id != null && id.holderName.trim().isNotEmpty) {
      return id.holderName.trim();
    }
    return 'Your wallet';
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
    // Cap blooms — each radial shader is expensive on Impeller/Android.
    final List<Color> layers = washes.take(3).toList();
    if (layers.isEmpty) return;

    final double twoPi = 6.28318530718;
    final double angle = phase * twoPi;

    for (int i = 0; i < layers.length; i++) {
      final Alignment base = _anchors[i % _anchors.length];
      // Each bloom orbits at a slightly different rate/radius.
      final double speed = 0.55 + i * 0.18;
      final double orbit = 0.12 + i * 0.02;
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
          : ((isDark ? 0.38 : 0.30) + layers.length * 0.03).clamp(0.20, 0.48);
      final double radius = size.shortestSide *
          lerpDouble(1.50, 0.95, i / layers.length.clamp(1, 5))! *
          pulse;

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            layers[i].withValues(alpha: richness * 0.65),
            layers[i].withValues(alpha: richness * 0.25),
            layers[i].withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
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

/// Debug / profile only — mock vs consumer data sources.
class _DeveloperSection extends ConsumerWidget {
  const _DeveloperSection({
    required this.surface,
    required this.borderColor,
    required this.isDark,
  });

  final Color surface;
  final Color borderColor;
  final bool isDark;

  Future<void> _editApiBaseUrl(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final TextEditingController controller =
        TextEditingController(text: flags.apiBaseUrl);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('API base URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com',
              helperText: 'No trailing slash. Empty forces mock.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    HapticService.select();
    await ref.read(devFlagsProvider.notifier).setApiBaseUrl(result);
  }

  Future<void> _selectFluidScheme(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final CardFluidScheme? selected = await showDialog<CardFluidScheme>(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Card Fluidic Gradient Scheme'),
          children: CardFluidScheme.values.map((CardFluidScheme scheme) {
            final bool isCurrent = scheme == flags.cardFluidScheme;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, scheme),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isCurrent
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isCurrent ? const Color(0xFF5E5CE6) : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scheme.label,
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
    if (selected != null) {
      HapticService.select();
      await ref.read(devFlagsProvider.notifier).setCardFluidScheme(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DevFlags flags = ref.watch(devFlagsProvider);
    final String urlLabel = flags.apiBaseUrl.isEmpty
        ? 'Not set'
        : flags.apiBaseUrl;

    return _SettingsSection(
      title: 'Developer',
      surface: surface,
      borderColor: borderColor,
      isDark: isDark,
      children: <Widget>[
        _SettingsToggleRow(
          icon: Icons.science_rounded,
          iconColor: const Color(0xFFAF52DE),
          title: 'Use mock passes',
          subtitle: flags.isMockPassesActive
              ? 'Fixtures · demo train & movie cards'
              : 'Remote repository (consumer path)',
          value: flags.useMockPasses,
          onChanged: (bool v) async {
            HapticService.select();
            await ref.read(devFlagsProvider.notifier).setUseMockPasses(v);
          },
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.palette_rounded,
          iconColor: const Color(0xFF5E5CE6),
          title: 'Card fluid gradient scheme',
          subtitle: flags.cardFluidScheme.label,
          onTap: () => _selectFluidScheme(context, ref),
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.link_rounded,
          iconColor: const Color(0xFF2F6FED),
          title: 'API base URL',
          subtitle: urlLabel,
          onTap: () => _editApiBaseUrl(context, ref),
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.refresh_rounded,
          iconColor: const Color(0xFF30D158),
          title: 'Reload passes',
          onTap: () {
            HapticService.select();
            ref.read(passListProvider.notifier).refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing passes…'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.restart_alt_rounded,
          iconColor: const Color(0xFF8E8E93),
          title: 'Reset dev flags',
          subtitle: 'Compile-time defaults',
          onTap: () async {
            HapticService.select();
            await ref
                .read(devFlagsProvider.notifier)
                .resetToCompileTimeDefaults();
          },
        ),
      ],
    );
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
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
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
        borderRadius: BorderRadius.circular(22.0),
      ),
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
      padding: const EdgeInsets.only(left: 58),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    final Color containerBg = ink.withValues(alpha: isDark ? 0.08 : 0.05);
    final Color iconTint = isDark ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: iconTint),
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
      height: subtitle == null ? 58 : 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            _SettingsRowIcon(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.inter(
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
                      style: GoogleFonts.inter(
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

class _AnimatedPressScale extends StatefulWidget {
  const _AnimatedPressScale({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<_AnimatedPressScale> {
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

    return _AnimatedPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              _SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
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

class _SettingsLinkRow extends StatelessWidget {
  const _SettingsLinkRow({
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

    return _AnimatedPressScale(
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
              _SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: subtitle == null
                    ? Text(
                        title,
                        style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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