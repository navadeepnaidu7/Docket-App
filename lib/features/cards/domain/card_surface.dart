import 'package:flutter/material.dart';

import 'card_issuer.dart';
import 'payment_card.dart';

/// One painted face. [light] chooses the Visa blue wordmark and the darker
/// RuPay green; dark faces use white ink and the brighter green.
class CardSurfaceStyle {
  const CardSurfaceStyle({
    required this.background,
    required this.ink,
    required this.light,
  });

  final Color background;
  final Color ink;
  final bool light;
}

const List<CardSurfaceStyle> _hdfc = <CardSurfaceStyle>[
  CardSurfaceStyle(
    background: Color(0xFF0E2C56),
    ink: Color(0xFFF6F7F8),
    light: false,
  ),
  CardSurfaceStyle(
    background: Color(0xFFE7F0F8),
    ink: Color(0xFF172033),
    light: true,
  ),
];

const List<CardSurfaceStyle> _icici = <CardSurfaceStyle>[
  CardSurfaceStyle(
    background: Color(0xFF8A3A16),
    ink: Color(0xFFF6F7F8),
    light: false,
  ),
  CardSurfaceStyle(
    background: Color(0xFFE7D3C4),
    ink: Color(0xFF3A2418),
    light: true,
  ),
];

const List<CardSurfaceStyle> _sbi = <CardSurfaceStyle>[
  CardSurfaceStyle(
    background: Color(0xFF123F9E),
    ink: Color(0xFFF6F7F8),
    light: false,
  ),
  CardSurfaceStyle(
    background: Color(0xFFD5E4F7),
    ink: Color(0xFF16325C),
    light: true,
  ),
];

const List<CardSurfaceStyle> _axis = <CardSurfaceStyle>[
  CardSurfaceStyle(
    background: Color(0xFF6E2036),
    ink: Color(0xFFF6F7F8),
    light: false,
  ),
  CardSurfaceStyle(
    background: Color(0xFFF3D5DC),
    ink: Color(0xFF4A2030),
    light: true,
  ),
];

const List<CardSurfaceStyle> _kotak = <CardSurfaceStyle>[
  CardSurfaceStyle(
    background: Color(0xFF8E1B2C),
    ink: Color(0xFFF6F7F8),
    light: false,
  ),
  CardSurfaceStyle(
    background: Color(0xFFF6D5DC),
    ink: Color(0xFF4A2030),
    light: true,
  ),
];

const List<CardSurfaceStyle> neutralCardSurfaces = <CardSurfaceStyle>[
  CardSurfaceStyle(
    background: Color(0xFF2C2C2E),
    ink: Color(0xFFF6F7F8),
    light: false,
  ),
  CardSurfaceStyle(
    background: Color(0xFFE4E4E6),
    ink: Color(0xFF1C1C1E),
    light: true,
  ),
  CardSurfaceStyle(
    background: Color(0xFFD7CBBC),
    ink: Color(0xFF2C241C),
    light: true,
  ),
];

