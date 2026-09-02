import '../../tickets/domain/bus_pass_models.dart';
import '../../tickets/domain/movie_pass_models.dart';
import '../../tickets/domain/pass_activity_date.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/ticket_models.dart';
import 'flight_itinerary.dart';
import 'journey_event.dart';
import 'place.dart';
import 'place_query_parser.dart';
import 'place_resolver.dart';

/// How much of the wallet the place table could actually place.
///
/// Cheap to keep — three counters and a list — and it is the only way to find
/// out that the cinema-address heuristic broke on real extracted data. Without
/// it a coverage regression looks identical to "the user travelled less".
/// Surfaced under Settings -> Developer.
final class ResolutionReport {
  const ResolutionReport({
    required this.attempted,
    required this.resolved,
    required this.missed,
  });

  static const ResolutionReport empty =
      ResolutionReport(attempted: 0, resolved: 0, missed: <String>[]);

  final int attempted;
  final int resolved;

  /// Human labels of the queries that found nothing, deduped and sorted.
  final List<String> missed;

  double get resolutionRate => attempted == 0 ? 1.0 : resolved / attempted;

  @override
  String toString() =>
      'ResolutionReport($resolved/$attempted placed, ${missed.length} distinct misses)';
}

/// Every memory the globe knows about, split by whether it can be drawn.
final class JourneyIndex {
  const JourneyIndex({
    required this.events,
    required this.placed,
    required this.unplaced,
    required this.report,
  });

  static const JourneyIndex empty = JourneyIndex(
    events: <JourneyEvent>[],
    placed: <JourneyEvent>[],
    unplaced: <JourneyEvent>[],
    report: ResolutionReport.empty,
  );

  /// All memories, most recent first, undated last.
  final List<JourneyEvent> events;

  /// Memories with at least one resolved stop. These are what the globe draws.
  final List<JourneyEvent> placed;

  /// Memories nothing could be resolved for.
  ///
  /// **Never dropped.** They surface as a "N memories without a place" row at
  /// the foot of the level sheet and count in totals. A pass that silently
  /// disappears from the globe is the failure this whole design guards against
  /// — an empty globe and a broken globe must not look the same.
  final List<JourneyEvent> unplaced;

  final ResolutionReport report;

  bool get isEmpty => events.isEmpty;
}

/// Interior halts sampled per route.
///
/// Halts are what make a rail arc follow the line rather than cut a chord, but
/// a long-distance train carries dozens and each one costs an arc segment. Eight
/// evenly-strided samples keep the shape and cap the cost.
const int _maxSampledVias = 8;

/// Folds passes and mock flights into the globe's memory list.
///
/// Pure and synchronous: no widgets, no assets, no I/O. Injecting a fake
/// resolver makes every degradation path directly testable, which is why this
/// is a free function rather than a method on a provider.
JourneyIndex buildJourneyIndex({
  required List<WalletPassItem> passes,
  required PlaceResolver resolver,
  List<FlightItinerary> flights = const <FlightItinerary>[],
}) {
  final _ResolutionTally tally = _ResolutionTally(resolver);
  final List<JourneyEvent> events = <JourneyEvent>[];

  for (final WalletPassItem item in passes) {
    // Exhaustive over the sealed hierarchy on purpose. When FlightPassItem is
    // added to WalletPassItem this switch stops compiling, in the one file that
    // should have an opinion about it, and the fix is a single case delegating
    // to _fromItinerary below.
    final JourneyEvent event = switch (item) {
      TrainPassItem(:final ticket) => _fromTrain(ticket, tally),
      MoviePassItem(:final pass) => _fromMovie(pass, tally, item),
      BusPassItem(:final pass) => _fromBus(pass, tally, item),
    };
    events.add(event);
  }

  for (final FlightItinerary itinerary in flights) {
    events.add(_fromItinerary(itinerary, tally));
  }

  _sortByRecency(events);

  return JourneyIndex(
    events: events,
    placed: events.where((JourneyEvent e) => e.isPlottable).toList(),
    unplaced: events.where((JourneyEvent e) => !e.isPlottable).toList(),
    report: tally.build(),
  );
}

JourneyEvent _fromTrain(TrainPass ticket, _ResolutionTally tally) {
  final List<JourneyStop> stops = <JourneyStop>[
    tally.stop(
      PlaceQueryParser.station(code: ticket.fromCode, name: ticket.fromName),
      JourneyStopRole.origin,
    ),
    for (final TicketHalt halt in _sampleVias(ticket.halts))
      tally.stop(
        PlaceQueryParser.halt(halt.station),
        JourneyStopRole.via,
      ),
    tally.stop(
      PlaceQueryParser.station(code: ticket.toCode, name: ticket.toName),
      JourneyStopRole.destination,
    ),
  ];

  return JourneyEvent(
    id: 'train:${ticket.id}',
    sourceId: ticket.id,
    kind: JourneyEventKind.train,
    title: ticket.trainName.isEmpty ? ticket.operator : ticket.trainName,
    subtitle: _routeSubtitle(ticket.fromName, ticket.toName),
    stops: _tidy(stops),
    when: PassActivityDate.of(TrainPassItem(ticket)),
  );
}

