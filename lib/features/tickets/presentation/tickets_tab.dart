import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_config.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../../../core/wallet/wallet_layout.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../../../shared/widgets/rolling_card_page.dart';
import '../../../shared/widgets/stacked_card_deck.dart';
import '../../dashboard/application/pass_deck_provider.dart';
import '../application/pass_ingest_controller.dart';
import '../application/pass_list_provider.dart';
import '../domain/pass_catalog.dart';
import 'add/pass_ingest_particle_card.dart';
import 'pass_remove_flow.dart';
import 'wallet_bus_card.dart';
import 'wallet_movie_card.dart';
import 'wallet_ticket_card.dart';

class TicketsTab extends ConsumerStatefulWidget {
  const TicketsTab({super.key, required this.isActive});

  final bool isActive;

  @override
  ConsumerState<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends ConsumerState<TicketsTab> {
  late final PageController _pageCtrl;
  final DeckController _deckCtrl = DeckController();
  String? _focusedIngestId;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _deckCtrl.dispose();
    super.dispose();
  }

  void _focusPass(String id) {
    if (_focusedIngestId == id) return;
    _focusedIngestId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final List<WalletPassItem>? items = ref
          .read(activePassesProvider)
          .valueOrNull;
      if (items == null) return;
      final int index = items.indexWhere(
        (WalletPassItem item) => item.id == id,
      );
      if (index < 0) return;
      if (ref.read(passDeckModeProvider)) {
        _deckCtrl.animateToIndex(index);
      } else if (_pageCtrl.hasClients) {
        _pageCtrl.animateToPage(
          index,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PassIngestUiState ingestState = ref.watch(
      passIngestControllerProvider,
    );
    ref.listen<PassIngestUiState>(passIngestControllerProvider, (
      PassIngestUiState? previous,
      PassIngestUiState next,
    ) {
      if (next is PassIngestRunning) _focusedIngestId = null;
      if (next is PassIngestSucceeded &&
          next.item.status == TicketStatus.active) {
        _focusPass(next.item.id);
      }
    });
    if (ingestState is PassIngestSucceeded &&
        ingestState.item.status == TicketStatus.active) {
      _focusPass(ingestState.item.id);
    }

    // Archived passes live on their own screen; this tab is active passes only.
    final AsyncValue<List<WalletPassItem>> asyncPasses = ref.watch(
      activePassesProvider,
    );

    final bool showMockBadge =
        DevConfig.showDevMenu && ref.watch(devFlagsProvider).isMockPassesActive;
    final bool deckMode = ref.watch(passDeckModeProvider);
    final double fabClearance = WalletLayout.fabClearance(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showMockBadge)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 20, 0),
            child: Align(alignment: Alignment.centerRight, child: _MockBadge()),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              asyncPasses.when(
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
                data: (List<WalletPassItem> filtered) {
                  if (filtered.isEmpty) {
                    return const _EmptyState();
                  }

                  if (deckMode) {
                    return _PassDeckView(
                      items: filtered,
                      fabClearance: fabClearance,
                      controller: _deckCtrl,
                      onRemove: (WalletPassItem item) =>
                          confirmAndRemovePass(context, ref, item),
                    );
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
                            padding: EdgeInsets.fromLTRB(
                              20,
                              0,
                              28,
                              fabClearance,
                            ),
                            child: _passCardFor(
                              item,
                              onLongPress: () =>
                                  confirmAndRemovePass(context, ref, item),
                            ),
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
                                  axis: Axis.vertical,
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (!ingestState.isIdle)
                Positioned.fill(
                  child: PassIngestParticleCard(
                    state: ingestState,
                    isActive: widget.isActive,
                    onFinished: () => ref
                        .read(passIngestControllerProvider.notifier)
                        .dismiss(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Deck mode ───────────────────────────────────────────────────

/// The face for one pass. Shared by both carousel modes so a card can never
/// gain a behaviour in one and not the other.
Widget _passCardFor(WalletPassItem item, {VoidCallback? onLongPress}) {
  return switch (item) {
    TrainPassItem(:final ticket) => WalletTicketCard(
      key: ValueKey<String>(ticket.id),
      ticket: ticket,
      onLongPress: onLongPress,
    ),
    MoviePassItem(:final pass) => WalletMovieCard(
      key: ValueKey<String>(pass.id),
      pass: pass,
      onLongPress: onLongPress,
    ),
    BusPassItem(:final pass) => WalletBusCard(
      key: ValueKey<String>(pass.id),
      pass: pass,
      onLongPress: onLongPress,
    ),
  };
}

/// Passes as a horizontal deck of overlapping cards, swiped sideways.
///
/// Opt-in through Settings → Experimental. Spec in `docs/features/pass-deck.md`.
class _PassDeckView extends StatelessWidget {
  const _PassDeckView({
    required this.items,
    required this.fabClearance,
    required this.controller,
    required this.onRemove,
  });

  final List<WalletPassItem> items;
  final double fabClearance;
  final DeckController controller;
  final ValueChanged<WalletPassItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: StackedCardDeck(
              controller: controller,
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final WalletPassItem item = items[index];
                return _passCardFor(item, onLongPress: () => onRemove(item));
              },
            ),
          ),
        ),
        if (items.length > 1)
          AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? _) => _DotIndicator(
              count: items.length,
              page: controller.position,
              axis: Axis.horizontal,
            ),
          ),
        // Keeps the dots clear of the floating add button rather than
        // overlapping it the way the vertical rail can afford to.
        SizedBox(height: fabClearance),
      ],
    );
  }
}

// ── Dot indicator ────────────────────────────────────────────────

/// Dots (or a scroll pill past [_dotThreshold]) laid out along [axis].
///
/// The roll carousel runs it vertically down the right edge; the deck runs it
/// horizontally under the cards.
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.page,
    required this.axis,
  });

  final int count;
  final double page;
  final Axis axis;

  static const int _dotThreshold = 5;
  static const double _track = 48.0;
  static const double _thickness = 4.0;

  bool get _isVertical => axis == Axis.vertical;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1C1C1E);

    if (count <= _dotThreshold) {
      return Flex(
        direction: axis,
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
            margin: _isVertical
                ? const EdgeInsets.symmetric(vertical: 3)
                : const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }

    final double pill = (_track / count).clamp(6.0, _track * 0.5);
    final double offset =
        (page / (count - 1)).clamp(0.0, 1.0) * (_track - pill);

    return SizedBox(
      width: _isVertical ? _thickness : _track,
      height: _isVertical ? _track : _thickness,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(_thickness / 2),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: _isVertical ? offset : 0,
            left: _isVertical ? 0 : offset,
            child: Container(
              width: _isVertical ? _thickness : pill,
              height: _isVertical ? pill : _thickness,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(_thickness / 2),
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

// ── Empty / error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
            'No active passes',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
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
