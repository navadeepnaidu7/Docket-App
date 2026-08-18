import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_items.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../application/trash_provider.dart';
import 'manage_cards_view.dart' show GhostCardStack;
import 'wallet_row_tile.dart';

/// Removed documents, restorable until deleted for good.
///
/// Rows come from [WalletRowTile], the same widget Manage uses. The two views
/// are siblings under the nav-title picker and used to draw the same document
/// two different ways — including two different blues for "passport" and a PAN
/// card tinted teal because this file ignored [IdDocumentCatalog] entirely.
class TrashView extends ConsumerWidget {
  const TrashView({super.key});

  void _showConfirmDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Object item,
  ) {
    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text(
          'This card will be permanently deleted from your offline wallet and '
          'cannot be restored.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              ref.read(trashProvider.notifier).permanentlyDeleteItem(item);
              Navigator.of(ctx).pop();
            },
          ),
        ],
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

    if (items.isEmpty) {
      return const _TrashEmptyState();
    }

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset + 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            items.length == 1
                ? '1 item · restore or delete for good'
                : '${items.length} items · restore or delete for good',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTokens.secondaryLabel(scheme),
            ),
          ),
        ),
        DecoratedBox(
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
                  showDivider: i != items.length - 1,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      WalletRowAction(
                        icon: Icons.restore_rounded,
                        color: scheme.primary,
                        tooltip: 'Restore',
                        onTap: () {
                          final Object item = items[i];
                          ref.read(trashProvider.notifier).restoreItem(
                                item,
                                ref,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                item is PassportProfile
                                    ? 'Passport restored to wallet'
                                    : 'ID document restored to wallet',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 2),
                      WalletRowAction(
                        icon: Icons.delete_outline_rounded,
                        color: AppTheme.danger,
                        tooltip: 'Delete permanently',
                        onTap: () => _showConfirmDeleteDialog(
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
      ],
    );
  }

}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const GhostCardStack(),
            const SizedBox(height: 24),
            Text(
              'Trash is empty',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cards you remove from your wallet are kept here until you '
              'restore them or delete them for good.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTokens.secondaryLabel(scheme),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
