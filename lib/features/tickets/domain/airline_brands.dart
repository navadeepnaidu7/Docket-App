/// The airlines a flight pass knows by sight: IATA designator, display name,
/// the colour the pass is printed in, and whether that colour needs dark ink.
///
/// Only colours live in the app. Logos are served by the backend at
/// `/img/airline/{code}.svg` and cached on the device (see
/// `presentation/flight/airline_logo.dart`), so adding an airline costs one
/// line here plus one SVG on the server, and nothing in the app download.
/// An airline that is not listed still gets a pass, on the neutral surface.
class AirlineBrand {
  const AirlineBrand(
    this.code,
    this.name,
    this.surface, {
    this.darkInk = false,
    this.logoScale = 1,
  });

  /// IATA designator, upper case.
  final String code;
  final String name;

  /// ARGB pass surface, taken from the airline's livery or logo.
  final int surface;

  /// True when the surface is light enough that white type would not read
  /// (Vueling yellow, Scoot yellow, Jetstar orange).
  final bool darkInk;

  /// Multiplier on the logo's fitted size, for marks whose drawing sits small
  /// or large inside its own box.
  final double logoScale;

  static AirlineBrand? of(String code) => _byCode[code.trim().toUpperCase()];
}

final Map<String, AirlineBrand> _byCode = <String, AirlineBrand>{
  for (final AirlineBrand b in airlineBrands) b.code: b,
};

