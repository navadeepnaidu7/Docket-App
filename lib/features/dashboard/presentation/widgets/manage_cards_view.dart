import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_items.dart';
import '../../application/trash_provider.dart';
import '../../application/wallet_order_provider.dart';
import 'wallet_row_tile.dart';

/// The wallet index: every document at once, as rows you can act on.
///
/// Home shows one card at a time and is visual; this is the same wallet in a
/// textual, actionable register. It owns four verbs — order (drag), reveal
/// (tap), remove (swipe) and account (count + a route into Trash).
///
/// Structure note: the list is a [SliverReorderableList] inside the page's own
/// [CustomScrollView] rather than a `ReorderableListView` inside an [Expanded].
/// The old shape stretched the grouped card to the full viewport height, so a
/// two-document wallet drew a card border down an otherwise empty screen.
class ManageCardsView extends ConsumerWidget {
  const ManageCardsView({
    super.key,
    required this.items,
    required this.onRevealItem,
    required this.onRemoveItem,
    required this.onOpenTrash,
  });

  final List<Object> items;

  /// Switches Home to this document's card.
  final ValueChanged<Object> onRevealItem;

  /// Runs the shared removal path (trash + list + wallet order).
  final ValueChanged<Object> onRemoveItem;

  final VoidCallback onOpenTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TrashState trash = ref.watch(trashProvider);
    final int trashCount = trash.passports.length + trash.idDocs.length;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    if (items.isEmpty) {
      return _ManageEmptyState(
        trashCount: trashCount,
        onOpenTrash: onOpenTrash,
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(
              '${_documentCount(items.length)} · drag to reorder',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTokens.secondaryLabel(scheme),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: DecoratedSliver(
            decoration: BoxDecoration(
              color: AppTokens.groupedFieldFill(
                scheme,
                isDark: theme.brightness == Brightness.dark,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(
                color: AppTokens.separator(scheme),
                width: 0.5,
              ),
            ),
            sliver: SliverReorderableList(
              itemCount: items.length,
              proxyDecorator: _liftedRow,
              // onReorderItem, not the deprecated onReorder: it hands back a
              // newIndex already adjusted for the removal at oldIndex, so the
              // `if (oldIndex < newIndex) newIndex -= 1` correction the old
              // code carried is not just unnecessary here, it would be wrong.
              onReorderItem: (int oldIndex, int newIndex) {
                HapticService.reorder();
                final List<String> nextIds = items.map(walletItemId).toList();
                nextIds.insert(newIndex, nextIds.removeAt(oldIndex));
                ref.read(walletOrderProvider.notifier).saveOrder(nextIds);
              },
              itemBuilder: (BuildContext context, int index) {
                final Object item = items[index];
                return _ManageRow(
                  key: ValueKey<String>(walletItemId(item)),
                  item: item,
                  index: index,
                  isLast: index == items.length - 1,
                  onReveal: () => onRevealItem(item),
                  onRemove: () => onRemoveItem(item),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
            child: _TrashFooterRow(count: trashCount, onTap: onOpenTrash),
          ),
        ),
      ],
    );
  }

  static String _documentCount(int n) =>
      n == 1 ? '1 document' : '$n documents';
}

/// Lifts the dragged row onto its own elevated surface.
///
/// This replaces the previous `Theme(data: theme.copyWith(canvasColor: ...,
/// shadowColor: ...))` wrapper, which existed only to suppress the drag
/// proxy's default material. Because `copyWith` returns a `ThemeData` that is
/// never `==` the previous one, that wrapper invalidated every descendant
/// reading `Theme.of(context)` — i.e. every row, chip and divider — on every
/// single build. `proxyDecorator` runs once per drag instead.
Widget _liftedRow(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? inner) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final double t = Curves.easeInOut.transform(animation.value);
      return Transform.scale(
        scale: lerpDouble(1.0, 1.02, t)!,
        child: Material(
          color: AppTokens.elevatedSurface(scheme),
          shadowColor: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          elevation: lerpDouble(0, 8, t)!,
          child: inner,
        ),
      );
    },
    child: child,
  );
}

/// One reorderable, revealable, removable row.
class _ManageRow extends StatelessWidget {
  const _ManageRow({
    super.key,
    required this.item,
    required this.index,
    required this.isLast,
    required this.onReveal,
    required this.onRemove,
  });

  final Object item;
  final int index;
  final bool isLast;
  final VoidCallback onReveal;
  final VoidCallback onRemove;

  Future<bool> _confirmRemove(BuildContext context) async {
    final WalletRowMeta meta = WalletRowMeta.of(item);
    HapticService.destructive();
    final bool? ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Remove from wallet?'),
        content: Text(
          '${meta.title} moves to Trash. You can restore it from there.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey<String>('dismiss-${walletItemId(item)}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemove(context),
      onDismissed: (_) => onRemove(),
      background: const _RemoveSwipeBackground(),
      child: WalletRowTile(
        item: item,
        onTap: onReveal,
        showDivider: !isLast,
        trailing: ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.drag_handle_rounded,
              size: 20,
              color: AppTokens.tertiaryLabel(scheme),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveSwipeBackground extends StatelessWidget {
  const _RemoveSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: AppTheme.danger.withValues(alpha: 0.16),
      child: const Icon(
        Icons.delete_outline_rounded,
        size: 22,
        color: AppTheme.danger,
      ),
    );
  }
}

/// Footer row into Trash — makes the picker's third mode reachable from the
/// second, instead of only from the nav-title dropdown.
class _TrashFooterRow extends StatelessWidget {
  const _TrashFooterRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color muted = AppTokens.secondaryLabel(scheme);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        onTap: () {
          HapticService.select();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline_rounded, size: 18, color: muted),
              const SizedBox(width: 10),
              Text(
                count == 0
                    ? 'Trash'
                    : count == 1
                        ? 'Trash · 1 item'
                        : 'Trash · $count items',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTokens.tertiaryLabel(scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostCard {
  const _GhostCard(this.angle, this.scale, this.opacity);

  final double angle;
  final double scale;
  final double opacity;
}

/// Back to front, so the upright card sits on top.
const List<_GhostCard> _ghostCards = <_GhostCard>[
  _GhostCard(-0.20, 0.86, 0.45),
  _GhostCard(0.14, 0.93, 0.70),
  _GhostCard(0.0, 1.0, 1.0),
];

/// Three empty card outlines, fanned. The same mini-card shape the rows use,
/// with nothing in it — rather than a glyph inside a tinted circle.
class GhostCardStack extends StatelessWidget {
  const GhostCardStack({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color line = AppTokens.separator(scheme);

    return SizedBox(
      width: 108,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final _GhostCard card in _ghostCards)
            Transform.rotate(
              angle: card.angle,
              child: Transform.scale(
                scale: card.scale,
                child: Container(
                  width: 84,
                  height: 53,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: line.withValues(alpha: card.opacity),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManageEmptyState extends StatelessWidget {
  const _ManageEmptyState({required this.trashCount, required this.onOpenTrash});

  final int trashCount;
  final VoidCallback onOpenTrash;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color muted = AppTokens.secondaryLabel(scheme);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const GhostCardStack(),
            const SizedBox(height: 24),
            Text(
              'No cards in wallet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cards you add on Home appear here, where you can reorder or '
              'remove them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                height: 1.4,
              ),
            ),
            if (trashCount > 0) ...<Widget>[
              const SizedBox(height: 20),
              _TrashFooterRow(count: trashCount, onTap: onOpenTrash),
            ],
          ],
        ),
      ),
    );
  }
}
