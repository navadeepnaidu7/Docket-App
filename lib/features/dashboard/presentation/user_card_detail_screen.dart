import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../application/space_archive_provider.dart';
import 'settings_screen.dart';

class UserCardDetailScreen extends ConsumerStatefulWidget {
  const UserCardDetailScreen({super.key});

  @override
  ConsumerState<UserCardDetailScreen> createState() =>
      _UserCardDetailScreenState();
}

class _UserCardDetailScreenState extends ConsumerState<UserCardDetailScreen> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SpaceArchiveData data = ref.watch(spaceArchiveAnalyticsProvider);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);

    // Match Settings dark chrome (neutral graphite, not blue-tinted navy).
    final Color bg =
        isDark ? const Color(0xFF0A0A0D) : theme.scaffoldBackgroundColor;
    final Color ink =
        isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final Color muted =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFFA1A1A6);

    final List<_StoryPage> stories = _buildStories(data, isDark);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () {
                      HapticService.select();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RepaintBoundary(
                child: SizedBox(
                  height: kSettingsHeroHeight,
                  child: WalletMembershipCard(
                    passports: passports,
                    idDocs: idDocs,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RepaintBoundary(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: stories.length,
                    onPageChanged: (int i) {
                      HapticService.select();
                      setState(() => _pageIndex = i);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return _StoryTypography(
                        key: ValueKey<int>(index),
                        page: stories[index],
                        ink: ink,
                        muted: muted,
                        isDark: isDark,
                        active: index == _pageIndex,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _PageDots(
                count: stories.length,
                index: _pageIndex,
                ink: ink,
                muted: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_StoryPage> _buildStories(SpaceArchiveData data, bool isDark) {
    final int trains = data.categoryCounts['Transit'] ?? 0;
    final int movies = data.categoryCounts['Cinema'] ?? 0;
    final int ids = data.totalIdsCount;
    final int passports = data.totalPassportsCount;
    final int credentials = ids + passports;
    final int activityDays = data.dateToPassesMap.length;
    final int yearsSpan = _yearsSpan(data);
    final int lifeDays = _lifeDaysEquivalent(trains: trains, movies: movies);

    final String yearsPhrase = yearsSpan <= 1
        ? 'the past year'
        : 'the last $yearsSpan years';

    return <_StoryPage>[
      _StoryPage(
        lines: <_StoryLine>[
          _StoryLine(
            spans: <_StorySpan>[
              const _StorySpan.muted("You've taken "),
              _StorySpan.emphasis(_countPhrase(trains, 'trip', 'trips')),
              _StorySpan.rollingIcon(
                icon: CupertinoIcons.train_style_one,
                color: const Color(0xFFE07A2F),
              ),
              _StorySpan.muted(' in $yearsPhrase, and '),
              const _StorySpan.muted('caught '),
              _StorySpan.emphasis(_countPhrase(movies, 'movie', 'movies')),
              _StorySpan.rollingIcon(
                icon: Icons.local_movies_rounded,
                color: const Color(0xFF9E121E),
              ),
              const _StorySpan.muted(' with '),
              _StorySpan.inlineAsset(
                assetPath: AppAssets.docketLogo,
                semanticLabel: 'docket',
              ),
              const _StorySpan.muted('. That stacks up to about '),
              _StorySpan.emphasis(
                _countPhrase(lifeDays, 'full day', 'full days'),
              ),
              const _StorySpan.muted(' of your life, kept in one place.'),
            ],
          ),
        ],
      ),
      _StoryPage(
        lines: <_StoryLine>[
          _StoryLine(
            spans: <_StorySpan>[
              const _StorySpan.muted('Your wallet holds '),
              _StorySpan.emphasis(
                _countPhrase(credentials, 'credential', 'credentials'),
              ),
              _StorySpan.rollingIcon(
                icon: CupertinoIcons.lock_shield_fill,
                color: const Color(0xFF2A9D6B),
              ),
              const _StorySpan.muted(' — '),
              _StorySpan.emphasis(
                _countPhrase(passports, 'passport', 'passports'),
              ),
              const _StorySpan.muted(' and '),
              _StorySpan.emphasis(_countPhrase(ids, 'ID', 'IDs')),
              const _StorySpan.muted(
                ' — encrypted on-device, never uploaded for storage.',
              ),
            ],
          ),
        ],
      ),
      _StoryPage(
        lines: <_StoryLine>[
          _StoryLine(
            spans: <_StorySpan>[
              _StorySpan.emphasis(data.topCategoryName),
              _StorySpan.rollingIcon(
                icon: data.topCategoryIcon,
                color: data.topCategoryColor,
              ),
              const _StorySpan.muted(' leads your archive with '),
              _StorySpan.emphasis(
                _countPhrase(
                  data.categoryCounts[data.topCategoryName] ?? 0,
                  'item',
                  'items',
                ),
              ),
              const _StorySpan.muted('. Across '),
              _StorySpan.emphasis(
                _countPhrase(activityDays, 'active day', 'active days'),
              ),
              const _StorySpan.muted(', your busiest stretch was '),
              _StorySpan.emphasis(data.peakMonthName),
              const _StorySpan.muted('.'),
            ],
          ),
        ],
      ),
      _StoryPage(
        lines: <_StoryLine>[
          _StoryLine(
            spans: <_StorySpan>[
              const _StorySpan.muted("You're a "),
              _StorySpan.emphasis(data.milestoneTitle),
              _StorySpan.rollingIcon(
                icon: CupertinoIcons.sparkles,
                color: isDark
                    ? const Color(0xFFFFD60A)
                    : const Color(0xFFB8860B),
              ),
              const _StorySpan.muted(' — '),
              _StorySpan.muted(_polishSubtitle(data.milestoneSubtitle)),
            ],
          ),
        ],
      ),
    ];
  }

  static String _countPhrase(int n, String singular, String plural) {
    final String word = n == 1 ? singular : plural;
    return '$n $word';
  }

  static String _polishSubtitle(String raw) {
    // Soften internal milestone copy for the narrative card.
    if (raw.contains('Top 1%')) {
      return 'among the most active wallets we see, with a rich pass history.';
    }
    if (raw.contains('Consistently')) {
      return 'consistently saving travel and access passes as you go.';
    }
    return 'unlocking seamless tickets and digital verification.';
  }

  static int _yearsSpan(SpaceArchiveData data) {
    if (data.dateToPassesMap.isEmpty) return 1;
    final List<DateTime> dates = data.dateToPassesMap.keys.toList()..sort();
    final int days = dates.last.difference(dates.first).inDays;
    final int years = (days / 365).ceil();
    return years.clamp(1, 10);
  }

  /// Rough “time spent” fun metric: ~2.5h per movie, ~6h per train day.
  static int _lifeDaysEquivalent({required int trains, required int movies}) {
    final double hours = (movies * 2.5) + (trains * 6.0);
    final int days = (hours / 24).round();
    return days.clamp(0, 999);
  }
}

// ── Story model ──────────────────────────────────────────────────────────────

class _StoryPage {
  const _StoryPage({required this.lines});
  final List<_StoryLine> lines;
}

class _StoryLine {
  const _StoryLine({required this.spans});
  final List<_StorySpan> spans;
}

enum _SpanKind { muted, emphasis, icon, asset }

class _StorySpan {
  const _StorySpan._({
    required this.kind,
    this.text,
    this.icon,
    this.color,
    this.assetPath,
    this.semanticLabel,
  });

  const _StorySpan.muted(String text)
      : this._(kind: _SpanKind.muted, text: text);

  const _StorySpan.emphasis(String text)
      : this._(kind: _SpanKind.emphasis, text: text);

  const _StorySpan.rollingIcon({
    required IconData icon,
    required Color color,
  }) : this._(kind: _SpanKind.icon, icon: icon, color: color);

  const _StorySpan.inlineAsset({
    required String assetPath,
    required String semanticLabel,
  }) : this._(
          kind: _SpanKind.asset,
          assetPath: assetPath,
          semanticLabel: semanticLabel,
        );

  final _SpanKind kind;
  final String? text;
  final IconData? icon;
  final Color? color;
  final String? assetPath;
  final String? semanticLabel;
}

// ── Typography layout ────────────────────────────────────────────────────────

class _StoryTypography extends StatelessWidget {
  const _StoryTypography({
    super.key,
    required this.page,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.active,
  });

  final _StoryPage page;
  final Color ink;
  final Color muted;
  final bool isDark;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = GoogleFonts.inter(
      fontSize: 32,
      height: 1.24,
      letterSpacing: -0.9,
      fontWeight: FontWeight.w500,
    );

    return SizedBox.expand(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                for (final _StoryLine line in page.lines)
                  for (final _StorySpan span in line.spans)
                    _buildSpan(span, base),
              ],
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }

  InlineSpan _buildSpan(_StorySpan span, TextStyle base) {
    switch (span.kind) {
      case _SpanKind.muted:
        return TextSpan(
          text: span.text,
          style: base.copyWith(
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        );
      case _SpanKind.emphasis:
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _RollingText(
            text: span.text ?? '',
            style: base.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
            play: active,
          ),
        );
      case _SpanKind.icon:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _RollingIconChip(
              icon: span.icon!,
              color: span.color!,
              isDark: isDark,
              play: active,
            ),
          ),
        );
      case _SpanKind.asset:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _RollingAssetChip(
              assetPath: span.assetPath!,
              label: span.semanticLabel ?? '',
              isDark: isDark,
              play: active,
            ),
          ),
        );
    }
  }
}

// ── Rolling transitions (Codex / Waterlemon style) ───────────────────────────

/// Vertical “roll” for emphasized numbers & words.
class _RollingText extends StatefulWidget {
  const _RollingText({
    required this.text,
    required this.style,
    required this.play,
  });

  final String text;
  final TextStyle style;
  final bool play;

  @override
  State<_RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<_RollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  String _shown = '';
  String _incoming = '';

  @override
  void initState() {
    super.initState();
    _shown = widget.text;
    _incoming = widget.text;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.play) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _RollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _shown = oldWidget.text;
      _incoming = widget.text;
      _ctrl.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _shown = _incoming);
      });
    } else if (!oldWidget.play && widget.play) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Measure tallest line for stable layout.
    final TextPainter measure = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout();

    final double h = measure.height;
    final double w = measure.width;

    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? child) {
        final double p = _t.value;
        // Outgoing rolls up & fades; incoming rolls in from below.
        final double outY = -h * p;
        final double inY = h * (1 - p);
        final double outOp = (1 - p).clamp(0.0, 1.0);
        final double inOp = p.clamp(0.0, 1.0);

        return SizedBox(
          width: w + 2,
          height: h,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                if (p < 1)
                  Transform.translate(
                    offset: Offset(0, outY),
                    child: Opacity(
                      opacity: outOp,
                      child: Text(_shown, style: widget.style),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0, inY),
                  child: Opacity(
                    opacity: inOp == 0 && p == 0 ? 1 : inOp,
                    child: Text(
                      p == 0 ? _shown : _incoming,
                      style: widget.style,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RollingIconChip extends StatefulWidget {
  const _RollingIconChip({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.play,
  });

  final IconData icon;
  final Color color;
  final bool isDark;
  final bool play;

  @override
  State<_RollingIconChip> createState() => _RollingIconChipState();
}

class _RollingIconChipState extends State<_RollingIconChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  IconData _shown = Icons.circle;
  IconData _incoming = Icons.circle;
  Color _shownColor = Colors.grey;
  Color _incomingColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _shown = widget.icon;
    _incoming = widget.icon;
    _shownColor = widget.color;
    _incomingColor = widget.color;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.play) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _RollingIconChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon != widget.icon || oldWidget.color != widget.color) {
      _shown = oldWidget.icon;
      _shownColor = oldWidget.color;
      _incoming = widget.icon;
      _incomingColor = widget.color;
      _ctrl.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _shown = _incoming;
          _shownColor = _incomingColor;
        });
      });
    } else if (!oldWidget.play && widget.play) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double size = 30;
    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? child) {
        final double p = _t.value;
        final double outY = -size * p;
        final double inY = size * (1 - p);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.isDark ? 0.22 : 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (p < 1)
                Transform.translate(
                  offset: Offset(0, outY),
                  child: Opacity(
                    opacity: (1 - p).clamp(0.0, 1.0),
                    child: Icon(_shown, size: 17, color: _shownColor),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, p == 0 ? 0 : inY),
                child: Opacity(
                  opacity: p == 0 ? 1 : p.clamp(0.0, 1.0),
                  child: Icon(
                    p == 0 ? _shown : _incoming,
                    size: 17,
                    color: p == 0 ? _shownColor : _incomingColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RollingAssetChip extends StatefulWidget {
  const _RollingAssetChip({
    required this.assetPath,
    required this.label,
    required this.isDark,
    required this.play,
  });

  final String assetPath;
  final String label;
  final bool isDark;
  final bool play;

  @override
  State<_RollingAssetChip> createState() => _RollingAssetChipState();
}

class _RollingAssetChipState extends State<_RollingAssetChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.play) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _RollingAssetChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.play && widget.play) {
      _ctrl.forward(from: 0);
    } else if (oldWidget.assetPath != widget.assetPath) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double size = 28;
    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? child) {
        final double p = _t.value;
        // Subtle vertical roll + scale on entry.
        final double y = size * (1 - p) * 0.55;
        final double scale = 0.86 + (0.14 * p);
        final double opacity = p == 0 ? 1.0 : p.clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, p == 0 ? 0 : y),
          child: Transform.scale(
            scale: p == 0 ? 1 : scale,
            child: Opacity(
              opacity: opacity,
              child: Semantics(
                label: widget.label,
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SvgPicture.asset(
                    widget.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Page dots ────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.ink,
    required this.muted,
  });

  final int count;
  final int index;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int i) {
        final bool on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: on ? 8 : 6,
          height: on ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? ink.withValues(alpha: 0.85) : muted.withValues(alpha: 0.45),
          ),
        );
      }),
    );
  }
}
