import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_config.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../../../shared/widgets/rolling_card_page.dart';
import '../application/pass_list_provider.dart';
import '../domain/pass_catalog.dart';
import 'wallet_movie_card.dart';
import 'wallet_ticket_card.dart';

class TicketsTab extends ConsumerStatefulWidget {
  const TicketsTab({super.key});

  @override
  ConsumerState<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends ConsumerState<TicketsTab> {
  int _filterIndex = 0;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<WalletPassItem> _filter(List<WalletPassItem> all) {
    return all
        .where(
          (WalletPassItem p) => _filterIndex == 0
              ? p.status == TicketStatus.active
              : p.status == TicketStatus.expired,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<WalletPassItem>> asyncPasses =
        ref.watch(passListProvider);
    final bool showMockBadge = DevConfig.showDevMenu &&
        ref.watch(devFlagsProvider).isMockPassesActive;
    final double fabClearance =
        MediaQuery.of(context).padding.bottom + 16 + 58 + 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: <Widget>[
              _FilterPill(
                label: 'Active',
                selected: _filterIndex == 0,
                onTap: () {
                  HapticService.select();
                  setState(() {
                    _filterIndex = 0;
                    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
                  });
                },
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Expired',
                selected: _filterIndex == 1,
                onTap: () {
                  HapticService.select();
                  setState(() {
                    _filterIndex = 1;
                    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
                  });
                },
              ),
              if (showMockBadge) ...<Widget>[
                const Spacer(),
                _MockBadge(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: asyncPasses.when(
            loading: () => const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            error: (Object err, StackTrace st) => _ErrorState(
              message: err.toString(),
              onRetry: () => ref.read(passListProvider.notifier).refresh(),
            ),
            data: (List<WalletPassItem> all) {
              final List<WalletPassItem> filtered = _filter(all);
              if (filtered.isEmpty) {
                return _EmptyState(isActive: _filterIndex == 0);
              }
              return Stack(
                children: <Widget>[
                  PageView.builder(
                    controller: _pageCtrl,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int index) {
                      final WalletPassItem item = filtered[index];
                      return RollingCardPage(
                        controller: _pageCtrl,
                        index: index,
                        padding:
                            EdgeInsets.fromLTRB(20, 0, 28, fabClearance),
                        child: switch (item) {
                          TrainPassItem(:final ticket) => WalletTicketCard(
                              key: ValueKey<String>(ticket.id),
                              ticket: ticket,
                            ),
                          MoviePassItem(:final pass) => WalletMovieCard(
                              key: ValueKey<String>(pass.id),
                              pass: pass,
                            ),
                        },
                      );
                    },
                  ),
                  if (filtered.length > 1)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: fabClearance,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pageCtrl,
                          builder: (BuildContext context, Widget? _) {
                            final double page = _pageCtrl.hasClients
                                ? (_pageCtrl.page ?? 0)
                                : 0;
                            return _DotIndicator(
                              count: filtered.length,
                              page: page,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.page});
  final int count;
  final double page;

  static const int _dotThreshold = 5;
  static const double _trackH = 48.0;

  @override
  Widget build(BuildContext context) {
    if (count <= _dotThreshold) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(count, (int i) {
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
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1C1C1E))
                  .withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }

    final double pillH = (_trackH / count).clamp(6.0, _trackH * 0.5);
    final double travel = _trackH - pillH;
    final double offset = (page / (count - 1)).clamp(0.0, 1.0) * travel;
    final Color trackColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1C1C1E);

    return SizedBox(
      width: 4,
      height: _trackH,
      child: Stack(
        children: <Widget>[
          Container(
            width: 4,
            height: _trackH,
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: offset,
            child: Container(
              width: 4,
              height: pillH,
              decoration: BoxDecoration(
                color: trackColor.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFAF52DE).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFAF52DE).withValues(alpha: 0.35),
        ),
      ),
      child: const Text(
        'MOCK',
        style: TextStyle(
          color: Color(0xFFAF52DE),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Filter pill ───────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color activeColor =
        isDark ? theme.colorScheme.primary : const Color(0xFF1F3A60);
    final Color inactiveBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.15);

    return BounceTap(
      onTap: onTap,
      scaleFactor: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : inactiveBorderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B)),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Empty / error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color contentColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.confirmation_number_outlined,
            size: 44,
            color: contentColor.withValues(alpha: 0.58),
          ),
          const SizedBox(height: 12),
          Text(
            isActive ? 'No active passes' : 'No expired passes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              'Couldn’t load passes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            BounceTap(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
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
