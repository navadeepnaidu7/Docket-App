import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_items.dart';
import '../../../../shared/widgets/line_icon.dart';
import '../../../../shared/widgets/wallet_empty_state.dart';
import '../../application/trash_provider.dart';
import '../../application/wallet_order_provider.dart';
import 'manage_order_preview.dart';
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
    this.onAdd,
  });

  final List<Object> items;

  /// Switches Home to this document's card.
  final ValueChanged<Object> onRevealItem;

  /// Runs the shared removal path (trash + list + wallet order).
  final ValueChanged<Object> onRemoveItem;

  final VoidCallback onOpenTrash;

  /// Opens the add-document menu. Manage hides the dashboard FAB, so the empty
  /// state carries its own action instead of pointing at a button that is gone.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TrashState trash = ref.watch(trashProvider);
    final int trashCount = trash.passports.length + trash.idDocs.length;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    if (items.isEmpty) {
      return WalletEmptyState(
        artwork: const ManageOrderPreview(),
        lead: 'Nothing to arrange yet.',
        prompt: 'Your documents line up here, in the order you choose.',
        actionLabel: 'Add',
        actionIcon: const LineIcon(AppAssets.iconAdd),
        onAction: onAdd,
        // Trash stays reachable with zero documents: an emptied wallet is
        // exactly when someone goes looking for what they removed.
        secondaryLabel: trashCount > 0 ? 'Trash · $trashCount' : 'Trash',
        secondaryIcon: const LineIcon(AppAssets.iconTrash),
        onSecondary: onOpenTrash,
        bottomClearance: bottomInset + 24,
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _ManageCaption(count: items.length),
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
              onReorderStart: (_) => HapticService.longPress(),
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
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 32),
            // A row in the list's own language rather than a floating pill:
            // Trash is another place documents live, not a button.
            child: _TrashEntry(count: trashCount, onTap: onOpenTrash),
          ),
        ),
      ],
    );
  }
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
    return Dismissible(
      key: ValueKey<String>('dismiss-${walletItemId(item)}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemove(context),
      onDismissed: (_) => onRemove(),
      background: const _RemoveSwipeBackground(),
      // Hold anywhere on the row to pick it up. A grip glyph on every row
      // repeated the same mark eighteen times down the list for a gesture
      // the caption already names.
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: WalletRowTile(
          item: item,
          onTap: onReveal,
          showDivider: !isLast,
        ),
      ),
    );
  }
}

/// One quiet line under the header: how many, and the two hidden gestures.
///
/// Replaces a 26 pt two-tone headline ("18 documents. Arrange your wallet.")
/// that stood between the "Manage" title and the list it introduced.
class _ManageCaption extends StatelessWidget {
  const _ManageCaption({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Brightness b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: count == 1 ? '1 document' : '$count documents',
              style: TextStyle(
                color: AppTheme.ink(b),
                fontWeight: FontWeight.w500,
              ),
            ),
            const TextSpan(text: '   Hold to reorder, swipe to remove'),
          ],
        ),
        style: AppFonts.ui(
          fontSize: 14,
          letterSpacing: -0.1,
          color: AppTokens.secondaryLabel(scheme),
        ),
      ),
    );
  }
}

class _TrashEntry extends StatelessWidget {
  const _TrashEntry({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    return Material(
      color: AppTokens.groupedFieldFill(scheme, isDark: isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: BorderSide(color: AppTokens.separator(scheme), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticService.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 40,
                child: LineIcon(
                  AppAssets.iconTrash,
                  size: 20,
                  color: AppTokens.secondaryLabel(scheme),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Trash',
                  style: AppFonts.ui(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: AppTheme.ink(theme.brightness),
                  ),
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: AppFonts.ui(
                    fontSize: 15,
                    color: AppTokens.secondaryLabel(scheme),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: AppTokens.tertiaryLabel(scheme),
              ),
            ],
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
      child: const LineIcon(
        AppAssets.iconTrash,
        size: 22,
        color: AppTheme.danger,
      ),
    );
  }
}
