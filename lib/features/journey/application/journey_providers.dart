import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../data/journey_atlas.dart';
import '../data/mock_flight_fixtures.dart';
import '../data/place_table.dart';
import '../domain/flight_itinerary.dart';
import '../domain/geo_point.dart';
import '../domain/journey_camera.dart';
import '../domain/journey_cluster.dart';
import '../domain/journey_event.dart';
import '../domain/journey_index.dart';
import '../domain/journey_level.dart';
import '../domain/place_resolver.dart';

/// The packed globe geometry.
///
/// Decoded off the UI isolate: the work is only a few milliseconds, but it
/// lands on the frame the user opens Journey, and that is the one frame that
/// must not jank. Follows the `compute` pattern in `attachment_store.dart`.
///
/// A failure here is not fatal. The globe falls back to its wireframe — rim,
/// arcs and markers, no continents — because a Journey that still tells you
/// where you have been beats an error screen, and "missing data is a normal
/// state" is the house rule everywhere else in this app.
final journeyAtlasProvider = FutureProvider<JourneyAtlas>((Ref ref) async {
  try {
    final ByteData raw = await rootBundle.load(AppAssets.journeyAtlas);
    final Uint8List bytes = raw.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );
    return await compute(decodeJourneyAtlas, bytes);
  } catch (error) {
    debugPrint('Journey atlas unavailable, falling back to wireframe: $error');
    return JourneyAtlas.wireframe;
  }
});

/// The curated place table.
///
/// Parsed on the main isolate deliberately: a few dozen rows is well under a
/// millisecond, and shipping it through `compute` would cost more in isolate
/// hand-off than the parse itself.
final placeTableProvider = FutureProvider<PlaceTable>((Ref ref) async {
  try {
    return PlaceTable.decode(
      await rootBundle.loadString(AppAssets.journeyPlaces),
    );
  } catch (error) {
    debugPrint('Journey place table unavailable: $error');
    return PlaceTable.empty;
  }
});

/// Synchronous place lookup, empty until the table lands.
///
/// The empty resolver is what lets Journey open with no spinner: the globe
/// draws immediately with every memory listed as unplaced, then rebuilds once
/// the table arrives. One frame of an empty globe beats a loading state.
final placeResolverProvider = Provider<PlaceResolver>((Ref ref) {
  final PlaceTable? table = ref.watch(placeTableProvider).valueOrNull;
  if (table == null || table.length == 0) return const EmptyPlaceResolver();
  return BundledPlaceResolver(table);
});

/// Mock flights, until a real flight pass kind exists.
final mockFlightsProvider = Provider<List<FlightItinerary>>(
  (Ref ref) => mockFlightItineraries,
);

/// Every memory Journey knows about.
///
/// A plain synchronous `Provider` folding lists in one pass — the same shape as
/// `spaceArchiveAnalyticsProvider`. Keeping it synchronous is what the
/// resolver's synchronous `lookup` buys, and it means clustering downstream
/// never has to deal with `AsyncValue`.
final journeyEventsProvider = Provider<JourneyIndex>((Ref ref) {
  final List<WalletPassItem> passes =
      ref.watch(passListProvider).value ?? const <WalletPassItem>[];
  return buildJourneyIndex(
    passes: passes,
    flights: ref.watch(mockFlightsProvider),
    resolver: ref.watch(placeResolverProvider),
  );
});

/// Markers for one scope, cached per scope.
///
/// `Provider.family` keyed by a value type means flying back up to a level
/// already visited costs nothing, while any change to the underlying memories
/// still invalidates every scope at once.
final journeyClustersProvider =
    Provider.family<ClusterSet, JourneyScope>((Ref ref, JourneyScope scope) {
  final PlaceTable? table = ref.watch(placeTableProvider).valueOrNull;
  return clusterFor(
    ref.watch(journeyEventsProvider),
    scope,
    labelFor: (String key) => _labelForKey(table, key),
  );
});

/// Resolves a cluster key to a display name via the table's own rows.
String? _labelForKey(PlaceTable? table, String key) {
  if (table == null) return null;
  return table.byId('country:$key')?.name ??
      table.byId('region:$key')?.name ??
      table.byId(key)?.name;
}

