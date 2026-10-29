import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

Future<void> showIdMessage(
  BuildContext context,
  String title,
  String message,
) => showCupertinoDialog<void>(
  context: context,
  builder: (ctx) => CupertinoAlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('OK'),
      ),
    ],
  ),
);

class IdSection extends StatelessWidget {
  const IdSection({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surface(Theme.of(context).brightness),
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          children[i],
        ],
      ],
    ),
  );
}

Future<String?> requestIdPdfPassword(
  BuildContext context, {
  bool retry = false,
}) async {
  final controller = TextEditingController();
  try {
    return await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Unlock PDF'),
        content: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                retry
                    ? 'That password did not work. Try again.'
                    : 'Enter the PDF password. It stays on this device and is not saved.',
              ),
            ),
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: 'PDF password',
              onSubmitted: (value) => Navigator.of(ctx).pop(value),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  } finally {
    // Dialog route transitions may still reference its controller for one frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}
