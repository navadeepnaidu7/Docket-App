import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final Color bg = isDark
        ? const Color(0xFF0A0A0D)
        : theme.scaffoldBackgroundColor;
    final Color ink = isDark
        ? const Color(0xFFF2F2F7)
        : const Color(0xFF1C1C1E);
    final Color muted = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFFA1A1A6);

    final List<_StoryPage> stories = _buildStories(data, isDark);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticService.select();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Your Docket',
                    style: GoogleFonts.inter(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_pageIndex + 1} of ${stories.length}',
                    style: GoogleFonts.inter(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
            const SizedBox(height: 14),
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
                        active: index == _pageIndex,
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
              child: _PageDots(
                count: stories.length,
                index: _pageIndex,
                ink: ink,
                muted: muted,
                onTap: (int index) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  );
                },
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
        eyebrow: 'YOUR JOURNEY',
        icon: CupertinoIcons.train_style_one,
        accent: const Color(0xFFE07A2F),
        spans: <_StorySpan>[
          const _StorySpan.muted("You've taken\n"),
          _StorySpan.emphasis(_countPhrase(trains, 'trip', 'trips')),
          const _StorySpan.muted(', caught '),
          _StorySpan.emphasis(_countPhrase(movies, 'movie', 'movies')),
          const _StorySpan.muted(', and saved every moment in '),
          _StorySpan.emphasis('one place.'),
        ],
        caption:
            'Across $yearsPhrase · About ${_countPhrase(lifeDays, 'full day', 'full days')} of experiences',
      ),
      _StoryPage(
        eyebrow: 'PRIVATE BY DESIGN',
        icon: CupertinoIcons.lock_shield_fill,
        accent: const Color(0xFF2A9D6B),
        spans: <_StorySpan>[
          const _StorySpan.muted('Your wallet keeps\n'),
          _StorySpan.emphasis(
            _countPhrase(credentials, 'credential', 'credentials'),
          ),
          const _StorySpan.muted('\nclose and '),
          const _StorySpan.emphasis('completely yours.'),
        ],
        caption:
            '${_countPhrase(passports, 'passport', 'passports')} · ${_countPhrase(ids, 'ID', 'IDs')} · Encrypted on this device',
      ),
      _StoryPage(
        eyebrow: 'YOUR PATTERN',
        icon: data.topCategoryIcon,
        accent: data.topCategoryColor,
        spans: <_StorySpan>[
          _StorySpan.emphasis(data.topCategoryName),
          const _StorySpan.muted('\nleads your archive with '),
          _StorySpan.emphasis(
            _countPhrase(
              data.categoryCounts[data.topCategoryName] ?? 0,
              'item',
              'items',
            ),
          ),
          const _StorySpan.muted('. Your busiest stretch was '),
          _StorySpan.emphasis(data.peakMonthName),
          const _StorySpan.muted('.'),
        ],
        caption:
            '${_countPhrase(activityDays, 'active day', 'active days')} recorded across your archive',
      ),
      _StoryPage(
        eyebrow: 'YOUR MILESTONE',
        icon: CupertinoIcons.sparkles,
        accent: isDark ? const Color(0xFFFFD60A) : const Color(0xFFB8860B),
        spans: <_StorySpan>[
          const _StorySpan.muted("You're a\n"),
          _StorySpan.emphasis(data.milestoneTitle),
          const _StorySpan.muted('.'),
        ],
        caption: _polishSubtitle(data.milestoneSubtitle),
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
  const _StoryPage({
    required this.eyebrow,
    required this.icon,
    required this.accent,
    required this.spans,
    required this.caption,
  });
  final String eyebrow;
  final IconData icon;
  final Color accent;
  final List<_StorySpan> spans;
  final String caption;
}

enum _SpanKind { muted, emphasis }

class _StorySpan {
  const _StorySpan._({required this.kind, this.text});

  const _StorySpan.muted(String text)
    : this._(kind: _SpanKind.muted, text: text);

  const _StorySpan.emphasis(String text)
    : this._(kind: _SpanKind.emphasis, text: text);

  final _SpanKind kind;
  final String? text;
}

// ── Typography layout ────────────────────────────────────────────────────────

class _StoryTypography extends StatelessWidget {
  const _StoryTypography({
    super.key,
    required this.page,
    required this.ink,
    required this.muted,
    required this.active,
  });

  final _StoryPage page;
  final Color ink;
  final Color muted;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).height < 760;
    final TextStyle base = GoogleFonts.inter(
      fontSize: compact ? 31 : 36,
      height: 1.08,
      letterSpacing: -1.25,
      fontWeight: FontWeight.w500,
    );

    return SizedBox.expand(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: active ? 1 : 0),
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: page.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(page.icon, size: 18, color: page.accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    page.eyebrow,
                    style: GoogleFonts.inter(
                      color: page.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.15,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 16 : 22),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    for (final _StorySpan span in page.spans)
                      _buildSpan(span, base),
                  ],
                ),
                textAlign: TextAlign.left,
              ),
              SizedBox(height: compact ? 14 : 20),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: page.accent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page.caption,
                style: GoogleFonts.inter(
                  color: muted,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.15,
                ),
              ),
            ],
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
          style: base.copyWith(color: muted, fontWeight: FontWeight.w500),
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

// ── Page dots ────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  final int count;
  final int index;
  final Color ink;
  final Color muted;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(count, (int i) {
        final bool on = i == index;
        return Expanded(
          child: Semantics(
            button: true,
            selected: on,
            label: 'Story ${i + 1} of $count',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: on
                        ? ink.withValues(alpha: 0.88)
                        : muted.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
