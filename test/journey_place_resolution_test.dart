import 'dart:io';

import 'package:docket/features/journey/data/place_table.dart';
import 'package:docket/features/journey/domain/journey_event.dart';
import 'package:docket/features/journey/domain/journey_index.dart';
import 'package:docket/features/journey/domain/place.dart';
import 'package:docket/features/journey/domain/place_query_parser.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage of the bundled place table against the fixtures the app ships.
///
/// This is the highest-leverage test in Journey. The place table is curated by
/// hand, and a gap in it is invisible at runtime: the globe just looks emptier,
/// which is indistinguishable from a user who travelled less. Asserting that
/// every place string in `mock_pass_fixtures.dart` resolves turns a curation
/// gap into a red test.
void main() {
  // Read the asset off disk rather than through rootBundle so this stays a
  // plain unit test with no binding, no async, and no pumping.
  final PlaceTable table =
      PlaceTable.decode(File('assets/journey/places_v1.json').readAsStringSync());
  final BundledPlaceResolver resolver = BundledPlaceResolver(table);

  final List<WalletPassItem> fixtures = buildWalletPassCatalog(
    trains: mockTrainPasses,
    movies: mockMoviePasses,
  );

  group('bundled place table', () {
    test('parses and indexes every row', () {
      expect(table.length, greaterThan(20));
      expect(table.byId('city:bengaluru'), isNotNull);
      expect(table.byId('stn:SBC')!.cityKey, 'city:bengaluru');
    });

    test('every row sits inside the bounding box of its country', () {
      // Coarse on purpose. It cannot catch a station placed in the wrong
      // district, but it catches the transposed or sign-flipped coordinate,
      // which is the mistake that actually happens.
      const double minLat = 6.0;
      const double maxLat = 37.5;
      const double minLng = 68.0;
      const double maxLng = 97.5;
      for (final Place place in table.places) {
        if (place.countryCode != 'IN') continue;
        expect(
          place.point.lat,
          inInclusiveRange(minLat, maxLat),
          reason: '${place.id} latitude is outside India',
        );
        expect(
          place.point.lng,
          inInclusiveRange(minLng, maxLng),
          reason: '${place.id} longitude is outside India',
        );
      }
    });

    test('a station resolves to a city that exists', () {
      for (final Place place in table.places) {
        final String? cityId = place.cityId;
        if (cityId == null) continue;
        expect(
          table.byId(cityId),
          isNotNull,
          reason: '${place.id} points at missing city $cityId',
        );
      }
    });

    test('country and region rows are not name-searchable', () {
      // An address ending in "Karnataka" must not resolve a whole state as if
      // it were the venue.
      expect(
        table.lookup(const PlaceQuery(textCandidates: <String>['karnataka'])),
        isNull,
      );
      expect(
        table.lookup(const PlaceQuery(textCandidates: <String>['india'])),
        isNull,
      );
    });
  });

  group('fixture coverage', () {
    test('every shipped fixture pass is plottable', () {
      final JourneyIndex index =
          buildJourneyIndex(passes: fixtures, resolver: resolver);

      expect(
        index.unplaced,
        isEmpty,
        reason: 'unplaced: ${index.unplaced.map((JourneyEvent e) => e.id).toList()}',
      );
      expect(index.placed.length, fixtures.length);
    });

    test('no place string in any fixture goes unresolved', () {
      final JourneyIndex index =
          buildJourneyIndex(passes: fixtures, resolver: resolver);

      expect(
        index.report.missed,
        isEmpty,
        reason: 'the table has no row for: ${index.report.missed}',
      );
      expect(index.report.resolutionRate, 1.0);
    });

    test('every train fixture draws as a route, not a point', () {
      final JourneyIndex index =
          buildJourneyIndex(passes: fixtures, resolver: resolver);
      final Iterable<JourneyEvent> trains =
          index.placed.where((JourneyEvent e) => e.kind == JourneyEventKind.train);

      expect(trains, isNotEmpty);
      for (final JourneyEvent train in trains) {
        expect(train.isRoute, isTrue, reason: '${train.id} collapsed to a point');
      }
    });

    test('every movie fixture is a single point', () {
      final JourneyIndex index =
          buildJourneyIndex(passes: fixtures, resolver: resolver);
      final Iterable<JourneyEvent> movies =
          index.placed.where((JourneyEvent e) => e.kind == JourneyEventKind.movie);

      expect(movies, isNotEmpty);
      for (final JourneyEvent movie in movies) {
        expect(movie.isRoute, isFalse);
        expect(movie.placedStops.length, 1);
      }
    });

    test('mock_t1 resolves despite using an airport code as a station', () {
      // BLR is Kempegowda airport's IATA code, and the fixture uses it as a
      // train endpoint. The table carries it as a code on the Bengaluru city
      // row; without that this pass would silently lose half its route.
      final JourneyIndex index =
          buildJourneyIndex(passes: fixtures, resolver: resolver);
      final JourneyEvent t1 =
          index.events.firstWhere((JourneyEvent e) => e.id == 'train:mock_t1');

      expect(t1.placedStops.last.place!.cityKey, 'city:bengaluru');
    });

    test("the 'Hyderabad Decan' typo still resolves", () {
      final Place? hit = table.lookup(PlaceQueryParser.halt('Hyderabad Decan (HYB)'));
      expect(hit, isNotNull);
      expect(hit!.cityKey, 'city:hyderabad');
    });
  });

  group('query parsing', () {
    test('a halt string yields both its code and its name', () {
      final PlaceQuery query = PlaceQueryParser.halt('Vijayawada Jn (BZA)');
      expect(query.code, 'BZA');
      expect(query.textCandidates, containsAll(<String>['vijayawada jn', 'vijayawada']));
    });

    test('a halt without a code still yields a name', () {
      final PlaceQuery query = PlaceQueryParser.halt('New Delhi');
      expect(query.code, isNull);
      expect(query.textCandidates, contains('new delhi'));
    });

    test('a rail suffix is stripped to reach the city', () {
      expect(PlaceQueryParser.stripStationSuffix('chennai central'), 'chennai');
      expect(PlaceQueryParser.stripStationSuffix('kazipet jn'), 'kazipet');
      expect(PlaceQueryParser.stripStationSuffix('guntakal junction'), 'guntakal');
    });

    test('a name that is only a suffix keeps its name', () {
      // Stripping to empty would make the place unlookupable, which is worse
      // than leaving it alone.
      expect(PlaceQueryParser.stripStationSuffix('junction'), 'junction');
    });

    test('"Road" is never treated as a station suffix', () {
      // It is part of real place names far more often than it is a suffix.
      expect(PlaceQueryParser.stripStationSuffix('magrath road'), 'magrath road');
    });

    test('an address yields candidates from specific to general', () {
      expect(
        PlaceQueryParser.addressCandidates(
          'Phoenix Marketcity, Whitefield, Bengaluru',
        ),
        <String>['phoenix marketcity', 'whitefield', 'bengaluru'],
      );
    });

    test('an address drops country noise and postal codes', () {
      expect(
        PlaceQueryParser.addressCandidates(
          'Orion Mall, Rajajinagar, Bengaluru 560055, India',
        ),
        <String>['orion mall', 'rajajinagar', 'bengaluru'],
      );
    });

    test('a cinema offers its venue before its city', () {
      final PlaceQuery query = PlaceQueryParser.cinema(
        cinemaName: 'PVR INOX Phoenix Mall',
        cinemaAddress: 'Phoenix Marketcity, Whitefield, Bengaluru',
      );
      expect(query.textCandidates.first, 'pvr inox phoenix mall');
      expect(query.textCandidates.last, 'bengaluru');
    });

    test('a non-alphabetic code is rejected rather than matched', () {
      // A name that reached the code field must not become a false positive.
      expect(PlaceQueryParser.station(code: '12345', name: 'Somewhere').code, isNull);
      expect(PlaceQueryParser.station(code: '', name: 'Somewhere').code, isNull);
    });

    test('an empty query is recognised as having nothing to ask', () {
      expect(PlaceQueryParser.halt('   ').isEmpty, isTrue);
      expect(PlaceQueryParser.cinema(cinemaName: '', cinemaAddress: '').isEmpty, isTrue);
    });
  });
}
