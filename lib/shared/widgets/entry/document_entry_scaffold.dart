import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/motion/entry_reveal.dart';
import '../../../core/theme/app_theme.dart';
import '../bounce_tap.dart';
import '../studio_backdrop.dart';

/// Multi-step capture shell: progress, step body, sticky primary CTA.
class DocumentEntryScaffold extends StatelessWidget {
  const DocumentEntryScaffold({
    super.key,
    required this.title,
    required this.stepIndex,
    required this.stepCount,
    required this.body,
    required this.onBack,
    this.primaryLabel,
    this.onPrimary,
    this.primaryEnabled = true,
    this.primaryIcon,
    this.banner,
    this.showProgress = true,
  });

  final String title;
  final int stepIndex;
  final int stepCount;
  final Widget body;
  final VoidCallback onBack;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final IconData? primaryIcon;
  final Widget? banner;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool hasCta = primaryLabel != null && onPrimary != null;

    // Let the scaffold shrink above the keyboard so the bar stays a thin strip
    // (do not paint keyboard height into the CTA background).
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const StudioBackdrop(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _EntryAppBar(
                  title: title,
                  stepLabel: showProgress && stepCount > 1
                      ? '${stepIndex + 1} of $stepCount'
                      : null,
                  onBack: onBack,
                ),
                if (showProgress && stepCount > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _StepProgress(
                      index: stepIndex,
                      count: stepCount,
                    ),
                  ),
                if (banner != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: banner!,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey<int>(stepIndex),
                      child: EntryReveal(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          // Space for sticky bar only (~56 + pads). Keyboard is
                          // handled by resizeToAvoidBottomInset, not extra padding.
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            hasCta
                                ? 88 + (keyboard > 0 ? 8 : bottomInset)
                                : 28 + bottomInset,
                          ),
                          children: <Widget>[body],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasCta)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyCta(
                label: primaryLabel!,
                icon: primaryIcon,
                enabled: primaryEnabled,
                isDark: isDark,
                scheme: scheme,
                // No home-indicator padding while keyboard is open (already inset).
                bottomInset: keyboard > 0 ? 0 : bottomInset,
                onTap: () {
                  if (!primaryEnabled) return;
                  HapticService.select();
                  onPrimary!();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryAppBar extends StatelessWidget {
  const _EntryAppBar({
    required this.title,
    required this.onBack,
    this.stepLabel,
  });

  final String title;
  final String? stepLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color muted = AppTokens.secondaryLabel(scheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: <Widget>[
          BounceTap(
            onTap: onBack,
            scaleFactor: 0.92,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (stepLabel != null)
            Text(
              stepLabel!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double progress = count <= 1 ? 1.0 : (index + 1) / count;

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.75),
                    ],
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

class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.label,
    required this.enabled,
    required this.isDark,
    required this.scheme,
    required this.bottomInset,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final bool isDark;
  final ColorScheme scheme;
  final double bottomInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = isDark ? scheme.primary : scheme.onSurface;
    final Color fg = isDark ? scheme.onPrimary : scheme.surface;

    // Height stays compact: only the bar chrome + button + home-indicator inset.
    // Keyboard offset is applied by the parent Positioned, not as fill padding.
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTokens.separator(scheme),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: BounceTap(
              onTap: enabled ? onTap : null,
              scaleFactor: 0.975,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: enabled
                      ? <BoxShadow>[
                          BoxShadow(
                            color: bg.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, color: fg, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error / info banner for step validation.
class EntryBanner extends StatelessWidget {
  const EntryBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color base = isError ? AppTheme.danger : AppTheme.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: base.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: base,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: base,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
