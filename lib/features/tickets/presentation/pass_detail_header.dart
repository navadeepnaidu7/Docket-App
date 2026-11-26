import 'package:flutter/material.dart';

import '../domain/pass_catalog.dart';
import 'pass_remove_flow.dart';
import 'pass_typography.dart';

/// Common detail chrome; category terminology and copy targets stay explicit.
class PassDetailHeader extends StatelessWidget {
  const PassDetailHeader({
    super.key,
    required this.item,
    required this.copyLabel,
    required this.copyValue,
    this.title = 'E-Ticket',
  });

  final WalletPassItem item;
  final String title;
  final String copyLabel;
  final String copyValue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: <Widget>[
        const CloseButton(),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: PassType.screenTitle(
              Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        PassOverflowButton(
          item: item,
          copyLabel: copyLabel,
          copyValue: copyValue,
        ),
      ],
    ),
  );
}
