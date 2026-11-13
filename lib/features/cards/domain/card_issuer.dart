import 'card_number.dart';

/// A bank the offline table knows by name.
///
/// The id is stored on the card. A later table update must not rename a card
/// the person already confirmed, and it must not recolor one either: the face
/// reads [id] and the stored surface index, not a fresh lookup.
class CardIssuer {
  const CardIssuer({required this.id, required this.name});

  final String id;
  final String name;

  String get logoAsset => 'assets/wallet/banks/$id.svg';
}

const CardIssuer hdfcIssuer = CardIssuer(id: 'hdfc', name: 'HDFC Bank');
const CardIssuer iciciIssuer = CardIssuer(id: 'icici', name: 'ICICI Bank');
const CardIssuer sbiIssuer = CardIssuer(id: 'sbi', name: 'State Bank of India');
const CardIssuer axisIssuer = CardIssuer(id: 'axis', name: 'Axis Bank');
const CardIssuer kotakIssuer = CardIssuer(id: 'kotak', name: 'Kotak');

const CardIssuer pnbIssuer = CardIssuer(
  id: 'pnb',
  name: 'Punjab National Bank',
);
const CardIssuer bobIssuer = CardIssuer(id: 'bob', name: 'Bank of Baroda');
const CardIssuer canaraIssuer = CardIssuer(id: 'canara', name: 'Canara Bank');
const CardIssuer ubiIssuer = CardIssuer(id: 'ubi', name: 'Union Bank of India');
const CardIssuer idfcIssuer = CardIssuer(id: 'idfc', name: 'IDFC FIRST Bank');
const CardIssuer indusIssuer = CardIssuer(id: 'indus', name: 'IndusInd Bank');
const CardIssuer yesIssuer = CardIssuer(id: 'yes', name: 'YES Bank');
const CardIssuer federalIssuer = CardIssuer(
  id: 'federal',
  name: 'Federal Bank',
);
const CardIssuer rblIssuer = CardIssuer(id: 'rbl', name: 'RBL Bank');
const CardIssuer hsbcIssuer = CardIssuer(id: 'hsbc', name: 'HSBC');
const CardIssuer standardIssuer = CardIssuer(
  id: 'standard',
  name: 'Standard Chartered',
);
const CardIssuer citiIssuer = CardIssuer(id: 'citi', name: 'Citibank');
const CardIssuer chaseIssuer = CardIssuer(id: 'chase', name: 'Chase');
const CardIssuer boaIssuer = CardIssuer(id: 'boa', name: 'Bank of America');
const CardIssuer wellsIssuer = CardIssuer(id: 'wells', name: 'Wells Fargo');
const CardIssuer barclaysIssuer = CardIssuer(id: 'barclays', name: 'Barclays');
const CardIssuer deutscheIssuer = CardIssuer(
  id: 'deutsche',
  name: 'Deutsche Bank',
);
const CardIssuer dbsIssuer = CardIssuer(id: 'dbs', name: 'DBS Bank');

const List<CardIssuer> cardIssuers = <CardIssuer>[
  hdfcIssuer,
  iciciIssuer,
  sbiIssuer,
  axisIssuer,
  kotakIssuer,
  pnbIssuer,
  bobIssuer,
  canaraIssuer,
  ubiIssuer,
  idfcIssuer,
  indusIssuer,
  yesIssuer,
  federalIssuer,
  rblIssuer,
  hsbcIssuer,
  standardIssuer,
  citiIssuer,
  chaseIssuer,
  boaIssuer,
  wellsIssuer,
  barclaysIssuer,
  deutscheIssuer,
  dbsIssuer,
];

