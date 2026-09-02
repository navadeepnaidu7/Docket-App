import 'place.dart';

/// Builds [PlaceQuery]s out of the display strings passes actually carry.
///
/// Every place value in the wallet was authored to be *read on a card*, not to
/// be looked up: `'Vijayawada Jn (BZA)'` packs a code into a name, and
/// `'Phoenix Marketcity, Whitefield, Bengaluru'` is a venue, a locality and a
/// city in one field. Nothing here invents information — it only separates what
/// is already present, and offers the pieces in most-specific-first order so a
/// table row for a venue wins over the city it sits in when one exists.
///
/// Nothing in this file does fuzzy matching, and nothing should ever be added
/// that does. A near-miss on a place name is silent and unfalsifiable: the pin
/// still lands, just in the wrong country.
abstract final class PlaceQueryParser {
  PlaceQueryParser._();

  /// Trailing `(BZA)` on a station string.
  static final RegExp _trailingCode = RegExp(r'\(\s*([A-Za-z]{2,6})\s*\)\s*$');

  /// A standalone postal code at the end of an address token.
  static final RegExp _trailingPin = RegExp(r'\s*\b\d{6}\b\s*$');

  /// Rail name suffixes that name the station rather than the place.
  ///
  /// Stripping these is what maps `Chennai Central` and `Vijayawada Jn` onto
  /// the cities they serve. `Road` is deliberately absent — it is part of real
  /// place names far more often than it is a station suffix.
  static const List<String> _stationSuffixes = <String>[
    'junction',
    'jn',
    'central',
    'cantonment',
    'cantt',
    'terminus',
    'terminal',
  ];

  /// Address tokens that carry no location.
  static const Set<String> _addressNoise = <String>{'india', 'bharat'};

  /// A query for a train endpoint, from its code and display name.
  ///
  /// The code is the high-confidence signal and the name is the fallback, but
  /// both are offered because fixtures are not consistent: `mock_t1` uses
  /// `BLR`, an airport code, where every other train fixture uses a station
  /// code. The table carries such strays as aliases; the name is what saves the
  /// pass when it does not.
  static PlaceQuery station({String? code, String? name}) {
    return PlaceQuery(
      code: _cleanCode(code),
      textCandidates: _nameCandidates(name),
      expected: PlaceKind.station,
    );
  }

  /// A query for an intermediate halt, e.g. `'Vijayawada Jn (BZA)'`.
  ///
  /// The code lives inside the name here because the model has one string for
  /// both, and the server contract sends one string too. A halt written without
  /// the parenthesised code still resolves by name.
  static PlaceQuery halt(String station) {
    final String raw = station.trim();
    if (raw.isEmpty) return const PlaceQuery(expected: PlaceKind.station);

    final Match? match = _trailingCode.firstMatch(raw);
    final String? code = match == null ? null : _cleanCode(match.group(1));
    final String namePart =
        match == null ? raw : raw.substring(0, match.start).trim();

    return PlaceQuery(
      code: code,
      textCandidates: _nameCandidates(namePart),
      expected: PlaceKind.station,
    );
  }

  /// A query for a cinema, from its name and its address line.
  ///
  /// Candidates run venue, then locality, then city — most specific first — so
  /// a curated venue row pins the exact multiplex while an uncurated one still
  /// falls through to the right city instead of vanishing.
  ///
  /// The city being *last* is the point. Taking the final comma-token as "the
  /// city" happens to work on all eleven current fixtures and will not survive
  /// real extracted addresses, which trail state names and postal codes.
  static PlaceQuery cinema({
    required String cinemaName,
    required String cinemaAddress,
  }) {
    final List<String> candidates = <String>[
      ..._nameCandidates(cinemaName),
      ...addressCandidates(cinemaAddress),
    ];
    return PlaceQuery(
      textCandidates: _dedupe(candidates),
      expected: PlaceKind.venue,
    );
  }

  /// A query for an unstructured location string, e.g. a bus boarding point.
  static PlaceQuery freeText(String raw, {PlaceKind? expected}) {
    final List<String> candidates = <String>[
      ..._nameCandidates(raw),
      ...addressCandidates(raw),
    ];
    return PlaceQuery(
      textCandidates: _dedupe(candidates),
      expected: expected,
    );
  }

  /// Splits an address line into normalised candidates, specific to general.
  ///
  /// Visible for testing — the heuristics here are the ones most likely to
  /// break on real extracted data, so they are asserted directly rather than
  /// only through [cinema].
  static List<String> addressCandidates(String address) {
    final List<String> out = <String>[];
    for (final String part in address.split(',')) {
      final String cleaned = normalizePlaceName(
        part.replaceAll(_trailingPin, ' '),
      );
      if (cleaned.isEmpty) continue;
      if (_addressNoise.contains(cleaned)) continue;
      // A token that was nothing but a postal code is now empty of letters.
      if (!cleaned.contains(RegExp(r'[a-z]'))) continue;
      out.add(cleaned);
    }
    return _dedupe(out);
  }

  /// Strips a rail suffix from an already-normalised name.
  ///
  /// Returns the input unchanged when there is no suffix, and never returns an
  /// empty string — a station literally named `Junction` keeps its name rather
  /// than becoming unlookupable.
  static String stripStationSuffix(String normalized) {
    for (final String suffix in _stationSuffixes) {
      if (normalized == suffix) return normalized;
      if (normalized.endsWith(' $suffix')) {
        final String stripped =
            normalized.substring(0, normalized.length - suffix.length - 1).trim();
        return stripped.isEmpty ? normalized : stripped;
      }
    }
    return normalized;
  }

  static String? _cleanCode(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    // Codes are letters only. Anything else is a name that reached the wrong
    // field, and matching it as a code would be a false positive.
    if (!RegExp(r'^[A-Z]{2,6}$').hasMatch(trimmed)) return null;
    return trimmed;
  }

  /// Normalised name plus its suffix-stripped form, in that order.
  static List<String> _nameCandidates(String? name) {
    if (name == null) return const <String>[];
    final String normalized = normalizePlaceName(name);
    if (normalized.isEmpty) return const <String>[];
    final String stripped = stripStationSuffix(normalized);
    return stripped == normalized
        ? <String>[normalized]
        : <String>[normalized, stripped];
  }

  static List<String> _dedupe(List<String> input) {
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final String value in input) {
      if (value.isEmpty) continue;
      if (seen.add(value)) out.add(value);
    }
    return out;
  }
}
