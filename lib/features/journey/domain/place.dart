import 'geo_point.dart';

/// What kind of thing a place is.
///
/// This is the granularity of the *record*, not of the level it is drawn at.
/// A cinema is a venue even though it is only ever seen at city level.
enum PlaceKind {
  country,
  region,
  city,
  station,
  airport,
  venue,
}

/// A resolved location: a stable id, a name to show, and a point to draw at.
///
/// [cityId], [regionCode] and [countryCode] are what make clustering a hash-map
/// grouping instead of a spatial algorithm — the table carries the hierarchy,
/// so every level's cluster key is already a field on the row.
final class Place {
  const Place({
    required this.id,
    required this.name,
    required this.kind,
    required this.point,
    this.cityId,
    this.regionCode,
    this.countryCode,
  });

  /// Namespaced and stable, e.g. `stn:BZA`, `city:bengaluru`, `country:IN`.
  final String id;

  final String name;
  final PlaceKind kind;
  final GeoPoint point;

  /// The [Place.id] of the city this sits in. Null on a city or above.
  final String? cityId;

  /// ISO 3166-2 subdivision, e.g. `IN-KA`.
  final String? regionCode;

  /// ISO 3166-1 alpha-2, e.g. `IN`.
  final String? countryCode;

  /// The city-level identity used for grouping.
  ///
  /// A city row is its own city; a station or venue points at one. Nothing
  /// downstream has to know which kind it started from.
  String? get cityKey => kind == PlaceKind.city ? id : cityId;

  @override
  String toString() => 'Place($id, $name)';
}

/// A lookup request built from whatever text a pass happened to carry.
///
/// Deliberately carries several ways of asking. The wallet's place strings were
/// authored for card faces, not for lookup, so a single canonical form cannot be
/// derived reliably — but a short ordered list of candidates resolves nearly all
/// of them against a small table.
final class PlaceQuery {
  const PlaceQuery({
    this.code,
    this.textCandidates = const <String>[],
    this.expected,
  });

  /// A station or airport code, uppercased. Highest-confidence signal there is.
  final String? code;

  /// Normalised name candidates, most specific first.
  final List<String> textCandidates;

  /// What kind of place the caller expects, used only to break ties.
  final PlaceKind? expected;

  /// True when there is nothing to look up — the pass carried no usable text.
  bool get isEmpty => code == null && textCandidates.isEmpty;

  /// The most human form of this query, for the "could not place" list.
  String get label {
    if (textCandidates.isNotEmpty) return textCandidates.first;
    return code ?? '';
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceQuery &&
      other.code == code &&
      other.expected == expected &&
      _sameList(other.textCandidates, textCandidates);

  @override
  int get hashCode => Object.hash(code, expected, Object.hashAll(textCandidates));

  @override
  String toString() =>
      'PlaceQuery(code: $code, text: $textCandidates, expected: $expected)';

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final RegExp _nonAlphanumeric = RegExp(r'[^a-z0-9]+');

/// Folds a place name to the form both the table index and lookups are keyed by.
///
/// Lowercases, strips punctuation and collapses whitespace, so `KSR Bengaluru`,
/// `ksr  bengaluru` and `K.S.R. Bengaluru` are one key. Nothing fuzzier than
/// that: near-miss matching is how a movie in Bengaluru ends up in Bangladesh.
String normalizePlaceName(String raw) =>
    raw.toLowerCase().replaceAll(_nonAlphanumeric, ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
