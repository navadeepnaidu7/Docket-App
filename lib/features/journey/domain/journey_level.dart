/// The four discrete altitudes Journey moves between.
///
/// There is no free zoom. Levels are the only way through, which is what keeps
/// every interaction purposeful and keeps the frame budget predictable — the
/// level of detail changes at known moments rather than on every frame.
enum JourneyLevel {
  world,
  country,
  region,
  city;

  /// The next level down, or null at the floor.
  JourneyLevel? get deeper => switch (this) {
        JourneyLevel.world => JourneyLevel.country,
        JourneyLevel.country => JourneyLevel.region,
        JourneyLevel.region => JourneyLevel.city,
        JourneyLevel.city => null,
      };

  /// The level above, or null at world.
  JourneyLevel? get shallower => switch (this) {
        JourneyLevel.world => null,
        JourneyLevel.country => JourneyLevel.world,
        JourneyLevel.region => JourneyLevel.country,
        JourneyLevel.city => JourneyLevel.region,
      };

  /// What a marker at this level stands for, shown under the level title.
  String get markerNoun => switch (this) {
        JourneyLevel.world => 'countries',
        JourneyLevel.country => 'regions',
        JourneyLevel.region => 'cities',
        JourneyLevel.city => 'memories',
      };

  /// True where political borders are drawn. Never at world level — the dot
  /// field is the landmass there, and lines would make it read as a map.
  bool get showsBorders => this != JourneyLevel.world;

  /// True where the globe rotates on its own before first interaction.
  bool get idleRotates => this == JourneyLevel.world;
}

/// A level plus the thing being looked at inside it.
///
/// The parent key is the cluster key of the level above: at [JourneyLevel.country]
/// it is a country code, at [JourneyLevel.region] a region code, at
/// [JourneyLevel.city] a city id. Value equality is what lets the clustering
/// provider be a `Provider.family` that caches per scope, so flying back up to
/// somewhere already visited costs nothing.
final class JourneyScope {
  const JourneyScope(this.level, [this.parentKey]);

  static const JourneyScope world = JourneyScope(JourneyLevel.world);

  final JourneyLevel level;
  final String? parentKey;

  @override
  bool operator ==(Object other) =>
      other is JourneyScope &&
      other.level == level &&
      other.parentKey == parentKey;

  @override
  int get hashCode => Object.hash(level, parentKey);

  @override
  String toString() => 'JourneyScope(${level.name}, $parentKey)';
}
