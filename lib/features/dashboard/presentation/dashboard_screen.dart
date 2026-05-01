import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../passport/application/passport_draft_controller.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_entry_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _openPassportEntry() {
    ref.read(passportDraftProvider.notifier).reset();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 680),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const PassportEntryScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
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
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(onAddPassport: () {
        Navigator.of(context).pop();
        _openPassportEntry();
      }),
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

  @override
  Widget build(BuildContext context) {
    final List<PassportProfile> passports = ref.watch(passportListProvider);

    // Get the currently displayed profile name for the header greeting
    final String currentName = passports.isNotEmpty ? passports.first.name : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        extendBody: true,
        body: Stack(
          children: <Widget>[
            // — deep background —
            const _WalletBackdrop(),

            // — main scrollable content —
            SafeArea(
              child: FadeTransition(
                opacity: _entryFade,
                child: SlideTransition(
                  position: _entrySlide,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: <Widget>[
                      // gear icon header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(26, 40, 22, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Greeting
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentName.isEmpty ? 'User' : currentName.split(' ').first,
                                    style: const TextStyle(
                                      color: Color(0xFF1C1C1E),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              // gear button
                              _GlassIconButton(
                                icon: Icons.settings_rounded,
                                onTap: _showSettingsSheet,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // passport cards page view
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: PageView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: passports.isEmpty ? 1 : passports.length,
                          itemBuilder: (context, index) {
                            final profile = passports.isEmpty ? const PassportProfile.empty() : passports[index];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                              child: Center(
                                child: WalletPassportCard(profile: profile),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // — floating add FAB —
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: _AddFab(onTap: _showAddSheet),
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

// ─── BACKDROP ────────────────────────────────────────────────────────────────

class _WalletBackdrop extends StatefulWidget {
  const _WalletBackdrop();

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
      duration: const Duration(seconds: 14),
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
        decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _AppleCardGradientPainter(_ctrl.value),
            );
          },
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

    // Soft pink/orange orb
    final double t1 = progress * 2 * math.pi;
    drawOrb(
      const Color(0xFFFFB347).withValues(alpha: 0.45),
      w * 0.5 + math.cos(t1) * w * 0.35,
      h * 0.3 + math.sin(t1) * h * 0.15,
      w * 0.9,
    );

    // Soft purple orb
    final double t2 = progress * 2 * math.pi + (math.pi * 0.66);
    drawOrb(
      const Color(0xFFCBA1F7).withValues(alpha: 0.35),
      w * 0.3 + math.cos(t2) * w * 0.45,
      h * 0.6 + math.sin(t2) * h * 0.25,
      w * 1.0,
    );

    // Soft blue orb
    final double t3 = progress * 2 * math.pi + (math.pi * 1.33);
    drawOrb(
      const Color(0xFF81D4FA).withValues(alpha: 0.45),
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
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.90 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: const Color(0xFF1C1C1E).withValues(alpha: 0.85),
                      size: 22,
                    ),
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
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.92 : 1.0,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
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
                    size: 32,
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
  const _AddItemSheet({required this.onAddPassport});

  final VoidCallback onAddPassport;

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
                    'Add to Wallet',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Choose what you'd like to add",
                    style: TextStyle(
                      color: const Color(0xFF8E8E93),
                      fontSize: 15,
                    ),
                  ),
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
                  icon: Icons.confirmation_number_rounded,
                  iconColor: const Color(0xFF19D3C5),
                  title: 'Ticket',
                  subtitle: 'Flight, train or event ticket',
                  onTap: () => Navigator.of(context).pop(),
                  comingSoon: true,
                ),
                const SizedBox(height: 12),
                _AddOption(
                  icon: Icons.badge_rounded,
                  iconColor: const Color(0xFFFFB703),
                  title: 'ID Card',
                  subtitle: 'Aadhaar, PAN or any national ID',
                  onTap: () => Navigator.of(context).pop(),
                  comingSoon: true,
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
    this.comingSoon = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool comingSoon;

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
                        if (widget.comingSoon) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
