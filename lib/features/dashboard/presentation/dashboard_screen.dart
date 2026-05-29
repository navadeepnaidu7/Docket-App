import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../ids/presentation/add_id_sheet.dart';
import '../../ids/presentation/id_entry_screen.dart';
import '../../ids/presentation/wallet_id_card.dart';
import '../../passport/application/passport_draft_controller.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_entry_screen.dart';
import '../../tickets/presentation/tickets_tab.dart';
import 'wallet_passport_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutQuint),
    ));
    _tabCtrl = TabController(length: 2, vsync: this);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _openPassportEntry(bool isEPassport) {
    ref.read(passportDraftProvider.notifier).reset();
    ref.read(passportDraftProvider.notifier).updateIsEPassport(isEPassport);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const PassportEntryScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openIdEntry(IdDocumentType type) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => IdEntryScreen(type: type),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet() {
    HapticFeedback.mediumImpact();
    if (_tabCtrl.index == 0) {
      // Docs tab — choose Passport or ID
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddItemSheet(
          onAddPassport: () {
            Navigator.of(context).pop();
            _showPassportTypeSheet();
          },
          onAddId: () {
            Navigator.of(context).pop();
            showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddIdSheet(onSelectType: _openIdEntry),
            );
          },
        ),
      );
    } else {
      // Tickets tab — coming soon
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _TicketsComingSoonSheet(),
      );
    }
  }

  void _showPassportTypeSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassportTypeSheet(
        onSelectEPassport: () {
          Navigator.of(context).pop();
          _openPassportEntry(true);
        },
        onSelectRegularPassport: () {
          Navigator.of(context).pop();
          _openPassportEntry(false);
        },
      ),
    );
  }

  void _showSettingsSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }

  void _showDeleteDialog(PassportProfile profile) {
    HapticFeedback.heavyImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Remove Passport?'),
        message: Text(
          'This will remove ${profile.name}\'s passport from your wallet.',
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(passportListProvider.notifier).removePassport(profile.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showDeleteIdDialog(IdDocument doc) {
    HapticFeedback.heavyImpact();
    final String label = doc.holderName.isEmpty ? 'this card' : "${doc.holderName}'s";
    final String type = doc.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card';
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Remove ID Card?'),
        message: Text('This will remove $label $type from your wallet.'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(idListProvider.notifier).removeDocument(doc.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);

    final String currentName = passports.isNotEmpty ? passports.first.name : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        extendBody: true,
        body: Stack(
          children: <Widget>[
            const RepaintBoundary(child: _WalletBackdrop()),
            SafeArea(
              child: FadeTransition(
                opacity: _entryFade,
                child: SlideTransition(
                  position: _entrySlide,
                  child: Column(
                    children: [
                      // ── Header ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  () {
                                    final hour = DateTime.now().hour;
                                    if (hour < 12) return 'Good morning,';
                                    if (hour < 17) return 'Good afternoon,';
                                    return 'Good evening,';
                                  }(),
                                  style: const TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentName.isEmpty
                                      ? 'User'
                                      : currentName.split(' ').first,
                                  style: const TextStyle(
                                    color: Color(0xFF1C1C1E),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                              ],
                            ),
                            _GlassIconButton(
                              icon: Icons.settings_rounded,
                              onTap: _showSettingsSheet,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Tab content ──────────────────────────────────────
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          clipBehavior: Clip.none,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            // Tab 0: Docs (Passports + IDs combined)
                            _DocsTab(
                              passports: passports,
                              idDocs: idDocs,
                              onDeletePassport: _showDeleteDialog,
                              onDeleteId: _showDeleteIdDialog,
                            ),

                            // Tab 1: Tickets
                            const TicketsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom island bar (pill tabs + add button) ───────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PillTabBar(controller: _tabCtrl),
                    const SizedBox(width: 10),
                    _AddFab(onTap: _showAddSheet),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FROSTED PILL TAB BAR ─────────────────────────────────────────────────────

class _PillTabBar extends StatefulWidget {
  const _PillTabBar({required this.controller});
  final TabController controller;

  @override
  State<_PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<_PillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.animation!.addListener(_onTabAnim);
  }

  @override
  void dispose() {
    widget.controller.animation!.removeListener(_onTabAnim);
    super.dispose();
  }

  void _onTabAnim() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final double t = (widget.controller.animation!.value).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 52,
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 0.5,
            ),
          ),
          child: Stack(
            children: [
              // Spring-animated indicator pill
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment(t * 2 - 1, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Labels
              Row(
                children: [
                  _TabLabel(label: 'Docs', index: 0, controller: widget.controller, t: t),
                  _TabLabel(label: 'Tickets', index: 1, controller: widget.controller, t: t),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.index,
    required this.controller,
    required this.t,
  });
  final String label;
  final int index;
  final TabController controller;
  final double t;

  @override
  Widget build(BuildContext context) {
    final bool selected = index == 0 ? t < 0.5 : t >= 0.5;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          controller.animateTo(index);
        },
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: selected ? Colors.white : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DOCS TAB (passports + IDs combined) ─────────────────────────────────────

class _DocsTab extends StatefulWidget {
  const _DocsTab({
    required this.passports,
    required this.idDocs,
    required this.onDeletePassport,
    required this.onDeleteId,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final void Function(PassportProfile) onDeletePassport;
  final void Function(IdDocument) onDeleteId;

  @override
  State<_DocsTab> createState() => _DocsTabState();
}

class _DocsTabState extends State<_DocsTab> {
  late final PageController _pageCtrl;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onScroll);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onScroll() => setState(() => _page = _pageCtrl.page ?? 0);

  @override
  Widget build(BuildContext context) {
    final double fabClearance = MediaQuery.of(context).padding.bottom + 16 + 52 + 20;
    final items = <Object>[...widget.passports, ...widget.idDocs];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 0, 32, fabClearance),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF4C7CFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded,
                    color: Color(0xFF4C7CFF), size: 36),
              ),
              const SizedBox(height: 20),
              const Text('No Documents Yet',
                  style: TextStyle(color: Color(0xFF1C1C1E),
                      fontSize: 20, fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
              const SizedBox(height: 8),
              const Text('Tap + to add a passport or ID card.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final double delta = (_page - index).clamp(-1.0, 1.0);
            return _RollPage(
              delta: delta,
              padding: EdgeInsets.fromLTRB(20, 8, 44, fabClearance),
              child: item is PassportProfile
                  ? WalletPassportCard(
                      profile: item,
                      onLongPress: () => widget.onDeletePassport(item),
                    )
                  : WalletIdCard(
                      document: item as IdDocument,
                      onLongPress: () => widget.onDeleteId(item),
                    ),
            );
          },
        ),
        if (items.length > 1)
          Positioned(
            right: 14,
            top: 0,
            bottom: fabClearance,
            child: Center(
              child: _DotIndicator(count: items.length, page: _page),
            ),
          ),
      ],
    );
  }
}

// ─── EMPTY TICKETS STATE ──────────────────────────────────────────────────────

// ─── ROLL PAGE TRANSFORM ──────────────────────────────────────────────────────

class _RollPage extends StatelessWidget {
  const _RollPage({
    required this.delta,
    required this.child,
    required this.padding,
  });

  final double delta;   // -1 (above) to +1 (below), 0 = current
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // delta < 0 → card is above (exiting upward): tilt top away, shrink
    // delta > 0 → card is below (entering from below): tilt bottom away, shrink
    final double tilt = delta * 0.38;          // radians of X-axis rotation
    final double scale = 1.0 - delta.abs() * 0.08;
    final double translateY = delta * 24;      // subtle Y nudge

    final Matrix4 m = Matrix4.identity()
      ..setEntry(3, 2, 0.001)                  // perspective
      ..rotateX(tilt)
      ..scale(scale)
      ..translate(0.0, translateY);

    return Padding(
      padding: padding,
      child: Center(
        child: Transform(
          transform: m,
          alignment: delta < 0 ? Alignment.bottomCenter : Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

// ─── DOT INDICATOR ───────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.page});
  final int count;
  final double page;

  static const int _dotThreshold = 5;
  static const double _trackH = 48.0;

  @override
  Widget build(BuildContext context) {
    if (count <= _dotThreshold) {
      // Individual animated dots
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final double distance = (page - i).abs().clamp(0.0, 1.0);
          final double size = lerpDouble(10, 6, distance)!;
          final double opacity = lerpDouble(1.0, 0.25, distance)!;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }

    // Scrollbar pill for many items
    final double pillH = (_trackH / count).clamp(6.0, _trackH * 0.5);
    final double travel = _trackH - pillH;
    final double offset = (page / (count - 1)).clamp(0.0, 1.0) * travel;

    return SizedBox(
      width: 4,
      height: _trackH,
      child: Stack(
        children: [
          // Track
          Container(
            width: 4,
            height: _trackH,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: offset,
            child: Container(
              width: 4,
              height: pillH,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BACKDROP ────────────────────────────────────────────────────────────────

class _WalletBackdrop extends StatefulWidget {
  const _WalletBackdrop({this.tabIndex = 0});

  final int tabIndex;

  @override
  State<_WalletBackdrop> createState() => _WalletBackdropState();
}

class _WalletBackdropState extends State<_WalletBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF2F2F7)),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _AppleCardGradientPainter(_ctrl.value),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppleCardGradientPainter extends CustomPainter {
  _AppleCardGradientPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    void drawOrb(Color color, double cx, double cy, double radius) {
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // Soft amber orb
    final double t1 = progress * 2 * math.pi;
    drawOrb(
      const Color(0xFFFFB347).withValues(alpha: 0.13),
      w * 0.5 + math.cos(t1) * w * 0.35,
      h * 0.3 + math.sin(t1) * h * 0.15,
      w * 0.9,
    );

    // Soft purple orb
    final double t2 = progress * 2 * math.pi + (math.pi * 0.66);
    drawOrb(
      const Color(0xFFCBA1F7).withValues(alpha: 0.10),
      w * 0.3 + math.cos(t2) * w * 0.45,
      h * 0.6 + math.sin(t2) * h * 0.25,
      w * 1.0,
    );

    // Soft blue orb
    final double t3 = progress * 2 * math.pi + (math.pi * 1.33);
    drawOrb(
      const Color(0xFF81D4FA).withValues(alpha: 0.13),
      w * 0.7 + math.cos(t3) * w * 0.3,
      h * 0.5 + math.sin(t3) * h * 0.35,
      w * 0.9,
    );
  }

  @override
  bool shouldRepaint(covariant _AppleCardGradientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─── HEADER WIDGETS ───────────────────────────────────────────────────────────

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
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

// ─── FLOATING ADD BUTTON ──────────────────────────────────────────────────────

class _AddFab extends StatefulWidget {
  const _AddFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _rotateCtrl;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotateAnim = CurvedAnimation(parent: _rotateCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _pressed = true);
        _rotateCtrl.forward();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _rotateCtrl.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _rotateCtrl.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 0.5,
                  ),
                ),
                child: RotationTransition(
                  turns: Tween<double>(begin: 0, end: 0.125).animate(_rotateAnim),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 26,
                    color: Color(0xFF1C1C1E),
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

// ─── ADD ITEM SHEET ───────────────────────────────────────────────────────────

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({required this.onAddPassport, required this.onAddId});

  final VoidCallback onAddPassport;
  final VoidCallback onAddId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(36),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Add Document',
                    style: TextStyle(color: Color(0xFF1C1C1E),
                        fontSize: 26, fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Choose what you'd like to add",
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
                ),
                const SizedBox(height: 24),
                _AddOption(
                  icon: Icons.book_rounded,
                  iconColor: const Color(0xFF4C7CFF),
                  title: 'Passport',
                  subtitle: 'Indian passport or travel document',
                  onTap: onAddPassport,
                ),
                const SizedBox(height: 12),
                _AddOption(
                  icon: Icons.badge_rounded,
                  iconColor: const Color(0xFF1C3252),
                  title: 'ID Card',
                  subtitle: 'PAN Card, Aadhaar or national ID',
                  onTap: onAddId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketsComingSoonSheet extends StatelessWidget {
  const _TicketsComingSoonSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF19D3C5).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_number_rounded,
                      color: Color(0xFF19D3C5), size: 32),
                ),
                const SizedBox(height: 20),
                const Text('Tickets Coming Soon',
                    style: TextStyle(color: Color(0xFF1C1C1E),
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Flight, train, bus and event tickets\nwill be available in a future update.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8E8E93),
                      fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PassportTypeSheet extends StatelessWidget {
  const _PassportTypeSheet({
    required this.onSelectEPassport,
    required this.onSelectRegularPassport,
  });

  final VoidCallback onSelectEPassport;
  final VoidCallback onSelectRegularPassport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(36),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Passport Type',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Which kind of passport are you adding?",
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _AddOption(
                  icon: Icons.nfc_rounded,
                  iconColor: const Color(0xFF4C7CFF),
                  title: 'E-Passport',
                  subtitle: 'Biometric passport with an NFC chip',
                  onTap: onSelectEPassport,
                ),
                const SizedBox(height: 12),
                _AddOption(
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF19D3C5),
                  title: 'Regular Passport',
                  subtitle: 'Standard passport without NFC',
                  onTap: onSelectRegularPassport,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddOption extends StatefulWidget {
  const _AddOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_AddOption> createState() => _AddOptionState();
}

class _AddOptionState extends State<_AddOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC7C7CC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SETTINGS SHEET ───────────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(36),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Wallet Settings',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsRow(
                  icon: Icons.style_rounded,
                  iconColor: const Color(0xFF4C7CFF),
                  title: 'Manage Cards',
                  subtitle: 'Reorder, hide or remove cards',
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF19D3C5),
                  title: 'Security & Privacy',
                  subtitle: 'Biometrics, PIN, data storage',
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  icon: Icons.palette_rounded,
                  iconColor: const Color(0xFFFFB703),
                  title: 'Appearance',
                  subtitle: 'Card order, theme, display',
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF8E8E93),
                  title: 'About SlickPort',
                  subtitle: 'Version, legal, open source',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => HapticFeedback.selectionClick(),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC7C7CC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
