/// The text half of a shared pass.
///
/// A shared pass leaves the app as two things: a PNG of the card, and these
/// lines. The image carries the identity; the text carries what someone needs
/// to read, quote back, or search for in a chat six weeks later.
///
/// Deliberately plain Dart with no Flutter import, so the wording is unit
/// testable without pumping a widget. Every value on these models defaults to
/// the empty string rather than null, so each line is emitted only when it has
/// something after the label — a line reading `Seat:` is worse than no line.
library;

import 'bus_pass_models.dart';
import 'movie_pass_models.dart';
import 'pass_catalog.dart';
import 'ticket_models.dart';

/// Lines describing [item], newline joined. Never empty.
String buildPassShareText(WalletPassItem item) {
  final List<String> lines = switch (item) {
    TrainPassItem(:final TrainPass ticket) => _trainLines(ticket),
    BusPassItem(:final BusPass pass) => _busLines(pass),
    MoviePassItem(:final MoviePass pass) => _movieLines(pass),
  };
  return lines.join('\n');
}

/// The payload to encode in the shared image's QR, or null for no QR at all.
///
/// This is the single place the omit-when-absent rule lives. It never falls
/// back to a PNR or a booking ID: those identify a booking, they are not what a
/// gate scanner reads, and a QR that scans to the wrong thing is worse at a
/// turnstile than no QR at all. Null here means the share card draws no code
/// block.
String? passShareCodePayload(WalletPassItem item) {
  final String? raw = switch (item) {
    TrainPassItem(:final TrainPass ticket) => ticket.codePayload,
    BusPassItem(:final BusPass pass) => pass.codePayload,
    MoviePassItem(:final MoviePass pass) => pass.codePayload,
  };
  return _clean(raw);
}

/// The human-readable reference printed under the QR — the thing you would read
/// aloud at a counter when the scanner fails.
String? passShareCodeCaption(WalletPassItem item) {
  return switch (item) {
    TrainPassItem(:final TrainPass ticket) => _labelled('PNR', ticket.pnr),
    BusPassItem(:final BusPass pass) => _labelled('Booking', pass.bookingId),
    MoviePassItem(:final MoviePass pass) => _labelled('Booking', pass.bookingId),
  };
}

/// Short kind label for the share card's header strip.
String passShareKindLabel(WalletPassItem item) => switch (item) {
      TrainPassItem() => 'Train ticket',
      BusPassItem() => 'Bus ticket',
      MoviePassItem() => 'Movie ticket',
    };

/// File name for the exported PNG.
///
/// Sanitised hard: this string reaches a file system, a share sheet and a photo
/// library, and pass ids are server-issued strings we do not control.
String passShareFileName(WalletPassItem item) {
  final String kind = switch (item) {
    TrainPassItem() => 'train',
    BusPassItem() => 'bus',
    MoviePassItem() => 'movie',
  };
  final String slug = item.id
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final String tail = slug.isEmpty ? 'pass' : slug;
  return 'docket-$kind-$tail';
}

// ── Per kind ─────────────────────────────────────────────────────────────────

List<String> _trainLines(TrainPass t) {
  final List<String> out = <String>[];
  _add(out, null, t.trainTitle);
  _add(out, null, _route(t.fromName, t.toName));
  _add(out, 'Depart', _joinDot(t.date, t.departTime));
  _add(out, 'Arrive', _joinDot(t.arrivalDate, t.arriveTime));
  _add(out, 'Class', t.ticketClass);
  _add(out, 'Coach', t.coachesListLabel);
  _add(out, t.passengerCount == 1 ? 'Seat' : 'Seats', t.seatsListLabel);
  _add(out, t.passengerCount == 1 ? 'Passenger' : 'Passengers',
      t.passengers.map((TicketPassenger p) => p.name).join(', '));
  _add(out, 'PNR', t.pnr);
  _add(out, 'Booking ID', t.bookingId);
  return _fallback(out, 'Train ticket');
}

List<String> _busLines(BusPass b) {
  final List<String> out = <String>[];
  _add(out, null, b.operator);
  _add(out, null, _route(b.resolvedFromCity, b.resolvedToCity));
  _add(out, 'Depart', _joinDot(b.date, b.departTime));
  _add(out, 'Arrive', _joinDot(b.arrivalDate, b.arriveTime));
  _add(out, 'Boarding',
      b.boardingPoint.trim().isNotEmpty ? b.boardingPoint : b.boardingLocation);
  _add(out, 'Drop', b.dropLocation);
  _add(out, 'Bay', b.platform);
  _add(out, 'Seats', b.seatDetails.trim().isNotEmpty
      ? b.seatDetails
      : b.passengers
          .map((BusPassenger p) => p.seat)
          .where((String s) => s.trim().isNotEmpty)
          .join(', '));
  _add(out, b.passengers.length == 1 ? 'Passenger' : 'Passengers',
      b.passengers.map((BusPassenger p) => p.name).join(', '));
  _add(out, 'Fare', b.fare);
  _add(out, 'Booking ID', b.bookingId);
  return _fallback(out, 'Bus ticket');
}

List<String> _movieLines(MoviePass m) {
  final List<String> out = <String>[];
  _add(out, null, m.movieTitle);
  _add(out, null, m.movieSubtitle);
  _add(out, null, _joinDot(m.format, m.language));
  _add(out, 'Show', _joinDot(m.showDate, m.showTime));
  _add(out, 'Venue', m.cinemaName);
  _add(out, 'Address', m.cinemaAddress);
  _add(out, 'Screen', m.screen);
  _add(out, m.seatCount == 1 ? 'Seat' : 'Seats', m.seatListLabel);
  _add(out, 'Booking ID', m.bookingId);
  return _fallback(out, 'Movie ticket');
}

// ── Formatting helpers ───────────────────────────────────────────────────────

/// Appends `Label: value`, or a bare value when [label] is null. A blank value
/// appends nothing.
void _add(List<String> out, String? label, String value) {
  final String? v = _clean(value);
  if (v == null) return;
  out.add(label == null ? v : '$label: $v');
}

String _route(String from, String to) {
  final String a = from.trim();
  final String b = to.trim();
  if (a.isEmpty && b.isEmpty) return '';
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$a to $b';
}

/// Joins the non-blank parts with the app's separator dot.
String _joinDot(String a, String b) {
  final List<String> parts = <String>[a, b]
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();
  return parts.join(' · ');
}

String? _labelled(String label, String value) {
  final String? v = _clean(value);
  return v == null ? null : '$label $v';
}

String? _clean(String? raw) {
  final String v = raw?.trim() ?? '';
  return v.isEmpty ? null : v;
}

/// A pass whose every field came back blank still has to share as something.
List<String> _fallback(List<String> lines, String kind) =>
    lines.isEmpty ? <String>[kind] : lines;
