import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
import 'swipe_to_empty_trash.dart';
import 'trash_tray_preview.dart';
import 'wallet_row_tile.dart';

/// Removed documents, restorable until deleted for good.
///
/// Speaks the same language as Manage, its sibling under the nav-title
/// picker: the two-tone [WalletListHeadline] over a grouped list of
/// [WalletRowTile]s and a bottom swipe control with inline confirmation. Rows are
/// drawn `removed` — faded mini card — so the list reads as "out of the
/// wallet" at a glance. See `docs/features/manage-trash-redesign.md`.
class TrashView extends ConsumerStatefulWidget {
  const TrashView({super.key, this.onGoHome});

  /// Switches the dashboard to Home. The empty state's only exit: with
  /// nothing to restore, the wallet itself is the useful place to land.
  final VoidCallback? onGoHome;

  @override
  ConsumerState<TrashView> createState() => _TrashViewState();
}

class _TrashViewState extends ConsumerState<TrashView> {
  bool _emptying = false;

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
    if (_emptying) return;
    final bool ok = await _confirm(
      context,
      title: 'Delete for good?',
      body:
          '${WalletRowMeta.of(item).title} will be erased from this device. '
          'This cannot be undone.',
      action: 'Delete',
    );
    if (!ok || !mounted || _emptying) return;
    await ref.read(trashProvider.notifier).permanentlyDeleteItem(item);
  }

  Future<void> _emptyTrash(List<String> reviewedIds) async {
    if (_emptying) return;
    final TrashState current = ref.read(trashProvider);
    final Set<String> currentIds = {
      ...current.passports.map(walletItemId),
      ...current.idDocs.map(walletItemId),
    };
    if (!setEquals(currentIds, reviewedIds.toSet())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trash changed. Review it and slide again.'),
        ),
      );
      return;
    }
    if (currentIds.isEmpty) return;
    final controller = ref.read(trashProvider.notifier);
    setState(() => _emptying = true);
    try {
      HapticService.destructive();
      await controller.emptyTrash();
    } finally {
      if (mounted) setState(() => _emptying = false);
    }
  }

  void _restore(BuildContext context, WidgetRef ref, Object item) {
    if (_emptying) return;
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
  Widget build(BuildContext context) {
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
        onAction: widget.onGoHome,
        bottomClearance: bottomInset + 24,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              WalletListHeadline(
                lead: '${items.length} in Trash.',
                prompt: 'Restore what you need.',
                hint: 'Nothing here is erased until you delete it.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ExcludeSemantics(
                  excluding: _emptying,
                  child: ExcludeFocus(
                    excluding: _emptying,
                    child: AbsorbPointer(
                      absorbing: _emptying,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTokens.groupedFieldFill(
                            scheme,
                            isDark: theme.brightness == Brightness.dark,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          border: Border.all(
                            color: AppTokens.separator(scheme),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < items.length; i++)
                              WalletRowTile(
                                key: ValueKey<String>(
                                  'trash-${walletItemId(items[i])}',
                                ),
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
                                      onTap: () =>
                                          _restore(context, ref, items[i]),
                                    ),
                                    const SizedBox(width: 2),
                                    WalletRowAction(
                                      icon: AppAssets.iconTrash,
                                      color: AppTheme.danger,
                                      tooltip: 'Delete for good',
                                      onTap: () => _deleteForGood(
                                        context,
                                        ref,
                                        items[i],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate(effects: walletRise(2, reduced: reduced)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 20),
          child: Center(
            child: SwipeToEmptyTrash(
              itemIds: items.map(walletItemId).toList(growable: false),
              onDelete: _emptyTrash,
            ),
          ),
        ).animate(effects: walletRise(3, reduced: reduced)),
      ],
    );
  }
}
