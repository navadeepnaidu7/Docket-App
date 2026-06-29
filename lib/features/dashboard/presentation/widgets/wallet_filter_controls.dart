import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/wallet/wallet_filter.dart';
import '../../application/wallet_filter_provider.dart';

class WalletFilterControls extends ConsumerStatefulWidget {
  const WalletFilterControls({
    super.key,
    required this.options,
    required this.selected,
  });

  final List<WalletFilterCategory> options;
  final WalletFilterCategory selected;

  @override
  ConsumerState<WalletFilterControls> createState() =>
      _WalletFilterControlsState();
}

class _WalletFilterControlsState extends ConsumerState<WalletFilterControls> {
  bool _isOpen = false;

  void _toggle() {
    HapticService.tap();
    setState(() => _isOpen = !_isOpen);
  }

  void _select(WalletFilterCategory category) {
    HapticService.select();
    ref.read(walletFilterCategoryProvider.notifier).select(category);
    setState(() => _isOpen = false);
  }

  void _clearActive() {
    HapticService.select();
    ref.read(walletFilterCategoryProvider.notifier).resetToAll();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color muted =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B);
    final Color fill = isDark
        ? Colors.black.withValues(alpha: 0.50)
        : Colors.white.withValues(alpha: 0.92);
    final Color border = isDark
        ? Colors.white.withValues(alpha: _isOpen ? 0.18 : 0.12)
        : Colors.black.withValues(alpha: _isOpen ? 0.10 : 0.06);
    final Color rowFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF2F2F7);

    final WalletFilterCategory active = widget.options.contains(widget.selected)
        ? widget.selected
        : WalletFilterCategory.all;
    final bool hasActiveChip = active != WalletFilterCategory.all;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_isOpen ? 14 : 99),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: fill,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_isOpen ? 14 : 99),
              side: BorderSide(color: border, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _toggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: ink.withValues(alpha: 0.78),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filter',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                              color: ink.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _isOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: ink.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isOpen) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: border,
                    ),
                    for (final WalletFilterCategory category in widget.options)
                      InkWell(
                        onTap: () => _select(category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          color: active == category ? rowFill : null,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: active == category
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color:
                                        active == category ? ink : muted,
                                  ),
                                ),
                              ),
                              if (active == category)
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: ink.withValues(alpha: 0.65),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (hasActiveChip) ...[
          const SizedBox(width: 8),
          _ActiveFilterChip(
            label: active.label,
            onClear: _clearActive,
          ),
        ],
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onClear,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () {
                HapticService.tap();
                onClear();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ink.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}