import 'journey_level.dart';

/// Every tunable number in Journey's motion and framing, in one place.
///
/// These roughly twenty constants are where the difference between "premium"
/// and "school project" actually lives, and no test can tell you which side you
/// are on — golden tests pin pixels, not motion. They are gathered here so they
/// can be swept on a real device through the debug tuning overlay and then
/// frozen, rather than edited one at a time and hot-reloaded blind.
abstract final class JourneyMotion {
  JourneyMotion._();

  /// Eye distance from the globe centre, in globe radii, per level.
  ///
  /// Below about 1.05 the visible cap collapses to nothing and the horizon
  /// maths loses precision, so [city] stays well clear of the surface. At 1.28
  /// the cap is small enough to read as near-flat ground.
  static double distanceFor(JourneyLevel level) => switch (level) {
        JourneyLevel.world => 3.2,
        JourneyLevel.country => 2.1,
        JourneyLevel.region => 1.65,
        JourneyLevel.city => 1.28,
      };

  /// Fraction of the shorter viewport axis the globe's visible disc fills.
  ///
  /// Held constant across levels on purpose: the disc stays the same size while
  /// the visible cap shrinks, so descending reads as seeing *less of Earth more
  /// closely* rather than as the sphere growing. That is the whole illusion.
  static const double discFill = 0.86;

  /// How far the camera pulls back mid-flight, per radian of ground covered.
  ///
  /// This one constant does most of the work of feeling expensive: a hop
  /// between two cinemas in one city barely lifts, while India to Europe pulls
  /// right back and swoops in.
  static const double arcLiftPerRadian = 0.9 / 3.141592653589793;

  /// Flight duration floor and ceiling.
  ///
  /// A fixed duration makes short hops feel sluggish and long ones feel rushed,
  /// so the real duration is interpolated between these by angular distance.
  static const Duration flightMin = Duration(milliseconds: 520);
  static const Duration flightMax = Duration(milliseconds: 1000);

  /// One idle revolution at world level, before the first interaction.
  static const Duration idleRevolution = Duration(seconds: 120);

  /// Delay before any looping controller starts.
  ///
  /// Matches `WalletBackdrop`, which defers its loops for the same reason: the
  /// first frames after a view swap belong to layout, not to animation.
  static const Duration idleStartDelay = Duration(milliseconds: 480);

  /// Cross-fade for borders appearing as the camera descends past world level.
  static const Duration borderFade = Duration(milliseconds: 420);

  /// Reveal of a level's arcs once its camera flight settles.
  static const Duration arcReveal = Duration(milliseconds: 620);

  /// Minimum on-screen separation between two pins before they are nudged
  /// apart. Venues in one city sit within a fraction of a degree and would
  /// otherwise stack into an unreadable pile.
  static const double pinMinSpacing = 34.0;

  /// Marker radius in logical pixels, by how many memories it stands for.
  static const double clusterRadiusMin = 7.0;
  static const double clusterRadiusMax = 18.0;

  /// Land dot radius at the back and front of the visible cap.
  ///
  /// The spread is what gives the sphere its depth without any lighting model.
  static const double dotRadiusFar = 0.6;
  static const double dotRadiusNear = 2.2;

  /// Land dot opacity across the same range.
  static const double dotAlphaFar = 0.18;
  static const double dotAlphaNear = 1.0;

  /// Depth buckets the land dots are binned into.
  ///
  /// The entire planet draws in this many `drawRawPoints` calls, one per bucket,
  /// because a bucket shares a single `Paint`. More buckets is a smoother depth
  /// ramp and one more draw call each; five is under the point at which the
  /// banding is visible.
  static const int depthBuckets = 5;
}
