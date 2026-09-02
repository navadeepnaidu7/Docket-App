import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../application/pass_list_provider.dart';
import '../domain/history_folder.dart';
import '../domain/pass_catalog.dart';
import '../domain/pass_ingest.dart';

/// Confirm, then delete. Used from the wallet long-press, the archive, and
/// the detail overflow sheet.
Future<void> confirmAndRemovePass(
  BuildContext context,
  WidgetRef ref,
  WalletPassItem item, {
  bool popOnSuccess = false,
}) async {
  HapticService.destructive();
  final String title = HistoryPassPresentation.title(item);
  final String subject = title.trim().isEmpty ? 'This pass' : title.trim();

  final bool? confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (BuildContext ctx) => CupertinoActionSheet(
      title: const Text('Remove this pass?'),
      message: Text('$subject will be removed from your wallet.'),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Remove'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref.read(passListProvider.notifier).removePass(item.id);
  } catch (error) {
    if (!context.mounted) return;
    HapticService.error();
    await showPassRemoveError(context, error);
    return;
  }
  if (!context.mounted) return;

  HapticService.success();
  if (popOnSuccess) {
    Navigator.of(context).pop();
    return;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$subject removed from your wallet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<void> showPassRemoveError(BuildContext context, Object error) {
  final String message = error is PassIngestException
      ? error.message
      : 'Check your connection and try again.';
  return showCupertinoDialog<void>(
    context: context,
    builder: (BuildContext ctx) => CupertinoAlertDialog(
      title: const Text('Could not remove pass'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// The `⋯` control on pass detail screens: optional copy, then Remove.
class PassOverflowButton extends ConsumerWidget {
  const PassOverflowButton({
    super.key,
    required this.item,
    this.copyLabel,
    this.copyValue,
  });

  final WalletPassItem item;
  final String? copyLabel;
  final String? copyValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.more_horiz_rounded, size: 24),
      tooltip: 'More',
      onPressed: () {
        HapticService.select();
        _showOverflowSheet(context, ref);
      },
    );
  }

  void _showOverflowSheet(BuildContext context, WidgetRef ref) {
    final String? value = copyValue?.trim();
    final bool canCopy = value != null && value.isNotEmpty;
    final Color danger = AppTheme.danger;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (canCopy)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(copyLabel ?? 'Copy'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    Navigator.pop(ctx);
                    HapticService.confirm();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: danger),
                title: Text(
                  'Remove pass',
                  style: TextStyle(color: danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmAndRemovePass(
                    context,
                    ref,
                    item,
                    popOnSuccess: true,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
