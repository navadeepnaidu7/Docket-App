import 'geo_point.dart';
import 'journey_event.dart';
import 'journey_index.dart';
import 'journey_level.dart';
import 'place.dart';

/// A marker on the globe: either a group of memories, or one memory.
final class JourneyCluster {
  const JourneyCluster({
    required this.key,
    required this.label,
    required this.point,
    required this.position,
    required this.events,
    required this.isMemory,
  });

  /// The grouping key at this level: a country code, region code, city id, or
  /// at city level the id of the memory itself.
  final String key;

  final String label;
  final GeoPoint point;

  /// Unit vector for [point], precomputed because it is projected every frame.
  final Vec3 position;

  final List<JourneyEvent> events;

  /// True at city level, where a marker stands for a single memory and draws
  /// as a pin rather than as a count bubble.
  final bool isMemory;

  int get count => events.length;
}

/// Every marker for one scope, plus what could not be shown.
final class ClusterSet {
  const ClusterSet({
    required this.scope,
    required this.clusters,
    required this.unplacedCount,
  });

  static const ClusterSet empty = ClusterSet(
    scope: JourneyScope.world,
    clusters: <JourneyCluster>[],
    unplacedCount: 0,
  );

  final JourneyScope scope;
  final List<JourneyCluster> clusters;

  /// Memories with no resolvable place. Surfaced as a row, never dropped.
  final int unplacedCount;

  bool get isEmpty => clusters.isEmpty;

  int get memoryCount =>
      clusters.fold<int>(0, (int sum, JourneyCluster c) => sum + c.count);
}

/// Groups an index into the markers one scope should show.
///
/// This is a hash-map grouping, not a spatial clustering algorithm. The place
/// table carries the hierarchy — every row knows its city, region and country —
/// so each level's key is already a field and no geometry is involved. That is
/// also why it is cheap enough to be a plain provider rather than something
/// cached by hand.
///
/// An event spanning several groups appears in each of them. A train from
/// Bengaluru to Delhi genuinely is a memory of both places, and hiding it from
/// one would be answering a different question than "where have I been".
///
/// [labelFor] turns a grouping key into a display name — `IN` into `India`,
/// `IN-KA` into `Karnataka`. Without it a cluster would be captioned with the
/// name of whichever place happened to be seen first, so a whole state would
/// read as the city the user's train left from.
ClusterSet clusterFor(
  JourneyIndex index,
  JourneyScope scope, {
  String? Function(String key)? labelFor,
}) {
  final Map<String, List<JourneyEvent>> grouped = <String, List<JourneyEvent>>{};
  final Map<String, Place> anchor = <String, Place>{};
  final Map<String, List<Vec3>> positions = <String, List<Vec3>>{};

  for (final JourneyEvent event in index.placed) {
    // A memory can touch a group more than once (origin and a halt in the same
    // state); it should still only be counted once there.
    final Set<String> keysForEvent = <String>{};

    for (final JourneyStop stop in event.placedStops) {
      final Place place = stop.place!;
      if (!_inScope(place, scope)) continue;

      final String? key = _keyFor(place, scope.level, event);
      if (key == null) continue;

      positions.putIfAbsent(key, () => <Vec3>[]).add(place.point.unitVector);
      anchor.putIfAbsent(key, () => place);
      if (keysForEvent.add(key)) {
        grouped.putIfAbsent(key, () => <JourneyEvent>[]).add(event);
      }
    }
  }

  final bool isMemoryLevel = scope.level == JourneyLevel.city;
  final List<JourneyCluster> clusters = <JourneyCluster>[];

  grouped.forEach((String key, List<JourneyEvent> events) {
    final Vec3? centre = sphericalCentroid(positions[key]!);
    if (centre == null) return;
    final Place place = anchor[key]!;
    clusters.add(
      JourneyCluster(
        key: key,
        label: isMemoryLevel
            ? events.first.title
            : labelFor?.call(key) ?? _labelFor(place, scope.level),
        point: geoPointFor(centre),
        position: centre,
        events: events,
        isMemory: isMemoryLevel,
      ),
    );
  });

  // Busiest first, then by key, so the order is stable across rebuilds and the
  // biggest marker never flickers behind a smaller one.
  clusters.sort((JourneyCluster a, JourneyCluster b) {
    final int byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.key.compareTo(b.key);
  });

  return ClusterSet(
    scope: scope,
    clusters: clusters,
    unplacedCount: index.unplaced.length,
  );
}

/// True when a place sits under the scope's parent.
bool _inScope(Place place, JourneyScope scope) {
  final String? parent = scope.parentKey;
  if (parent == null) return true;
  return switch (scope.level) {
    JourneyLevel.world => true,
    JourneyLevel.country => place.countryCode == parent,
    JourneyLevel.region => place.regionCode == parent,
    JourneyLevel.city => place.cityKey == parent,
  };
}

/// The grouping key a place contributes at a level.
String? _keyFor(Place place, JourneyLevel level, JourneyEvent event) =>
    switch (level) {
      JourneyLevel.world => place.countryCode,
      JourneyLevel.country => place.regionCode,
      JourneyLevel.region => place.cityKey,
      // At the floor a marker is one memory, so the key is the memory itself.
      JourneyLevel.city => event.id,
    };

String _labelFor(Place place, JourneyLevel level) => switch (level) {
      JourneyLevel.world => place.countryCode ?? place.name,
      JourneyLevel.country => place.regionCode ?? place.name,
      JourneyLevel.region => place.name,
      JourneyLevel.city => place.name,
    };
