import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/card_issuer.dart';
import '../domain/payment_card.dart';

/// Original bank colors on a small white field for both light and dark faces.
/// Names take precedence over stored hints, including on older saved cards.
class BankMark extends StatelessWidget {
  const BankMark({super.key, required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final CardIssuer? issuer = card.bankName.trim().isNotEmpty
        ? issuerFromName(card.bankName)
        : cardIssuers.where((issuer) => issuer.id == card.issuerId).firstOrNull;
    if (issuer == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.asset(
            issuer.logoAsset,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