/// Six-digit prefixes checked against public BIN lists before they were added.
///
/// A miss stays blank. The review step asks the person for the name rather
/// than printing a bank this table is not sure about. Longest prefix wins,
/// so an 8-digit entry can override a 6-digit one later without a rewrite.
const Map<String, CardIssuer> _prefixes = <String, CardIssuer>{
  // HDFC Bank, binlist.io/bank/hdfc-bank-in
  '508506': hdfcIssuer,
  '508562': hdfcIssuer,
  '508572': hdfcIssuer,
  '508573': hdfcIssuer,
  '508584': hdfcIssuer,
  '508589': hdfcIssuer,
  '508607': hdfcIssuer,
  '508608': hdfcIssuer,
  '508610': hdfcIssuer,
  '508614': hdfcIssuer,
  '508619': hdfcIssuer,
  '508622': hdfcIssuer,
  '508625': hdfcIssuer,
  '508627': hdfcIssuer,
  '508635': hdfcIssuer,
  '508636': hdfcIssuer,
  '508642': hdfcIssuer,
  '508691': hdfcIssuer,
  '508729': hdfcIssuer,
  '508733': hdfcIssuer,
  '508739': hdfcIssuer,
  '508972': hdfcIssuer,
  '508973': hdfcIssuer,
  '606997': hdfcIssuer,
  '607039': hdfcIssuer,
  '607081': hdfcIssuer,
  '607109': hdfcIssuer,
  // ICICI Bank, binlist.io/bank/icici-bank-ltd-in and icici-bank-in
  '400782': iciciIssuer,
  '400843': iciciIssuer,
  '401704': iciciIssuer,
  '401711': iciciIssuer,
  '401767': iciciIssuer,
  '401772': iciciIssuer,
  '401780': iciciIssuer,
  '401784': iciciIssuer,
  '401796': iciciIssuer,
  '401798': iciciIssuer,
  '401806': iciciIssuer,
  '401920': iciciIssuer,
  '402565': iciciIssuer,
  '402853': iciciIssuer,
  '403562': iciciIssuer,
  '404464': iciciIssuer,
  '404465': iciciIssuer,
  '405533': iciciIssuer,
  '405994': iciciIssuer,
  '406324': iciciIssuer,
  '477658': iciciIssuer,
  '508522': iciciIssuer,
  '508534': iciciIssuer,
  '508544': iciciIssuer,
  '508554': iciciIssuer,
  '508563': iciciIssuer,
  '508564': iciciIssuer,
  '508566': iciciIssuer,
  '508567': iciciIssuer,
  '508579': iciciIssuer,
  '508587': iciciIssuer,
  '508592': iciciIssuer,
  '508596': iciciIssuer,
  '508600': iciciIssuer,
  '508611': iciciIssuer,
  '508621': iciciIssuer,
  '508639': iciciIssuer,
  '508683': iciciIssuer,
  '508728': iciciIssuer,
  '508730': iciciIssuer,
  '508740': iciciIssuer,
  '508741': iciciIssuer,
  '508742': iciciIssuer,
  '508762': iciciIssuer,
  '508787': iciciIssuer,
  '508794': iciciIssuer,
  '508812': iciciIssuer,
  '508821': iciciIssuer,
  '508825': iciciIssuer,
  '508869': iciciIssuer,
};

CardIssuer? lookupCardIssuer(String raw) {
  final String digits = cardDigits(raw);
  CardIssuer? found;
  var foundLength = 0;
  for (final MapEntry<String, CardIssuer> entry in _prefixes.entries) {
    if (entry.key.length <= foundLength) continue;
    if (digits.startsWith(entry.key)) {
      found = entry.value;
      foundLength = entry.key.length;
    }
  }
  return found;
}

/// Explicit names and aliases only; similar bank names must not collide.
CardIssuer? issuerFromName(String name) {
  final String folded = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (folded.isEmpty) return null;
  return _issuerNames[folded];
}

final Map<String, CardIssuer> _issuerNames = <String, CardIssuer>{
  for (final CardIssuer issuer in cardIssuers)
    issuer.name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''): issuer,
  'hdfc': hdfcIssuer,
  'hdfcbanklimited': hdfcIssuer,
  'icici': iciciIssuer,
  'sbi': sbiIssuer,
  'sbicard': sbiIssuer,
  'sbicards': sbiIssuer,
  'axis': axisIssuer,
  'kotakmahindra': kotakIssuer,
  'kotakmahindrabank': kotakIssuer,
  'pnb': pnbIssuer,
  'bob': bobIssuer,
  'canara': canaraIssuer,
  'unionbank': ubiIssuer,
  'idfc': idfcIssuer,
  'idfcfirst': idfcIssuer,
  'indusind': indusIssuer,
  'yes': yesIssuer,
  'federal': federalIssuer,
  'rbl': rblIssuer,
  'ratnakarbank': rblIssuer,
  'hsbcbank': hsbcIssuer,
  'hsbcbankindia': hsbcIssuer,
  'standardcharteredbank': standardIssuer,
  'citi': citiIssuer,
  'citibank': citiIssuer,
  'chasebank': chaseIssuer,
  'jpmorganchase': chaseIssuer,
  'bofa': boaIssuer,
  'wellsfargobank': wellsIssuer,
  'barclaysbank': barclaysIssuer,
  'deutsche': deutscheIssuer,
  'dbs': dbsIssuer,
};

/// Color follows the confirmed name when that name is a known bank, and the
/// number otherwise. Unknown banks share the neutral surfaces.
CardIssuer? issuerForCard({required String bankName, required String number}) {
  // A confirmed name overrides a prefix hint, including an unknown bank.
  return bankName.trim().isNotEmpty
      ? issuerFromName(bankName)
      : lookupCardIssuer(number);
}
