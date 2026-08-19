import 'place.dart';

/// What produced a memory. Presentation only — never branched on to decide
/// whether something is a point or a route.
enum JourneyEventKind {
  train,
  bus,
  movie,
  flight,
  event,
}

/// What a stop is to the memory it belongs to.
enum JourneyStopRole {
  origin,
  via,
  destination,
  venue,
}

/// One place a memory touched, resolved or not.
///
/// [query] is always kept, even after a successful lookup. It is what the
/// "could not place" list shows, and what makes a resolution failure debuggable
/// without re-deriving it from the original pass.
final class JourneyStop {
  const JourneyStop({
    required this.query,
    required this.role,
    this.place,
    this.at,
  });

  final PlaceQuery query;
  final JourneyStopRole role;

  /// Null is a normal state, not an error.
  final Place? place;

  final DateTime? at;

  bool get isPlaced => place != null;

  @override
  String toString() => 'JourneyStop(${place?.id ?? query.label}, $role)';
}

/// A single memory on the globe.
///
/// The one idea that removes every render-time special case: **a memory is an
/// ordered list of stops.** A movie has one, a train has origin, sampled halts
/// and destination, a flight has two. Nothing downstream asks what kind of pass
/// produced it — it asks how many stops resolved:
///
/// * one placed stop  -> a point memory, drawn as a pin
/// * two or more      -> a route, drawn as arcs between consecutive stops
///
/// A train whose destination will not resolve therefore degrades to a point at
/// the end that did, with no branch anywhere and no fallback path to maintain.
///
/// This class deliberately knows nothing about `WalletPassItem`. That ignorance
/// is what lets a real flight pass slot in later without touching the renderer,
/// the clustering, or anything else that consumes a [JourneyEvent].
final class JourneyEvent {
  const JourneyEvent({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.stops,
    this.when,
  });

  /// Globe-unique, namespaced by kind: `train:mock_t1`, `flight:mock_f1`.
  final String id;

  /// The originating pass id, so a pin can open the real card.
  final String sourceId;

  final JourneyEventKind kind;

  /// `'Rajdhani Express'`, `'Dune: Part Two'`.
  final String title;

  /// `'Hyderabad to Bengaluru'`, `'PVR INOX Phoenix Mall'`.
  final String subtitle;

  final List<JourneyStop> stops;

  /// Resolved by `PassActivityDate.of` upstream. Null when nothing parsed.
  final DateTime? when;

  Iterable<JourneyStop> get placedStops =>
      stops.where((JourneyStop s) => s.isPlaced);

  /// True when at least one stop has coordinates, so something can be drawn.
  bool get isPlottable => stops.any((JourneyStop s) => s.isPlaced);

  /// True when this draws as a route rather than a single pin.
  bool get isRoute => placedStops.length >= 2;

  /// The place this memory is filed under when clustered.
  ///
  /// The origin end of a journey, or the single venue of a point memory. A
  /// round trip files under where it started, which is what "where have I been"
  /// means when you are looking at your own life rather than a timetable.
  Place? get anchorPlace {
    for (final JourneyStop stop in stops) {
      if (stop.isPlaced) return stop.place;
    }
    return null;
  }

  @override
  String toString() => 'JourneyEvent($id, ${stops.length} stops)';
}