JourneyEvent _fromMovie(
  MoviePass pass,
  _ResolutionTally tally,
  WalletPassItem item,
) {
  final JourneyStop venue = tally.stop(
    PlaceQueryParser.cinema(
      cinemaName: pass.cinemaName,
      cinemaAddress: pass.cinemaAddress,
    ),
    JourneyStopRole.venue,
  );

  return JourneyEvent(
    id: 'movie:${pass.id}',
    sourceId: pass.id,
    kind: JourneyEventKind.movie,
    title: pass.movieTitle,
    subtitle: pass.cinemaName,
    stops: <JourneyStop>[venue],
    when: PassActivityDate.of(item),
  );
}

JourneyEvent _fromBus(
  BusPass pass,
  _ResolutionTally tally,
  WalletPassItem item,
) {
  final List<JourneyStop> stops = <JourneyStop>[
    tally.stop(
      PlaceQueryParser.freeText(pass.boardingLocation),
      JourneyStopRole.origin,
    ),
    tally.stop(
      PlaceQueryParser.freeText(pass.dropLocation),
      JourneyStopRole.destination,
    ),
  ];

  return JourneyEvent(
    id: 'bus:${pass.id}',
    sourceId: pass.id,
    kind: JourneyEventKind.bus,
    title: pass.operator,
    subtitle: _routeSubtitle(pass.boardingLocation, pass.dropLocation),
    stops: _tidy(stops),
    when: PassActivityDate.of(item),
  );
}

/// The conversion a real `FlightPassItem` will reuse verbatim.
JourneyEvent _fromItinerary(FlightItinerary itinerary, _ResolutionTally tally) {
  final List<JourneyStop> stops = <JourneyStop>[
    tally.stop(
      PlaceQueryParser.station(
        code: itinerary.fromIata,
        name: itinerary.fromCity,
      ),
      JourneyStopRole.origin,
      at: itinerary.departAt,
    ),
    tally.stop(
      PlaceQueryParser.station(
        code: itinerary.toIata,
        name: itinerary.toCity,
      ),
      JourneyStopRole.destination,
      at: itinerary.arriveAt,
    ),
  ];

  return JourneyEvent(
    id: 'flight:${itinerary.id}',
    sourceId: itinerary.id,
    kind: JourneyEventKind.flight,
    title: itinerary.flightLabel,
    subtitle: itinerary.routeLabel,
    stops: _tidy(stops),
    when: itinerary.departAt,
  );
}

/// Evenly-strided sample of the interior halts, capped at [_maxSampledVias].
List<TicketHalt> _sampleVias(List<TicketHalt> halts) {
  if (halts.length <= _maxSampledVias) return halts;
  final List<TicketHalt> out = <TicketHalt>[];
  final int last = halts.length - 1;
  for (int i = 0; i < _maxSampledVias; i++) {
    out.add(halts[(i * last / (_maxSampledVias - 1)).round()]);
  }
  return out;
}

/// Drops unresolvable intermediate stops and collapses repeats.
///
/// Fixtures routinely repeat the endpoints in the halt list, so an untidied
/// train emits a zero-length first segment and a zero-length last one. Endpoints
/// are kept even when unresolved, so a route with one bad end degrades to a
/// point memory rather than losing its remaining half.
List<JourneyStop> _tidy(List<JourneyStop> stops) {
  final List<JourneyStop> out = <JourneyStop>[];
  for (final JourneyStop stop in stops) {
    if (stop.role == JourneyStopRole.via && !stop.isPlaced) continue;
    final JourneyStop? previous = out.isEmpty ? null : out.last;
    if (previous != null &&
        previous.isPlaced &&
        stop.isPlaced &&
        previous.place!.id == stop.place!.id) {
      // Same place twice running. Prefer whichever carries more meaning: an
      // endpoint outranks a via, so a halt that repeats the origin is dropped
      // but a via followed by the real destination is replaced.
      if (stop.role != JourneyStopRole.via) out[out.length - 1] = stop;
      continue;
    }
    out.add(stop);
  }
  return out;
}

String _routeSubtitle(String from, String to) {
  final String a = from.trim();
  final String b = to.trim();
  if (a.isEmpty && b.isEmpty) return '';
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$a to $b';
}

/// Most recent first, undated last, id as the tie-break.
///
/// The tie-break is not cosmetic: without it the order of same-day memories
/// depends on sort stability and golden tests flake.
void _sortByRecency(List<JourneyEvent> events) {
  events.sort((JourneyEvent a, JourneyEvent b) {
    final DateTime? x = a.when;
    final DateTime? y = b.when;
    if (x == null && y == null) return a.id.compareTo(b.id);
    if (x == null) return 1;
    if (y == null) return -1;
    final int byDate = y.compareTo(x);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
}

/// Wraps a resolver to count what it could and could not place.
final class _ResolutionTally {
  _ResolutionTally(this._resolver);

  final PlaceResolver _resolver;
  final Set<String> _missed = <String>{};
  int _attempted = 0;
  int _resolved = 0;

  JourneyStop stop(PlaceQuery query, JourneyStopRole role, {DateTime? at}) {
    if (query.isEmpty) {
      // Nothing to ask. Not counted as a miss — the pass never carried a place,
      // which is a different problem from a table that lacks one.
      return JourneyStop(query: query, role: role, at: at);
    }
    _attempted++;
    final Place? place = _resolver.lookup(query);
    if (place != null) {
      _resolved++;
    } else {
      _missed.add(query.label);
    }
    return JourneyStop(query: query, role: role, place: place, at: at);
  }

  ResolutionReport build() => ResolutionReport(
        attempted: _attempted,
        resolved: _resolved,
        missed: _missed.toList()..sort(),
      );
}
