import 'dart:convert';
import 'dart:math';

import 'card_number.dart';

enum CardKind { debit, credit, unset }

/// One side of the scan, stored as an encrypted file. The bytes never enter
/// this record.
class CardScanRef {
  const CardScanRef({
    required this.side,
    required this.fileName,
    required this.sizeBytes,
  });

  final String side;
  final String fileName;
  final int sizeBytes;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'side': side,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
  };

  factory CardScanRef.fromMap(Map<String, dynamic> map) {
    return CardScanRef(
      side: map['side'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

String _newCardId() {
  final Random rand = Random();
  final int ts = DateTime.now().millisecondsSinceEpoch;
  return 'card$ts${rand.nextInt(99999).toString().padLeft(5, '0')}';
}

class PaymentCard {
  PaymentCard({
    String? id,
    this.holderName = '',
    this.number = '',
    this.expiryMonth,
    this.expiryYear,
    this.cvv = '',
    this.kind = CardKind.unset,
    this.bankName = '',
    this.issuerId,
    this.surfaceIndex = 0,
    this.manualNetwork,
    this.scans = const <CardScanRef>[],
  }) : id = id ?? _newCardId();

  final String id;
  final String holderName;

  /// Digits only.
  final String number;
  final int? expiryMonth;
  final int? expiryYear;
  final String cvv;
  final CardKind kind;

  /// The name the person confirmed. Printed as-is. Empty prints "Card".
  final String bankName;

  /// Family id (`hdfc`, `icici`, …) chosen when the card was saved.
  final String? issuerId;
  final int surfaceIndex;

  /// Used only when [matchCardNetwork] returns null. A range hit ignores it.
  final CardNetwork? manualNetwork;
  final List<CardScanRef> scans;

  CardNetwork? get network => effectiveCardNetwork(number, manualNetwork);

  String get lastFour => cardLastFour(number);

  String get displayBank => bankName.trim().isEmpty ? 'Card' : bankName.trim();

  String get expiryLabel {
    if (expiryMonth == null || expiryYear == null) return '';
    return formatCardExpiry(expiryMonth!, expiryYear!);
  }

  bool isExpiredAt(DateTime now) {
    if (expiryMonth == null || expiryYear == null) return false;
    return cardExpiryPassed(expiryMonth!, expiryYear!, now);
  }

  PaymentCard copyWith({
    String? id,
    String? holderName,
    String? number,
    int? expiryMonth,
    int? expiryYear,
    bool clearExpiry = false,
    String? cvv,
    CardKind? kind,
    String? bankName,
    String? issuerId,
    bool clearIssuer = false,
    int? surfaceIndex,
    CardNetwork? manualNetwork,
    bool clearManualNetwork = false,
    List<CardScanRef>? scans,
  }) {
    return PaymentCard(
      id: id ?? this.id,
      holderName: holderName ?? this.holderName,
      number: number ?? this.number,
      expiryMonth: clearExpiry ? null : (expiryMonth ?? this.expiryMonth),
      expiryYear: clearExpiry ? null : (expiryYear ?? this.expiryYear),
      cvv: cvv ?? this.cvv,
      kind: kind ?? this.kind,
      bankName: bankName ?? this.bankName,
      issuerId: clearIssuer ? null : (issuerId ?? this.issuerId),
      surfaceIndex: surfaceIndex ?? this.surfaceIndex,
      manualNetwork: clearManualNetwork
          ? null
          : (manualNetwork ?? this.manualNetwork),
      scans: scans ?? this.scans,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'holderName': holderName,
    'number': number,
    'expiryMonth': expiryMonth,
    'expiryYear': expiryYear,
    'cvv': cvv,
    'kind': kind.name,
    'bankName': bankName,
    'issuerId': issuerId,
    'surfaceIndex': surfaceIndex,
    'manualNetwork': manualNetwork?.name,
    'scans': scans.map((CardScanRef scan) => scan.toMap()).toList(),
  };

  factory PaymentCard.fromMap(Map<String, dynamic> map) {
    final String? id = map['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('Payment card is missing an id');
    }
    final List<CardScanRef> scans = <CardScanRef>[];
    final Object? rawScans = map['scans'];
    if (rawScans is List) {
      for (final Object? item in rawScans) {
        if (item is Map) {
          scans.add(CardScanRef.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return PaymentCard(
      id: id,
      holderName: map['holderName'] as String? ?? '',
      number: cardDigits(map['number'] as String? ?? ''),
      expiryMonth: (map['expiryMonth'] as num?)?.toInt(),
      expiryYear: (map['expiryYear'] as num?)?.toInt(),
      cvv: cardDigits(map['cvv'] as String? ?? ''),
      kind: CardKind.values.firstWhere(
        (CardKind kind) => kind.name == map['kind'],
        orElse: () => CardKind.unset,
      ),
      bankName: map['bankName'] as String? ?? '',
      issuerId: map['issuerId'] as String?,
      surfaceIndex: (map['surfaceIndex'] as num?)?.toInt() ?? 0,
      manualNetwork: CardNetwork.values.cast<CardNetwork?>().firstWhere(
        (CardNetwork? network) => network?.name == map['manualNetwork'],
        orElse: () => null,
      ),
      scans: scans,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PaymentCard.fromJson(String source) =>
      PaymentCard.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