/// Where the globe opens: over the centre of gravity of the user's own travel.
///
/// A hard-coded home would be a map's idea of a default. This is a memory
/// atlas, so the first thing on screen should already be about them.
GlobeCamera initialCameraFor(JourneyIndex index) {
  final List<Vec3> points = <Vec3>[
    for (final JourneyEvent event in index.placed)
      for (final JourneyStop stop in event.placedStops)
        stop.place!.point.unitVector,
  ];
  final Vec3? centre = sphericalCentroid(points);
  final GeoPoint target =
      centre == null ? const GeoPoint(20.0, 78.0) : geoPointFor(centre);
  return GlobeCamera.forLevel(JourneyLevel.world, target);
}

/// One step of the descent, kept so the back affordance can retrace it.
final class JourneyCrumb {
  const JourneyCrumb({
    required this.level,
    required this.parentKey,
    required this.camera,
    required this.label,
  });

  final JourneyLevel level;
  final String? parentKey;
  final GlobeCamera camera;
  final String label;
}

/// Where the camera is going, and how it got here.
///
/// Holds the *destination* camera only. The interpolated in-flight value lives
/// in an `AnimationController` inside the view: putting a value that changes
/// sixty times a second into a provider would rebuild every consumer just as
/// often.
final class JourneyNavState {
  const JourneyNavState({
    required this.level,
    required this.parentKey,
    required this.camera,
    required this.stack,
    required this.title,
    this.selectedEventId,
  });

  final JourneyLevel level;
  final String? parentKey;
  final GlobeCamera camera;
  final List<JourneyCrumb> stack;
  final String title;
  final String? selectedEventId;

  JourneyScope get scope => JourneyScope(level, parentKey);

  bool get canGoBack => stack.isNotEmpty;

  JourneyNavState copyWith({
    JourneyLevel? level,
    String? parentKey,
    GlobeCamera? camera,
    List<JourneyCrumb>? stack,
    String? title,
    String? selectedEventId,
    bool clearParent = false,
    bool clearSelection = false,
  }) =>
      JourneyNavState(
        level: level ?? this.level,
        parentKey: clearParent ? null : (parentKey ?? this.parentKey),
        camera: camera ?? this.camera,
        stack: stack ?? this.stack,
        title: title ?? this.title,
        selectedEventId:
            clearSelection ? null : (selectedEventId ?? this.selectedEventId),
      );
}

/// Drives descent and ascent between the four levels.
class JourneyNavigator extends StateNotifier<JourneyNavState> {
  JourneyNavigator(GlobeCamera home)
      : super(
          JourneyNavState(
            level: JourneyLevel.world,
            parentKey: null,
            camera: home,
            stack: const <JourneyCrumb>[],
            title: 'Journey',
          ),
        );

  /// Descends into a cluster, or selects it when already at the floor.
  void descendInto(JourneyCluster cluster) {
    if (cluster.isMemory) {
      state = state.copyWith(selectedEventId: cluster.events.first.id);
      return;
    }
    final JourneyLevel? next = state.level.deeper;
    if (next == null) return;

    state = JourneyNavState(
      level: next,
      parentKey: cluster.key,
      camera: GlobeCamera.forLevel(next, cluster.point),
      stack: <JourneyCrumb>[
        ...state.stack,
        JourneyCrumb(
          level: state.level,
          parentKey: state.parentKey,
          camera: state.camera,
          label: state.title,
        ),
      ],
      title: cluster.label,
    );
  }

  /// Retraces one step. Clearing a selection counts as a step.
  void back() {
    if (state.selectedEventId != null) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    if (state.stack.isEmpty) return;

    final JourneyCrumb crumb = state.stack.last;
    state = JourneyNavState(
      level: crumb.level,
      parentKey: crumb.parentKey,
      camera: crumb.camera,
      stack: state.stack.sublist(0, state.stack.length - 1),
      title: crumb.label,
    );
  }

  void select(String? eventId) {
    state = eventId == null
        ? state.copyWith(clearSelection: true)
        : state.copyWith(selectedEventId: eventId);
  }
}

// Rotation from dragging deliberately does NOT live here. It is a per-frame
// value owned by the view, layered on top of this settled camera and reset on
// every descent, so a level always opens framed on whatever was tapped.

final journeyNavigatorProvider =
    StateNotifierProvider<JourneyNavigator, JourneyNavState>((Ref ref) {
  return JourneyNavigator(initialCameraFor(ref.read(journeyEventsProvider)));
});
