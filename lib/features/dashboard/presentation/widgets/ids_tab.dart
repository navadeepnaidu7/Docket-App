import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../../core/wallet/wallet_filter.dart';
import '../../../../core/wallet/wallet_items.dart';
import '../../application/card_shine_border_provider.dart';
import '../../application/wallet_filter_provider.dart';
import '../../../../shared/widgets/rolling_card_page.dart';
import '../../../../shared/widgets/wallet_card_shine_border.dart';
import '../../../ids/domain/id_document.dart';
import '../../../ids/presentation/wallet_id_card.dart';
import '../../../passport/domain/passport_profile.dart';
import '../wallet_passport_card.dart';
import 'dot_indicator.dart';
import 'wallet_filter_controls.dart';

class IdsTab extends ConsumerStatefulWidget {
  const IdsTab({
    super.key,
    required this.items,
    required this.allItems,
    required this.onDeletePassport,
    required this.onDeleteId,
    required this.pageNotifier,
    this.backdropTilt,
  });

  /// Visible wallet items (may be filtered).
  final List<Object> items;

  /// Full wallet list used to build filter chips.
  final List<Object> allItems;
  final void Function(PassportProfile) onDeletePassport;
  final void Function(IdDocument) onDeleteId;
  final ValueNotifier<double> pageNotifier;
  final WalletBackdropTilt? backdropTilt;

  @override
  ConsumerState<IdsTab> createState() => _IdsTabState();
}

class _IdsTabState extends ConsumerState<IdsTab> {
  late final PageController _pageCtrl;
  List<String> _lastVisibleIds = const [];
  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(_onScroll);
    _lastVisibleIds = _idsFor(widget.items);
  }

  @override
  void didUpdateWidget(IdsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<String> nextIds = _idsFor(widget.items);
    if (!_listEquals(_lastVisibleIds, nextIds)) {
      _lastVisibleIds = nextIds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(0);
        }
        widget.pageNotifier.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onScroll);
    _pageCtrl.dispose();
    super.dispose();
  }

  List<String> _idsFor(List<Object> items) =>
      items.map(walletItemId).toList(growable: false);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onScroll() {
    widget.pageNotifier.value = _pageCtrl.page ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final double fabClearance =
        MediaQuery.of(context).padding.bottom + 16 + 58 + 20;
    final items = widget.items;
    final bool shineEnabled = ref.watch(cardShineBorderProvider);
    final bool filterEnabled = ref.watch(walletFilterEnabledProvider);
    final WalletFilterCategory filterCategory =
        ref.watch(walletFilterCategoryProvider);
    final List<WalletFilterCategory> filterOptions =
        walletFilterOptionsFor(widget.allItems);
    if (widget.allItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 0, 32, fabClearance),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyDocsPreview(),
              const SizedBox(height: 28),
              Text(
                'No Documents Yet',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1C1C1E),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to add a passport or ID card.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final WalletFilterCategory activeFilter = filterOptions.contains(filterCategory)
        ? filterCategory
        : WalletFilterCategory.all;
    final bool showFilterButton =
        filterEnabled && filterOptions.length > 1;

    return Stack(
      children: [
        items.isEmpty
            ? _FilteredEmptyState(
                message: walletFilterEmptyMessage(filterCategory),
                fabClearance: fabClearance,
                onShowAll: () {
                  ref.read(walletFilterCategoryProvider.notifier).resetToAll();
                },
              )
            : Stack(
                children: [
                  PageView.builder(
                      controller: _pageCtrl,
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final Widget card = switch (item) {
                          PassportProfile profile => WalletPassportCard(
                              key: ValueKey<String>('passport-${profile.id}'),
                              profile: profile,
                              backdropTilt: widget.backdropTilt,
                              onLongPress: () =>
                                  widget.onDeletePassport(profile),
                            ),
                          IdDocument document => WalletIdCard(
                              key: ValueKey<String>(
                                'id-${document.id}-${document.type.name}',
                              ),
                              document: document,
                              backdropTilt: widget.backdropTilt,
                              onLongPress: () => widget.onDeleteId(document),
                            ),
                          _ => const SizedBox.shrink(),
                        };

                        return RollingCardPage(
                          controller: _pageCtrl,
                          index: index,
                          padding:
                              EdgeInsets.fromLTRB(20, 8, 28, fabClearance),
                          child: item is IdDocument
                              ? AnimatedBuilder(
                                  animation: _pageCtrl,
                                  builder: (context, _) {
                                    final double page = _pageCtrl.page ?? 0;
                                    final int activeIndex = page
                                        .round()
                                        .clamp(0, items.length - 1);
                                    return WalletCardShineBorder(
                                      enabled: shineEnabled,
                                      isActive: activeIndex == index,
                                      borderRadius: 24,
                                      child: card,
                                    );
                                  },
                                )
                              : card,
                        );
                      },
                    ),
                  if (items.length > 1)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: fabClearance,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pageCtrl,
                          builder: (context, _) {
                            final double page = _pageCtrl.page ?? 0;
                            return DotIndicator(
                              count: items.length,
                              page: page,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
        if (showFilterButton)
          Positioned(
            left: 20,
            top: 12,
            child: WalletFilterControls(
              options: filterOptions,
              selected: activeFilter,
            ),
          ),
      ],
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({
    required this.message,
    required this.fabClearance,
    required this.onShowAll,
  });

  final String message;
  final double fabClearance;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink =
        isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color muted =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, fabClearance),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 40,
              color: muted,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onShowAll,
              child: const Text('Show all cards'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyDocsPreview extends StatefulWidget {
  const EmptyDocsPreview({super.key});

  @override
  State<EmptyDocsPreview> createState() => _EmptyDocsPreviewState();
}

class _EmptyDocsPreviewState extends State<EmptyDocsPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final double shimmerX = lerpDouble(-130, 130, _shimmerCtrl.value)!;
        return SizedBox(
          width: 220,
          height: 164,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GhostDocCard(
                offset: const Offset(-18, 14),
                rotation: -0.13,
                scale: 0.90,
                color: const Color(0xFF2A9D8F),
                shimmerX: shimmerX - 28,
                alpha: 0.48,
              ),
              GhostDocCard(
                offset: const Offset(16, 4),
                rotation: 0.10,
                scale: 0.95,
                color: const Color(0xFF7C5CBF),
                shimmerX: shimmerX + 18,
                alpha: 0.56,
              ),
              GhostDocCard(
                offset: Offset.zero,
                rotation: -0.02,
                scale: 1.0,
                color: const Color(0xFF4C7CFF),
                shimmerX: shimmerX,
                alpha: 0.70,
              ),
            ],
          ),
        );
      },
    );
  }
}

class GhostDocCard extends StatelessWidget {
  const GhostDocCard({
    super.key,
    required this.offset,
    required this.rotation,
    required this.scale,
    required this.color,
    required this.shimmerX,
    required this.alpha,
  });

  final Offset offset;
  final double rotation;
  final double scale;
  final Color color;
  final double shimmerX;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 168,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withValues(alpha: 0.52),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16 * alpha),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.16 * alpha),
                            Colors.white.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 20,
                    child: Container(
                      width: 42,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18 * alpha),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  for (int i = 0; i < 3; i++)
                    Positioned(
                      left: 18,
                      right: 22 + i * 18,
                      bottom: 22 + i * 15,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16 * alpha),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  Positioned(
                    left: shimmerX,
                    top: -26,
                    bottom: -26,
                    child: Transform.rotate(
                      angle: -0.45,
                      child: Container(
                        width: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.38 * alpha),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}