const Map<String, List<CardSurfaceStyle>> _bankSurfaces = {
  'pnb': [
    CardSurfaceStyle(
      background: Color(0xFF5E1728),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFF2E0C1),
      ink: Color(0xFF4E2530),
      light: true,
    ),
  ],
  'bob': [
    CardSurfaceStyle(
      background: Color(0xFFC2491D),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFFAE5D3),
      ink: Color(0xFF5A2C1F),
      light: true,
    ),
  ],
  'canara': [
    CardSurfaceStyle(
      background: Color(0xFF0F426D),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE0EFF6),
      ink: Color(0xFF123E5C),
      light: true,
    ),
  ],
  'ubi': [
    CardSurfaceStyle(
      background: Color(0xFF1B3968),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE7EAF2),
      ink: Color(0xFF1E365B),
      light: true,
    ),
  ],
  'idfc': [
    CardSurfaceStyle(
      background: Color(0xFF6A1628),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFF2DDE0),
      ink: Color(0xFF4C1F2B),
      light: true,
    ),
  ],
  'indus': [
    CardSurfaceStyle(
      background: Color(0xFF58392E),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE9DFD4),
      ink: Color(0xFF45302A),
      light: true,
    ),
  ],
  'yes': [
    CardSurfaceStyle(
      background: Color(0xFF173E7A),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE0EBF9),
      ink: Color(0xFF183B6A),
      light: true,
    ),
  ],
  'federal': [
    CardSurfaceStyle(
      background: Color(0xFF123D63),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE0EAF0),
      ink: Color(0xFF173750),
      light: true,
    ),
  ],
  'rbl': [
    CardSurfaceStyle(
      background: Color(0xFF263B81),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE8EBF6),
      ink: Color(0xFF24336A),
      light: true,
    ),
  ],
  'hsbc': [
    CardSurfaceStyle(
      background: Color(0xFF22252B),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE8E8EB),
      ink: Color(0xFF23242B),
      light: true,
    ),
  ],
  'standard': [
    CardSurfaceStyle(
      background: Color(0xFF123F43),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFDFEFEA),
      ink: Color(0xFF193E39),
      light: true,
    ),
  ],
  'citi': [
    CardSurfaceStyle(
      background: Color(0xFF123C7C),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE3EBF9),
      ink: Color(0xFF193B70),
      light: true,
    ),
  ],
  'chase': [
    CardSurfaceStyle(
      background: Color(0xFF102C50),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFDCEAF5),
      ink: Color(0xFF183654),
      light: true,
    ),
  ],
  'boa': [
    CardSurfaceStyle(
      background: Color(0xFF173456),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE4EAF2),
      ink: Color(0xFF203654),
      light: true,
    ),
  ],
  'wells': [
    CardSurfaceStyle(
      background: Color(0xFF751F29),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFF1DFD2),
      ink: Color(0xFF582B26),
      light: true,
    ),
  ],
  'barclays': [
    CardSurfaceStyle(
      background: Color(0xFF0B4059),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFDEF2F5),
      ink: Color(0xFF124451),
      light: true,
    ),
  ],
  'deutsche': [
    CardSurfaceStyle(
      background: Color(0xFF102753),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFE3E9F5),
      ink: Color(0xFF1E3158),
      light: true,
    ),
  ],
  'dbs': [
    CardSurfaceStyle(
      background: Color(0xFF5D1B27),
      ink: Color(0xFFF6F7F8),
      light: false,
    ),
    CardSurfaceStyle(
      background: Color(0xFFF2E2E0),
      ink: Color(0xFF54252B),
      light: true,
    ),
  ],
};

List<CardSurfaceStyle> surfacesForIssuer(String? issuerId) {
  return switch (issuerId) {
    'hdfc' => _hdfc,
    'icici' => _icici,
    'sbi' => _sbi,
    'axis' => _axis,
    'kotak' => _kotak,
    _ => _bankSurfaces[issuerId] ?? neutralCardSurfaces,
  };
}

CardSurfaceStyle cardSurfaceStyle(String? issuerId, int index) {
  final List<CardSurfaceStyle> family = surfacesForIssuer(issuerId);
  final int safe = index < 0 ? 0 : index % family.length;
  return family[safe];
}

/// The issuer and shade to store.
///
/// Resolved once at save, then left alone, so a later table update does not
/// rename or recolor a card.
({String? issuerId, int surfaceIndex, String bankName}) resolveCardFace({
  required String bankName,
  required String number,
  required List<PaymentCard> existing,
  String? exceptId,
}) {
  final String confirmed = bankName.trim();
  final CardIssuer? issuer = issuerForCard(bankName: confirmed, number: number);
  return (
    issuerId: issuer?.id,
    surfaceIndex: assignCardSurface(
      issuerId: issuer?.id,
      existing: existing,
      exceptId: exceptId,
    ),
    bankName: confirmed,
  );
}

/// The next free shade in this card's family.
///
/// The index is stored on the card. Deleting a sibling does not walk the
/// others back to a new color; it only frees the shade for a later card.
int assignCardSurface({
  required String? issuerId,
  required List<PaymentCard> existing,
  String? exceptId,
}) {
  final List<CardSurfaceStyle> family = surfacesForIssuer(issuerId);
  final List<PaymentCard> siblings = existing
      .where(
        (PaymentCard card) => card.id != exceptId && card.issuerId == issuerId,
      )
      .toList(growable: false);
  final Set<int> used = siblings
      .map((PaymentCard card) => card.surfaceIndex)
      .toSet();
  for (var i = 0; i < family.length; i++) {
    if (!used.contains(i)) return i;
  }
  return siblings.length % family.length;
}
