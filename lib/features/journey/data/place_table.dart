import 'dart:convert';

import '../domain/geo_point.dart';
import '../domain/place.dart';
import '../domain/place_resolver.dart';

/// The bundled place table, indexed for lookup.
///
/// Small enough (a few hundred rows) that every index is a plain hash map and
/// the whole thing parses in about a millisecond. It stays JSON rather than
/// following the atlas into a binary format precisely because it is curated by
/// hand: a wrong coordinate here is silent — the pin still lands, just in the
/// wrong place — so the file has to stay readable in a diff.
final class PlaceTable {
  PlaceTable._({
    required this.places,
    required Map<String, Place> byId,
    required Map<String, Place> byCode,
    required Map<String, Place> byName,
    required Map<String, Place> byAlias,
  })  : _byId = byId,
        _byCode = byCode,
        _byName = byName,
        _byAlias = byAlias;

  static final PlaceTable empty = PlaceTable._(
    places: const <Place>[],
    byId: const <String, Place>{},
    byCode: const <String, Place>{},
    byName: const <String, Place>{},
    byAlias: const <String, Place>{},
  );

  final List<Place> places;

  final Map<String, Place> _byId;
  final Map<String, Place> _byCode;
  final Map<String, Place> _byName;
  final Map<String, Place> _byAlias;

  int get length => places.length;

  Place? byId(String id) => _byId[id];

  /// Parses the bundled JSON payload.
  ///
  /// Throws [FormatException] on a malformed row rather than skipping it. A
  /// silently dropped row is a place that stops appearing on the globe with no
  /// signal anywhere, which is exactly the failure mode this feature is built
  /// to avoid — better to fail the load and fall back visibly.
  static PlaceTable decode(String jsonText) {
    final Object? root = json.decode(jsonText);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('Place table root must be an object');
    }
    final Object? rawPlaces = root['places'];
    if (rawPlaces is! List) {
      throw const FormatException('Place table is missing "places"');
    }

    final List<Place> places = <Place>[];
    final Map<String, Place> byId = <String, Place>{};
    final Map<String, Place> byCode = <String, Place>{};
    final Map<String, Place> byName = <String, Place>{};
    final Map<String, Place> byAlias = <String, Place>{};

    for (final Object? raw in rawPlaces) {
      if (raw is! Map) {
        throw const FormatException('Place row must be an object');
      }
      final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
      final Place place = _placeFromRow(row);

      if (byId.containsKey(place.id)) {
        throw FormatException('Duplicate place id: ${place.id}');
      }
      byId[place.id] = place;
      places.add(place);

      for (final String code in _stringList(row['codes'])) {
        final String key = code.toUpperCase();
        // First writer wins, and a collision is a curation bug worth failing on
        // — two places answering to one code means one of them is unreachable.
        if (byCode.containsKey(key)) {
          throw FormatException(
            'Code "$key" claimed by both ${byCode[key]!.id} and ${place.id}',
          );
        }
        byCode[key] = place;
      }

      // Only things a pass can actually name are name-searchable. Countries and
      // regions are reachable by id and code alone: an address ending in
      // "Karnataka" must not resolve a whole state as if it were the venue.
      if (place.kind == PlaceKind.country || place.kind == PlaceKind.region) {
        continue;
      }
      byName.putIfAbsent(normalizePlaceName(place.name), () => place);
      for (final String alias in _stringList(row['a'])) {
        byAlias.putIfAbsent(normalizePlaceName(alias), () => place);
      }
    }

    return PlaceTable._(
      places: places,
      byId: byId,
      byCode: byCode,
      byName: byName,
      byAlias: byAlias,
    );
  }

  /// Exact code, then exact name, then alias. Never anything fuzzier.
  Place? lookup(PlaceQuery query) {
    final String? code = query.code;
    if (code != null) {
      final Place? hit = _byCode[code.toUpperCase()];
      if (hit != null) return hit;
    }
    for (final String candidate in query.textCandidates) {
      final Place? hit = _byName[candidate];
      if (hit != null) return hit;
    }
    for (final String candidate in query.textCandidates) {
      final Place? hit = _byAlias[candidate];
      if (hit != null) return hit;
    }
    return null;
  }

  static Place _placeFromRow(Map<String, dynamic> row) {
    final String? id = row['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Place row is missing "id"');
    }
    final double? lat = _toDouble(row['lat']);
    final double? lng = _toDouble(row['lng']);
    if (lat == null || lng == null) {
      throw FormatException('Place $id is missing coordinates');
    }
    final GeoPoint point = GeoPoint(lat, lng);
    if (!point.isValid) {
      throw FormatException('Place $id has out-of-range coordinates: $point');
    }
    return Place(
      id: id,
      name: row['n']?.toString() ?? id,
      kind: _kindFromToken(row['k']?.toString()),
      point: point,
      cityId: row['city']?.toString(),
      regionCode: row['r']?.toString(),
      countryCode: row['c']?.toString(),
    );
  }

  static PlaceKind _kindFromToken(String? token) => switch (token) {
        'country' => PlaceKind.country,
        'region' => PlaceKind.region,
        'city' => PlaceKind.city,
        'station' => PlaceKind.station,
        'airport' => PlaceKind.airport,
        'venue' => PlaceKind.venue,
        _ => throw FormatException('Unknown place kind: $token'),
      };

  static double? _toDouble(Object? raw) =>
      raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

  static List<String> _stringList(Object? raw) => raw is List
      ? raw.map((Object? e) => e.toString()).where((String s) => s.isNotEmpty).toList()
      : const <String>[];
}

/// The v1 [PlaceResolver]: answers entirely from the bundled table.
///
/// A server-backed resolver would implement the same interface, do its fetching
/// in [ensureReady], and need no change anywhere downstream.
final class BundledPlaceResolver implements PlaceResolver {
  const BundledPlaceResolver(this.table);

  final PlaceTable table;

  @override
  Place? lookup(PlaceQuery query) => query.isEmpty ? null : table.lookup(query);

  @override
  Future<void> ensureReady() async {}
}
