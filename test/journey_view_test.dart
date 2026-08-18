import 'dart:io';
import 'dart:typed_data';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/journey/application/journey_providers.dart';
import 'package:docket/features/journey/data/journey_atlas.dart';
import 'package:docket/features/journey/data/mock_flight_fixtures.dart';
import 'package:docket/features/journey/data/place_table.dart';
import 'package:docket/features/journey/domain/journey_cluster.dart';
import 'package:docket/features/journey/domain/journey_index.dart';
import 'package:docket/features/journey/domain/journey_level.dart';
import 'package:docket/features/journey/domain/pin_declutter.dart';
import 'package:docket/features/journey/presentation/journey_view.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final PlaceTable table =
      PlaceTable.decode(File('assets/journey/places_v1.json').readAsStringSync());
  final Uint8List atlasBytes =
      File('assets/journey/atlas_v1.bin').readAsBytesSync();
  final JourneyAtlas atlas = decodeJourneyAtlas(atlasBytes);

  final JourneyIndex index = buildJourneyIndex(
    passes: buildWalletPassCatalog(
      trains: mockTrainPasses,
      movies: mockMoviePasses,
    ),
    flights: mockFlightItineraries,
    resolver: BundledPlaceResolver(table),
  );

  Future<void> pumpJourney(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // The real providers reach for SharedPreferences and the pass
          // repository; the globe only cares about the resolved index, so
          // inject it and keep this a rendering test.
          journeyEventsProvider.overrideWithValue(index),
          journeyAtlasProvider.overrideWith((Ref ref) async => atlas),
          placeTableProvider.overrideWith((Ref ref) async => table),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: const Scaffold(body: JourneyView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  group('rendering', () {
    testWidgets('draws without throwing in dark and light', (tester) async {
      await pumpJourney(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(JourneyView), findsOneWidget);

      await pumpJourney(tester, brightness: Brightness.light);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens at world level with a summary of what is placed',
        (tester) async {
      await pumpJourney(tester);
      expect(find.text('Journey'), findsOneWidget);
      // The fixtures resolve to India plus the mock flight destinations.
      expect(find.textContaining('countries'), findsOneWidget);
    });

    testWidgets('shows no back affordance at world level', (tester) async {
      await pumpJourney(tester);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('tapping a cluster descends a level and flies the camera',
        (tester) async {
      await pumpJourney(tester);

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(JourneyView)),
      );
      expect(container.read(journeyNavigatorProvider).level, JourneyLevel.world);

      // Markers are wherever the projection and the declutter pass put them,
      // so sweep rather than hard-coding a pixel that would break the moment
      // any framing constant is tuned.
      bool descended = false;
      for (double y = 240; y <= 660 && !descended; y += 20) {
        for (double x = 60; x <= 330 && !descended; x += 20) {
          await tester.tapAt(Offset(x, y));
          await tester.pump(const Duration(milliseconds: 50));
          descended = container.read(journeyNavigatorProvider).level !=
              JourneyLevel.world;
        }
      }

      expect(descended, isTrue, reason: 'no tap anywhere hit a cluster');
      final JourneyNavState nav = container.read(journeyNavigatorProvider);
      expect(nav.level, JourneyLevel.country);
      expect(nav.canGoBack, isTrue);
      expect(nav.camera.distance, lessThan(3.2), reason: 'camera did not descend');

      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // And back out again.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(container.read(journeyNavigatorProvider).level, JourneyLevel.world);
    });

    testWidgets('survives a drag without throwing', (tester) async {
      await pumpJourney(tester);
      await tester.drag(find.byType(JourneyView), const Offset(-60, 20));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('the index behind the globe', () {
    test('every fixture and mock flight is placed', () {
      expect(index.unplaced, isEmpty);
      expect(index.report.missed, isEmpty);
      expect(index.placed.length, greaterThan(15));
    });

    test('the world level groups into more than one country', () {
      // Without the mock flights this would be a globe with one country lit,
      // which is the reason they exist.
      final ClusterSet world = clusterFor(index, JourneyScope.world);
      expect(world.clusters.length, greaterThan(1));
      expect(
        world.clusters.map((JourneyCluster c) => c.key),
        contains('IN'),
      );
    });

    test('descending into India yields several states', () {
      final ClusterSet country =
          clusterFor(index, const JourneyScope(JourneyLevel.country, 'IN'));
      expect(country.clusters.length, greaterThan(3));
      expect(
        country.clusters.map((JourneyCluster c) => c.key),
        contains('IN-KA'),
      );
    });

    test('descending into Karnataka reaches Bengaluru', () {
      final ClusterSet region =
          clusterFor(index, const JourneyScope(JourneyLevel.region, 'IN-KA'));
      expect(
        region.clusters.map((JourneyCluster c) => c.key),
        contains('city:bengaluru'),
      );
    });

    test('the city floor turns clusters into individual memories', () {
      final ClusterSet city = clusterFor(
        index,
        const JourneyScope(JourneyLevel.city, 'city:bengaluru'),
      );
      expect(city.clusters, isNotEmpty);
      for (final JourneyCluster cluster in city.clusters) {
        expect(cluster.isMemory, isTrue);
        expect(cluster.count, 1);
      }
      // Five of the eleven cinema fixtures are in Bengaluru, plus trains.
      expect(city.clusters.length, greaterThan(4));
    });

    test('a memory spanning two states appears under both', () {
      final ClusterSet country =
          clusterFor(index, const JourneyScope(JourneyLevel.country, 'IN'));
      // The Bengaluru to Delhi train is a memory of both places.
      final JourneyCluster ka = country.clusters
          .firstWhere((JourneyCluster c) => c.key == 'IN-KA');
      final JourneyCluster dl = country.clusters
          .firstWhere((JourneyCluster c) => c.key == 'IN-DL');
      final Set<String> shared = ka.events.map((e) => e.id).toSet()
        ..retainAll(dl.events.map((e) => e.id).toSet());
      expect(shared, isNotEmpty);
    });

    test('cluster labels are names, not raw codes', () {
      final ClusterSet world = clusterFor(
        index,
        JourneyScope.world,
        labelFor: (String key) => table.byId('country:$key')?.name,
      );
      final JourneyCluster india =
          world.clusters.firstWhere((JourneyCluster c) => c.key == 'IN');
      expect(india.label, 'India');
    });
  });

  group('pin declutter', () {
    test('separates coincident pins', () {
      final List<Offset> stacked = <Offset>[
        const Offset(100, 100),
        const Offset(100, 100),
        const Offset(100, 100),
      ];
      final List<Offset> spread = declutter(stacked, minSpacing: 30.0);

      for (int i = 0; i < spread.length; i++) {
        for (int j = i + 1; j < spread.length; j++) {
          expect((spread[i] - spread[j]).distance, greaterThan(1.0),
              reason: 'pins $i and $j are still stacked');
        }
      }
    });

    test('leaves already-separated pins where they are', () {
      final List<Offset> apart = <Offset>[
        const Offset(0, 0),
        const Offset(200, 0),
      ];
      expect(declutter(apart, minSpacing: 30.0), apart);
    });

    test('does not drift pins far from where they happened', () {
      final List<Offset> near = <Offset>[
        const Offset(100, 100),
        const Offset(104, 102),
        const Offset(98, 106),
      ];
      final List<Offset> spread = declutter(near, minSpacing: 34.0);
      for (int i = 0; i < near.length; i++) {
        expect((spread[i] - near[i]).distance, lessThan(60.0),
            reason: 'pin $i wandered off its city');
      }
    });

    test('is deterministic, so a settled camera gives settled pins', () {
      final List<Offset> input = <Offset>[
        const Offset(10, 10),
        const Offset(12, 11),
        const Offset(10, 10),
      ];
      expect(
        declutter(input, minSpacing: 25.0),
        declutter(input, minSpacing: 25.0),
      );
    });

    test('handles fewer than two markers', () {
      expect(declutter(const <Offset>[], minSpacing: 10.0), isEmpty);
      expect(
        declutter(const <Offset>[Offset(5, 5)], minSpacing: 10.0),
        <Offset>[const Offset(5, 5)],
      );
    });
  });
}