/// Ordered by region, then roughly by how often Docket's users fly them.
const List<AirlineBrand> airlineBrands = <AirlineBrand>[
  // India and South Asia
  AirlineBrand('6E', 'IndiGo', 0xFF001B94),
  AirlineBrand('AI', 'Air India', 0xFF6E1B3C),
  AirlineBrand('IX', 'Air India Express', 0xFFB4441C),
  AirlineBrand('QP', 'Akasa Air', 0xFFC2541E),
  AirlineBrand('SG', 'SpiceJet', 0xFFA51722),
  AirlineBrand('UL', 'SriLankan Airlines', 0xFF0B4F7C),
  AirlineBrand('BG', 'Biman Bangladesh', 0xFF006B3A),
  AirlineBrand('PK', 'PIA', 0xFF00643A),
  // Middle East and Turkey
  AirlineBrand('EK', 'Emirates', 0xFFC8102E, logoScale: 1.3),
  AirlineBrand('QR', 'Qatar Airways', 0xFF5C0632),
  AirlineBrand('EY', 'Etihad', 0xFF6E5320),
  AirlineBrand('FZ', 'flydubai', 0xFF00578A),
  AirlineBrand('G9', 'Air Arabia', 0xFFC4103A),
  AirlineBrand('WY', 'Oman Air', 0xFF0E4D5A),
  AirlineBrand('GF', 'Gulf Air', 0xFF1E2947),
  AirlineBrand('SV', 'Saudia', 0xFF016631),
  AirlineBrand('XY', 'flynas', 0xFF00807B),
  AirlineBrand('KU', 'Kuwait Airways', 0xFF20285C),
  AirlineBrand('RJ', 'Royal Jordanian', 0xFF2F3338),
  AirlineBrand('MS', 'EgyptAir', 0xFF00265D),
  AirlineBrand('LY', 'El Al', 0xFF1B358F),
  AirlineBrand('TK', 'Turkish Airlines', 0xFFC70A0C),
  AirlineBrand('PC', 'Pegasus', 0xFFFDC300, darkInk: true),
  // Europe
  AirlineBrand('BA', 'British Airways', 0xFF13306B),
  AirlineBrand('VS', 'Virgin Atlantic', 0xFF5B056A),
  AirlineBrand('LH', 'Lufthansa', 0xFF05164D),
  AirlineBrand('LX', 'Swiss', 0xFFD8070F),
  AirlineBrand('OS', 'Austrian', 0xFFC8200A),
  AirlineBrand('SN', 'Brussels Airlines', 0xFF051446),
  AirlineBrand('AF', 'Air France', 0xFF051039),
  AirlineBrand('KL', 'KLM', 0xFF0085CA),
  AirlineBrand('IB', 'Iberia', 0xFFC4162A),
  AirlineBrand('VY', 'Vueling', 0xFFFFCC00, darkInk: true),
  AirlineBrand('AZ', 'ITA Airways', 0xFF1A3A8A),
  AirlineBrand('SK', 'SAS', 0xFF0A1A8C),
  AirlineBrand('AY', 'Finnair', 0xFF0B1560),
  AirlineBrand('EI', 'Aer Lingus', 0xFF006472),
  AirlineBrand('TP', 'TAP Air Portugal', 0xFFC8102E),
  AirlineBrand('LO', 'LOT', 0xFF252668),
  AirlineBrand('A3', 'Aegean', 0xFF00217A),
  AirlineBrand('FR', 'Ryanair', 0xFF073590),
  AirlineBrand(
    'U2',
    'easyJet',
    0xFFF25C00,
  ), // a shade under the brand orange, so white reads
  AirlineBrand('W6', 'Wizz Air', 0xFF4F1E90),
  AirlineBrand('DY', 'Norwegian', 0xFFC8102E),
  AirlineBrand('EW', 'Eurowings', 0xFF871C54),
  // Americas
  AirlineBrand('AA', 'American Airlines', 0xFF0B4F8A),
  AirlineBrand('DL', 'Delta', 0xFF003D79),
  AirlineBrand('UA', 'United', 0xFF002F87),
  AirlineBrand('WN', 'Southwest', 0xFF304CB2),
  AirlineBrand('B6', 'JetBlue', 0xFF003876),
  AirlineBrand('AS', 'Alaska Airlines', 0xFF00385F),
  AirlineBrand('AC', 'Air Canada', 0xFFD6001C),
  AirlineBrand('WS', 'WestJet', 0xFF00467F),
  AirlineBrand('AM', 'Aeromexico', 0xFF040C3E),
  AirlineBrand('LA', 'LATAM', 0xFF2A0088),
  AirlineBrand('AV', 'Avianca', 0xFFD9001D),
  AirlineBrand('CM', 'Copa Airlines', 0xFF0060A9),
  // East and Southeast Asia, Oceania
  AirlineBrand('SQ', 'Singapore Airlines', 0xFF00266B),
  AirlineBrand('TR', 'Scoot', 0xFFFFE900, darkInk: true),
  AirlineBrand('CX', 'Cathay Pacific', 0xFF005D63),
  AirlineBrand('NH', 'ANA', 0xFF223F9A),
  AirlineBrand('JL', 'Japan Airlines', 0xFFCC0000),
  AirlineBrand('KE', 'Korean Air', 0xFF051766),
  AirlineBrand('OZ', 'Asiana', 0xFF4A4F55),
  AirlineBrand('CI', 'China Airlines', 0xFF1A2A5E),
  AirlineBrand('BR', 'EVA Air', 0xFF007A3D),
  AirlineBrand('CA', 'Air China', 0xFFC8102E),
  AirlineBrand('MU', 'China Eastern', 0xFF1B1D80),
  AirlineBrand('CZ', 'China Southern', 0xFF0B5CA8),
  AirlineBrand('TG', 'Thai Airways', 0xFF370E62),
  AirlineBrand('MH', 'Malaysia Airlines', 0xFF0D4689),
  AirlineBrand('AK', 'AirAsia', 0xFFE1001A),
  AirlineBrand('GA', 'Garuda Indonesia', 0xFF0E5A6E),
  AirlineBrand('PR', 'Philippine Airlines', 0xFF2F3B8D),
  AirlineBrand('5J', 'Cebu Pacific', 0xFF1F64A8),
  AirlineBrand('VN', 'Vietnam Airlines', 0xFF005E80),
  AirlineBrand('VJ', 'VietJet', 0xFFD7141C),
  AirlineBrand('QF', 'Qantas', 0xFFE40000),
  AirlineBrand('JQ', 'Jetstar', 0xFFFE5815, darkInk: true),
  AirlineBrand('VA', 'Virgin Australia', 0xFFC8102E),
  AirlineBrand('NZ', 'Air New Zealand', 0xFF1A1A1A, logoScale: 1.15),
  // Africa
  AirlineBrand('ET', 'Ethiopian', 0xFF0B6B3A, logoScale: 1.2),
  AirlineBrand('KQ', 'Kenya Airways', 0xFFC8102E),
  AirlineBrand('SA', 'South African Airways', 0xFF163683, logoScale: 1.2),
  AirlineBrand('AT', 'Royal Air Maroc', 0xFFC20831, logoScale: 1.25),
];
