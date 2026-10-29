import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_items.dart';
import '../../../../shared/widgets/docket_button.dart';
import '../../../../shared/widgets/line_icon.dart';
import '../../../../shared/widgets/wallet_empty_state.dart';
import '../../../../shared/widgets/wallet_list_headline.dart';
import '../../application/trash_provider.dart';
import 'trash_tray_preview.dart';
import 'wallet_row_tile.dart';

/// Removed documents, restorable until deleted for good.
///
/// Speaks the same language as Manage, its sibling under the nav-title
/// picker: the two-tone [WalletListHeadline] over a grouped list of
/// [WalletRowTile]s, quiet [DocketButton] pills, Lucide glyphs. Rows are
/// drawn `removed` — faded mini card — so the list reads as "out of the
/// wallet" at a glance. See `docs/features/manage-trash-redesign.md`.
class TrashView extends ConsumerWidget {
  const TrashView({super.key, this.onGoHome});

  /// Switches the dashboard to Home. The empty state's only exit: with
  /// nothing to restore, the wallet itself is the useful place to land.
  final VoidCallback? onGoHome;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    HapticService.destructive();
    final bool? ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteForGood(
    BuildContext context,
    WidgetRef ref,
    Object item,
  ) async {
    final bool ok = await _confirm(
      context,
      title: 'Delete for good?',
      body:
          '${WalletRowMeta.of(item).title} will be erased from this device. '
          'This cannot be undone.',
      action: 'Delete',
    );
    if (!ok) return;
    await ref.read(trashProvider.notifier).permanentlyDeleteItem(item);
  }

  Future<void> _emptyTrash(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final bool ok = await _confirm(
      context,
      title: 'Empty Trash?',
      body:
          '${count == 1 ? '1 document' : '$count documents'} will be erased '
          'from this device. This cannot be undone.',
      action: 'Empty Trash',
    );
    if (!ok) return;
    await ref.read(trashProvider.notifier).emptyTrash();
  }

  void _restore(BuildContext context, WidgetRef ref, Object item) {
    HapticService.select();
    ref.read(trashProvider.notifier).restoreItem(item, ref);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${WalletRowMeta.of(item).title} is back in your wallet',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TrashState trashState = ref.watch(trashProvider);
    final List<Object> items = <Object>[
      ...trashState.passports,
      ...trashState.idDocs,
    ];
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final bool reduced = MediaQuery.disableAnimationsOf(context);

    if (items.isEmpty) {
      return WalletEmptyState(
        artwork: const TrashTrayPreview(),
        lead: 'Trash is empty.',
        prompt: 'Removed documents wait here, ready to come back.',
        actionLabel: 'Go to Home',
        actionIcon: const LineIcon(AppAssets.iconHome),
        actionTone: DocketButtonTone.secondary,
        onAction: onGoHome,
        bottomClearance: bottomInset + 24,
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: bottomInset + 24),
      children: <Widget>[
        WalletListHeadline(
          lead: '${items.length} in Trash.',
          prompt: 'Restore what you need.',
          hint: 'Nothing here is erased until you delete it.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DecoratedBox(
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
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
                  WalletRowTile(
                    key: ValueKey<String>('trash-${walletItemId(items[i])}'),
                    item: items[i],
                    removed: true,
                    showDivider: i != items.length - 1,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        WalletRowAction(
                          icon: AppAssets.iconRestore,
                          color: AppTheme.ink(theme.brightness),
                          tooltip: 'Restore',
                          onTap: () => _restore(context, ref, items[i]),
                        ),
                        const SizedBox(width: 2),
                        WalletRowAction(
                          icon: AppAssets.iconTrash,
                          color: AppTheme.danger,
                          tooltip: 'Delete for good',
                          onTap: () => _deleteForGood(context, ref, items[i]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ).animate(effects: walletRise(2, reduced: reduced)),
        const SizedBox(height: 24),
        Center(
          child: DocketButton(
            label: 'Empty Trash',
            onPressed: () => _emptyTrash(context, ref, items.length),
            tone: DocketButtonTone.secondary,
            expand: false,
            compact: true,
            leading: const LineIcon(AppAssets.iconTrash),
          ),
        ).animate(effects: walletRise(3, reduced: reduced)),
      ],
    );
  }
}
