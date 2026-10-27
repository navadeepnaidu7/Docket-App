import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../../tickets/domain/bus_pass_models.dart';
import '../../../tickets/domain/movie_pass_models.dart';
import '../../../tickets/domain/pass_activity_date.dart';
import '../../../tickets/domain/pass_catalog.dart';
import '../../../tickets/domain/pass_display.dart';
import '../../../tickets/presentation/bus/bus_pass_detail_screen.dart';
import '../../../tickets/presentation/movie_pass_detail_screen.dart';
import '../../../tickets/presentation/ticket_detail_screen.dart';

/// Account summary under the membership card: one paragraph of two-tone text
/// with the apps the passes came from stacked inline, revealed word by word
/// with a blur-in.
class AccountSummary extends StatefulWidget {
  const AccountSummary({
    super.key,
    required this.passes,
    required this.ids,
    required this.passports,
  });

  final List<WalletPassItem> passes;
  final List<IdDocument> ids;
  final List<PassportProfile> passports;

  @override
  State<AccountSummary> createState() => _AccountSummaryState();
}

class _AccountSummaryState extends State<AccountSummary>
    with TickerProviderStateMixin {
  /// Delay between consecutive words entering.
  static const int _staggerMs = 55;

  /// How long one word takes to sharpen.
  static const int _wordMs = 700;

  late final AnimationController _reveal = AnimationController(vsync: this);
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _started = false;

  @override
  void dispose() {
    _reveal.dispose();
    _sheen.dispose();
    super.dispose();
  }

  void _start(int slots, bool reduced) {
    if (_started) return;
    _started = true;
    if (reduced) {
      _reveal.value = 1;
      return;
    }
    _reveal.duration = Duration(milliseconds: slots * _staggerMs + _wordMs);
    _sheen.repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal.forward(from: 0);
    });
  }

  Animation<double> _slot(int slot, int slots) {
    final double total = (slots * _staggerMs + _wordMs).toDouble();
    final double start = slot * _staggerMs / total;
    final double end = math.min(1, (slot * _staggerMs + _wordMs) / total);
    return CurvedAnimation(
      parent: _reveal,
      curve: Interval(start, end, curve: const Cubic(0.2, 0.8, 0.2, 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    final bool dark = b == Brightness.dark;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Color ink = AppTheme.ink(b);
    final Color muted = ink.withValues(alpha: dark ? 0.44 : 0.40);
    final Color page = AppTheme.background(b);

    final _Summary s = _Summary.of(
      widget.passes,
      widget.ids,
      widget.passports,
      dark: dark,
    );

    // Each word takes one slot, each accent phrase and app stack two.
    int slots = 0;
    for (final _Piece p in s.pieces) {
      slots += p.words == null ? 2 : p.words!.length;
    }
    final int captionSlot = slots + 2;
    slots = captionSlot + 2;
    _start(slots, reduced);

    final TextStyle base = AppFonts.ui(
      fontSize: 26,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.7,
      height: 1.42,
      color: ink,
    );

    final List<InlineSpan> spans = <InlineSpan>[];
    int slot = 0;
    void gap() {
      if (spans.isNotEmpty) spans.add(TextSpan(text: ' ', style: base));
    }

    for (final _Piece p in s.pieces) {
      if (p.apps != null) {
        gap();
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AppIconStack(
              apps: p.apps!,
              ringColor: page,
              // A slot late, so the stack sharpens after the word before it.
              reveal: _slot(slot + 1, slots),
              idle: !reduced,
            ),
          ),
        );
        slot += 2;
      } else if (p.gradient != null) {
        gap();
        spans.add(
          _wordSpan(
            p.text,
            base.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
            _slot(slot, slots),
            gradient: p.gradient,
          ),
        );
        slot += 2;
      } else {
        final TextStyle style = base.copyWith(
          color: p.tone == _Tone.ink ? ink : muted,
        );
        for (final String w in p.words!) {
          if (!p.attach || w != p.words!.first) gap();
          spans.add(_wordSpan(w, style, _slot(slot, slots)));
          slot++;
        }
      }
    }

    final TextStyle captionStyle = AppFonts.ui(
      fontSize: 14,
      height: 1.5,
      letterSpacing: -0.1,
      color: muted,
    );
    final TextStyle captionStrong = captionStyle.copyWith(
      color: ink,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(TextSpan(children: spans)),
        if (s.caption != null) ...<Widget>[
          const SizedBox(height: 22),
          _Reveal(
            animation: _slot(captionSlot, slots),
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  for (final (String text, bool strong) in s.caption!)
                    TextSpan(
                      text: text,
                      style: strong ? captionStrong : captionStyle,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  InlineSpan _wordSpan(
    String text,
    TextStyle style,
    Animation<double> animation, {
    List<Color>? gradient,
  }) {
    Widget word = Text(text, style: style);
    if (gradient != null) {
      word = AnimatedBuilder(
        animation: _sheen,
        child: word,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeInOut.transform(_sheen.value);
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (Rect r) =>
                LinearGradient(
                  colors: gradient,
                  tileMode: TileMode.mirror,
                ).createShader(
                  Rect.fromLTWH(r.left - r.width * t, r.top, r.width, r.height),
                ),
            child: child,
          );
        },
      );
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: _Reveal(animation: animation, child: word),
    );
  }
}

/// A live, tappable sentence about the nearest scheduled pass.
class UpNextSummary extends StatefulWidget {
  const UpNextSummary({super.key, required this.passes});

  final List<WalletPassItem> passes;

  @override
  State<UpNextSummary> createState() => _UpNextSummaryState();
}

class _UpNextSummaryState extends State<UpNextSummary> {
  late final Timer _clock;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _open(WalletPassItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => switch (item) {
          TrainPassItem(:final ticket) => TicketDetailScreen(ticket: ticket),
          MoviePassItem(:final pass) => MoviePassDetailScreen(pass: pass),
          BusPassItem(:final pass) => BusPassDetailScreen(pass: pass),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final item = nextUpcomingPass(widget.passes, now);
    if (item == null) return const SizedBox.shrink();
    final start = passStartTime(item)!;
    final b = Theme.of(context).brightness;
    final ink = AppTheme.ink(b);
    final muted = ink.withValues(alpha: b == Brightness.dark ? 0.55 : 0.52);
    final (String title, SummaryApp app) = switch (item) {
      TrainPassItem(:final ticket) => (
        'a train to ${ticket.toName.trim().isNotEmpty ? ticket.toName : ticket.toCode}',
        SummaryApp.irctc,
      ),
      MoviePassItem(:final pass) => (
        passTitle(item),
        switch (pass.brand) {
          MoviePassBrand.bookMyShow => SummaryApp.bookMyShow,
          MoviePassBrand.district => SummaryApp.district,
          _ => SummaryApp.cinema,
        },
      ),
      BusPassItem(:final pass) => (
        pass.resolvedToCity.trim().isEmpty
            ? 'a bus ride'
            : 'a bus to ${pass.resolvedToCity}',
        pass.brand == BusPassBrand.redBus ? SummaryApp.redBus : SummaryApp.bus,
      ),
    };
    final day = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final String when = day == today
        ? 'today'
        : day == DateTime(now.year, now.month, now.day + 1)
        ? 'tomorrow'
        : 'on ${MaterialLocalizations.of(context).formatMediumDate(start)}';
    final remaining = start.difference(now);
    final minutes = (remaining.inSeconds / 60).ceil();
    final String countdown = minutes < 1
        ? 'Starting now'
        : minutes < 60
        ? 'In $minutes ${minutes == 1 ? 'minute' : 'minutes'}'
        : minutes < 1440
        ? 'In ${minutes ~/ 60}h${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}'
        : 'In ${minutes ~/ 1440} ${(minutes ~/ 1440) == 1 ? 'day' : 'days'}';
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(
          TimeOfDay.fromDateTime(start),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        )
        .toLowerCase();

    final style = AppFonts.ui(
      fontSize: 23,
      height: 1.45,
      letterSpacing: -0.5,
      fontWeight: FontWeight.w500,
      color: muted,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Semantics(
        button: true,
        label: 'Next up, $title $when at $time. $countdown. Open pass',
        excludeSemantics: true,
        child: BounceTap(
          scaleFactor: 0.985,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      const TextSpan(text: 'Next up, '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: AppIconTile(
                            app: app,
                            size: 27,
                            ringColor: AppTheme.background(b),
                          ),
                        ),
                      ),
                      TextSpan(
                        text: title,
                        style: TextStyle(color: ink),
                      ),
                      TextSpan(text: ' $when at '),
                      TextSpan(
                        text: time,
                        style: TextStyle(color: ink),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$countdown · Tap to open',
                  style: AppFonts.ui(fontSize: 14, height: 1.5, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades a child in from a blur, like text sharpening as it is typed.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double v = animation.value;
        if (v >= 1) return child!;
        final double sigma = (1 - v) * 7;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 5 * (1 - v)),
            child: sigma < 0.05
                ? child
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: child,
                  ),
          ),
        );
      },
    );
  }
}

// ── App icons ────────────────────────────────────────────────────────────────

/// An app a pass or document came from, drawn as a home-screen icon.
class SummaryApp {
  const SummaryApp({
    required this.name,
    required this.background,
    this.svg,
    this.png,
    this.tint,
    this.glyph = 0.58,
    this.label,
  });

  final String name;

  /// Top-to-bottom fill, like the light falloff on a real app icon.
  final List<Color> background;
  final String? svg;
  final String? png;
  final Color? tint;

  /// Logo size as a fraction of the icon.
  final double glyph;
  final String? label;

  static const SummaryApp bookMyShow = SummaryApp(
    name: 'BookMyShow',
    background: <Color>[Color(0xFFFF5470), Color(0xFFE0304A)],
    svg: AppAssets.bookMyShowLogo,
    tint: Colors.white,
    glyph: 0.62,
  );
  static const SummaryApp district = SummaryApp(
    name: 'District',
    background: <Color>[Color(0xFF8155FF), Color(0xFF5B37E8)],
    svg: AppAssets.districtLogo,
    glyph: 0.7,
  );
  static const SummaryApp cinema = SummaryApp(
    name: 'Movies',
    background: <Color>[Color(0xFF48484C), Color(0xFF1C1C1E)],
    svg: AppAssets.passIconTicket,
    tint: Colors.white,
    glyph: 0.5,
  );
  static const SummaryApp irctc = SummaryApp(
    name: 'IRCTC',
    background: <Color>[Color(0xFFFFFFFF), Color(0xFFEDEDEA)],
    svg: AppAssets.passIconTrain,
    tint: Color(0xFF1B3B8F),
    glyph: 0.54,
  );
  static const SummaryApp redBus = SummaryApp(
    name: 'redBus',
    background: <Color>[Color(0xFFF0606A), Color(0xFFC9333F)],
    svg: AppAssets.passIconBus,
    tint: Colors.white,
    glyph: 0.52,
  );
  static const SummaryApp bus = SummaryApp(
    name: 'Bus',
    background: <Color>[Color(0xFF48484C), Color(0xFF1C1C1E)],
    svg: AppAssets.passIconBus,
    tint: Colors.white,
    glyph: 0.52,
  );
  static const SummaryApp aadhaar = SummaryApp(
    name: 'Aadhaar',
    background: <Color>[Color(0xFFFFFFFF), Color(0xFFEDEDEA)],
    svg: AppAssets.aadhaarLogo,
    glyph: 0.64,
  );
  static const SummaryApp pan = SummaryApp(
    name: 'PAN',
    background: <Color>[Color(0xFF2A62D6), Color(0xFF0E3A8A)],
    label: 'PAN',
  );
  static const SummaryApp passport = SummaryApp(
    name: 'Passport',
    background: <Color>[Color(0xFF34407A), Color(0xFF141C45)],
    png: AppAssets.passportEmblemWatermark,
    tint: Color(0xFFE2C374),
    glyph: 0.56,
  );
}

/// Overlapping app icons that sit inside a line of text.
///
/// At rest each icon drifts by under a pixel, out of phase with its
/// neighbours. A tap sends a hop through the stack.
class AppIconStack extends StatefulWidget {
  const AppIconStack({
    super.key,
    required this.apps,
    required this.ringColor,
    required this.reveal,
    this.idle = true,
    this.size = 32,
  });

  final List<SummaryApp> apps;
  final Color ringColor;
  final Animation<double> reveal;
  final bool idle;
  final double size;

  static const int maxShown = 4;

  @override
  State<AppIconStack> createState() => _AppIconStackState();
}

class _AppIconStackState extends State<AppIconStack>
    with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    if (widget.idle) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    _hop.dispose();
    _press.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticService.select();
    _hop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final double step = size * 0.68;
    final int extra = widget.apps.length - AppIconStack.maxShown;
    final List<SummaryApp> shown = extra > 0
        ? widget.apps.take(AppIconStack.maxShown - 1).toList()
        : widget.apps;
    final int count = shown.length + (extra > 0 ? 1 : 0);

    Widget tileAt(int k) => k < shown.length
        ? AppIconTile(app: shown[k], size: size, ringColor: widget.ringColor)
        : _MoreTile(count: extra + 1, size: size, ringColor: widget.ringColor);

    final Listenable motion = Listenable.merge(<Listenable>[
      widget.reveal,
      _drift,
      _hop,
      _press,
    ]);

    return Semantics(
      label: widget.apps.map((SummaryApp a) => a.name).join(', '),
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) => _press.reverse(),
        onTapCancel: _press.reverse,
        onTap: _onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(
            width: size + step * (count - 1),
            height: size,
            child: AnimatedBuilder(
              animation: motion,
              builder: (BuildContext context, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    for (int k = 0; k < count; k++)
                      _place(k, step, size, tileAt(k)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _place(int k, double step, double size, Widget tile) {
    // Entrance: icons start piled on the first one and spring out to their
    // places, one after another.
    // Starts a beat late so the stack lands after the word before it.
    final double a = (0.25 + k * 0.12).clamp(0.0, 0.6);
    final double r = Interval(
      a,
      1,
    ).transform(widget.reveal.value.clamp(0.0, 1.0));
    final double spring = Curves.easeOutBack.transform(r);
    // Same easing as the words, which [reveal] already carries.
    final double fade = r;

    // Idle drift, out of phase per icon.
    final double phase = _drift.value * 2 * math.pi + k * 1.3;
    final double driftY = widget.idle ? math.sin(phase) * 0.8 : 0;
    final double driftTurn = widget.idle ? math.sin(phase + 1.1) * 0.012 : 0;

    // Tap hop travels left to right.
    final double h0 = k * 0.12;
    final double h = _hop.isAnimating || _hop.value > 0
        ? Interval(h0, math.min(1, h0 + 0.5)).transform(_hop.value)
        : 0;
    final double hopY = -math.sin(h * math.pi) * size * 0.26;
    final double hopTurn = math.sin(h * math.pi * 2) * 0.07;
    final double hopScale = 1 + math.sin(h * math.pi) * 0.08;

    final double press = 1 - Curves.easeOut.transform(_press.value) * 0.06;
    final double blur = (1 - fade) * 7;

    Widget child = tile;
    if (blur > 0.05) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      );
    }

    return Positioned(
      left: step * k * spring,
      top: 0,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, driftY + hopY),
          child: Transform.rotate(
            angle: driftTurn + hopTurn,
            child: Transform.scale(
              scale: (0.7 + 0.3 * spring) * hopScale * press,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// One app icon with home-screen weight: a superellipse, a lit fill, a sharp
/// logo, a hairline edge, a top gloss and a two-layer shadow. A ring in the
/// page colour separates it from the icon it overlaps.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.app,
    required this.size,
    required this.ringColor,
  });

  final SummaryApp app;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(size * 0.27);
    final double g = size * app.glyph;

    Widget logo;
    if (app.svg != null) {
      logo = SvgPicture.asset(
        app.svg!,
        width: g,
        height: g,
        fit: BoxFit.contain,
        colorFilter: app.tint == null
            ? null
            : ColorFilter.mode(app.tint!, BlendMode.srcIn),
      );
    } else if (app.png != null && app.tint == null) {
      // A real app icon: full bleed, the tile only adds the edge and gloss.
      logo = Image.asset(
        app.png!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else if (app.png != null) {
      logo = Image.asset(
        app.png!,
        width: g,
        height: g,
        fit: BoxFit.contain,
        color: app.tint,
        colorBlendMode: app.tint == null ? null : BlendMode.srcIn,
        filterQuality: FilterQuality.high,
      );
    } else {
      logo = Text(
        app.label ?? '',
        style: AppFonts.ui(
          fontSize: size * 0.23,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Colors.white,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(
            color: ringColor,
            width: 2.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.12),
            blurRadius: 1.5,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: app.background,
                ),
              ),
            ),
            Center(child: logo),
            // Gloss: light catching the top edge.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.75,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.count,
    required this.size,
    required this.ringColor,
  });

  final int count;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    final Color ink = AppTheme.ink(b);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: Color.alphaBlend(
          ink.withValues(alpha: 0.10),
          AppTheme.background(b),
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size * 0.27),
          side: BorderSide(
            color: ringColor,
            width: 2.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      child: Text(
        '+$count',
        style: AppFonts.ui(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: ink.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ── Copy ─────────────────────────────────────────────────────────────────────

enum _Tone { muted, ink }

/// A run of the paragraph: plain words, one accent phrase, or an app stack.
class _Piece {
  _Piece.words(String text, this.tone, {this.attach = false})
    : text = text,
      words = text.split(' '),
      gradient = null,
      apps = null;

  _Piece.accent(this.text, this.gradient)
    : tone = _Tone.ink,
      attach = false,
      words = null,
      apps = null;

  _Piece.apps(this.apps)
    : text = '',
      tone = _Tone.ink,
      attach = false,
      words = null,
      gradient = null;

  final String text;
  final _Tone tone;

  /// Joins the first word to the previous run with no space, for punctuation.
  final bool attach;
  final List<String>? words;
  final List<Color>? gradient;
  final List<SummaryApp>? apps;
}

class _Summary {
  const _Summary({required this.pieces, required this.caption});

  final List<_Piece> pieces;
  final List<(String, bool)>? caption;

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _n(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';

  static _Summary of(
    List<WalletPassItem> passes,
    List<IdDocument> ids,
    List<PassportProfile> passports, {
    required bool dark,
  }) {
    final List<Color> warm = dark
        ? const <Color>[Color(0xFFFF6B85), Color(0xFFFFB45C)]
        : const <Color>[Color(0xFFFF4F6D), Color(0xFFF08A2A)];
    final List<Color> cool = dark
        ? const <Color>[Color(0xFF5A9BFF), Color(0xFF6FE0F5)]
        : const <Color>[Color(0xFF2F7BF6), Color(0xFF22B8D8)];
    final List<Color> violet = dark
        ? const <Color>[Color(0xFF9D8BFF), Color(0xFFE0A0FF)]
        : const <Color>[Color(0xFF6E56F0), Color(0xFFB45CE8)];
    final List<Color> fresh = dark
        ? const <Color>[Color(0xFF3DDC84), Color(0xFFB4F05A)]
        : const <Color>[Color(0xFF1FA463), Color(0xFF6CC22E)];

    int trains = 0;
    int buses = 0;
    final Map<MoviePassBrand, int> movieBrands = <MoviePassBrand, int>{};
    final Map<SummaryApp, int> busApps = <SummaryApp, int>{};
    final Map<(int, int), int> months = <(int, int), int>{};

    for (final WalletPassItem item in passes) {
      switch (item) {
        case TrainPassItem():
          trains++;
        case MoviePassItem(:final pass):
          movieBrands.update(pass.brand, (int c) => c + 1, ifAbsent: () => 1);
        case BusPassItem(:final pass):
          buses++;
          final SummaryApp app = pass.brand == BusPassBrand.redBus
              ? SummaryApp.redBus
              : SummaryApp.bus;
          busApps.update(app, (int c) => c + 1, ifAbsent: () => 1);
      }
      final DateTime? d = PassActivityDate.of(item);
      if (d != null) {
        months.update((d.year, d.month), (int c) => c + 1, ifAbsent: () => 1);
      }
    }
    final int movies = movieBrands.values.fold(0, (int a, int b) => a + b);

    List<SummaryApp> byUse<K>(Map<K, int> m, SummaryApp Function(K) app) {
      final List<MapEntry<K, int>> e = m.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return <SummaryApp>[for (final MapEntry<K, int> x in e) app(x.key)];
    }

    // Travel and cinema clauses, joined "A, B and C."
    final List<List<_Piece>> clauses = <List<_Piece>>[];
    if (movies > 0) {
      clauses.add(<_Piece>[
        _Piece.words('caught', _Tone.muted),
        _Piece.accent(_n(movies, 'movie', 'movies'), warm),
        _Piece.words('on', _Tone.muted),
        _Piece.apps(
          byUse<MoviePassBrand>(
            movieBrands,
            (MoviePassBrand b) => switch (b) {
              MoviePassBrand.bookMyShow => SummaryApp.bookMyShow,
              MoviePassBrand.district => SummaryApp.district,
              _ => SummaryApp.cinema,
            },
          ),
        ),
      ]);
    }
    if (trains > 0) {
      clauses.add(<_Piece>[
        _Piece.words('rode', _Tone.muted),
        _Piece.accent(_n(trains, 'train', 'trains'), cool),
        _Piece.words('with', _Tone.muted),
        _Piece.apps(const <SummaryApp>[SummaryApp.irctc]),
      ]);
    }
    if (buses > 0) {
      clauses.add(<_Piece>[
        _Piece.words('took', _Tone.muted),
        _Piece.accent(_n(buses, 'bus ride', 'bus rides'), violet),
        _Piece.words('with', _Tone.muted),
        _Piece.apps(byUse<SummaryApp>(busApps, (SummaryApp a) => a)),
      ]);
    }

    final List<_Piece> pieces = <_Piece>[];
    if (clauses.isNotEmpty) {
      pieces.add(_Piece.words('You', _Tone.muted));
      for (int i = 0; i < clauses.length; i++) {
        if (i > 0) {
          pieces.add(
            i == clauses.length - 1
                ? _Piece.words('and', _Tone.muted)
                : _Piece.words(',', _Tone.muted, attach: true),
          );
        }
        pieces.addAll(clauses[i]);
      }
      pieces.add(_Piece.words('.', _Tone.muted, attach: true));
    }

    final int idCount = ids.length + passports.length;
    if (idCount > 0) {
      final bool onlyPassports = ids.isEmpty;
      pieces
        ..add(_Piece.words('Your', _Tone.ink))
        ..add(
          _Piece.accent(
            onlyPassports
                ? _n(idCount, 'passport', 'passports')
                : _n(idCount, 'ID', 'IDs'),
            fresh,
          ),
        )
        ..add(
          _Piece.apps(<SummaryApp>[
            if (ids.any((IdDocument d) => d.type == IdDocumentType.aadhaar))
              SummaryApp.aadhaar,
            if (ids.any((IdDocument d) => d.type == IdDocumentType.pan))
              SummaryApp.pan,
            if (passports.isNotEmpty) SummaryApp.passport,
          ]),
        )
        ..add(
          _Piece.words(
            idCount == 1
                ? 'lives right here, only on this phone.'
                : 'live right here, only on this phone.',
            _Tone.ink,
          ),
        );
    }

    if (pieces.isEmpty) {
      pieces
        ..add(_Piece.words('Your Docket is empty.', _Tone.ink))
        ..add(
          _Piece.words(
            'Add a pass or an ID and this page fills itself in.',
            _Tone.muted,
          ),
        );
    }

    List<(String, bool)>? caption;
    if (months.isNotEmpty) {
      final (int, int) peak = months.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
      final double hours = movies * 2.5 + (trains + buses) * 6.0;
      final int days = (hours / 24).round();
      caption = <(String, bool)>[
        ('Busiest in ', false),
        (_months[peak.$2 - 1], true),
        if (hours >= 1) ...<(String, bool)>[
          (' · about ', false),
          (
            days >= 1
                ? _n(days, 'day', 'days')
                : _n(hours.round(), 'hour', 'hours'),
            true,
          ),
          (' on the move', false),
        ],
      ];
    }

    return _Summary(pieces: pieces, caption: caption);
  }
}
