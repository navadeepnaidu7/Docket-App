import 'pass_code.dart';
import 'pass_status.dart';

/// Operator whose chrome the bus pass wears.
///
/// Mirrors [MoviePassBrand]: layout reads a resolved style object instead of
/// scattering `operator ==` checks. Unknown operators fall to [universal],
/// which is a neutral slate card rather than anyone's branding.
enum BusPassBrand {
  redBus,
  universal;

  static BusPassBrand fromJson(Object? raw) {
    final String n =
        (raw?.toString() ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    return switch (n) {
      'redbus' => BusPassBrand.redBus,
      _ => BusPassBrand.universal,
    };
  }

  /// Best-effort brand for a booking whose payload carries no explicit brand.
  ///
  /// Extracted tickets arrive with an operator name and nothing else, so the
  /// name is the only signal available. Deliberately a containment check on a
  /// squashed string: operators are written "redBus", "Red Bus", "RedBus Trips"
  /// and an exact match would miss all but the first.
  static BusPassBrand fromOperator(String operator) {
    final String n =
        operator.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    if (n.contains('redbus')) return BusPassBrand.redBus;
    return BusPassBrand.universal;
  }

  String toJson() => name;
}

/// One traveller on a bus booking.
class BusPassenger {
  const BusPassenger({
    required this.name,
    this.seat = '',
  });

  final String name;
  final String seat;

  factory BusPassenger.fromJson(Map<String, dynamic> json) {
    return BusPassenger(
      name: json['name']?.toString() ?? '',
      seat: json['seat']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (seat.isNotEmpty) 'seat': seat,
      };
}

/// Bus booking pass — first-cut wallet type for extracted coach tickets.
class BusPass {
  const BusPass({
    required this.id,
    required this.operator,
    required this.boardingLocation,
    required this.dropLocation,
    required this.departTime,
    required this.arriveTime,
    required this.date,
    required this.arrivalDate,
    required this.status,
    this.seatDetails = '',
    this.passengers = const <BusPassenger>[],
    this.bookingId = '',
    this.departAt,
    this.arriveAt,
    this.brand,
    this.fromCity = '',
    this.toCity = '',
    this.boardingPoint = '',
    this.platform = '',
    this.fare = '',
    this.codePayload,
    this.codePayloadBase64,
    this.codeFormat,
  });

  final String id;
  final String operator;
  final String boardingLocation;
  final String dropLocation;
  final String departTime;
  final String arriveTime;
  final String date;
  final String arrivalDate;
  final TicketStatus status;
  final String seatDetails;
  final List<BusPassenger> passengers;
  final String bookingId;
  final String? departAt;
  final String? arriveAt;

  /// Explicit brand when the payload names one. Null means "infer from
  /// [operator]" — see [resolvedBrand].
  final BusPassBrand? brand;

  /// City endpoints, used for the header route line. Empty falls back to the
  /// leading segment of the stop, which is how operators write it.
  final String fromCity;
  final String toCity;

  /// Where to physically stand, when the operator distinguishes it from the
  /// drop/boarding *location*. Empty falls back to [boardingLocation].
  final String boardingPoint;

  /// Bay or platform number at the boarding point.
  final String platform;

  /// Fare as a display string, currency symbol included. Deliberately not a
  /// number: the server sends it formatted, and a bus fare is never arithmetic
  /// on the client.
  final String fare;

  /// Raw payload for a real QR/barcode library, decoded off the uploaded
  /// ticket on device. Matches the field trains and movies already carry, and
  /// is nullable for the same reason: plenty of passes have no code. Null means
  /// this pass has no scannable code — callers must render nothing rather than
  /// inventing one. See `docs/features/ticket-code-extraction.md`.
  final String? codePayload;

  /// Base64 payload, set instead of [codePayload] when the symbol's bytes are
  /// not valid UTF-8.
  final String? codePayloadBase64;

  /// Symbology wire value; absent means QR. See [PassCodeFormat].
  final String? codeFormat;

  /// The scannable code, or null when this pass has none.
  PassCode? get passCode => PassCode.parse(
        payload: codePayload,
        payloadBase64: codePayloadBase64,
        format: codeFormat,
      );

  /// The brand to dress this pass in — explicit when given, inferred from the
  /// operator name otherwise.
  BusPassBrand get resolvedBrand =>
      brand ?? BusPassBrand.fromOperator(operator);

  /// City for the origin, falling back to the leading segment of the stop.
  String get resolvedFromCity =>
      fromCity.trim().isNotEmpty ? fromCity.trim() : _leadSegment(boardingLocation);

  /// City for the destination, same fallback.
  String get resolvedToCity =>
      toCity.trim().isNotEmpty ? toCity.trim() : _leadSegment(dropLocation);

  String get routeLabel {
    final String from = boardingLocation.trim();
    final String to = dropLocation.trim();
    if (from.isEmpty && to.isEmpty) return operator;
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from → $to';
  }

  factory BusPass.fromJson(Map<String, dynamic> json) {
    final List<dynamic> paxRaw =
        json['passengers'] is List ? json['passengers'] as List : const [];
    return BusPass(
      id: json['id']?.toString() ?? '',
      operator: json['operator']?.toString() ?? '',
      boardingLocation: json['boardingLocation']?.toString() ?? '',
      dropLocation: json['dropLocation']?.toString() ?? '',
      departTime: json['departTime']?.toString() ?? '',
      arriveTime: json['arriveTime']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      arrivalDate: json['arrivalDate']?.toString() ?? '',
      status: TicketStatus.fromJson(json['status']),
      seatDetails: json['seatDetails']?.toString() ?? '',
      passengers: paxRaw
          .whereType<Map>()
          .map((Map m) => BusPassenger.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      bookingId: json['bookingId']?.toString() ?? '',
      departAt: json['departAt']?.toString(),
      arriveAt: json['arriveAt']?.toString(),
      brand: json['brand'] == null ? null : BusPassBrand.fromJson(json['brand']),
      fromCity: json['fromCity']?.toString() ?? '',
      toCity: json['toCity']?.toString() ?? '',
      boardingPoint: json['boardingPoint']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      fare: json['fare']?.toString() ?? '',
      codePayload: json['codePayload']?.toString(),
      codePayloadBase64: json['codePayloadBase64']?.toString(),
      codeFormat: json['codeFormat']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'operator': operator,
        'boardingLocation': boardingLocation,
        'dropLocation': dropLocation,
        'departTime': departTime,
        'arriveTime': arriveTime,
        'date': date,
        'arrivalDate': arrivalDate,
        'status': status.toJson(),
        if (seatDetails.isNotEmpty) 'seatDetails': seatDetails,
        if (passengers.isNotEmpty)
          'passengers':
              passengers.map((BusPassenger p) => p.toJson()).toList(),
        if (bookingId.isNotEmpty) 'bookingId': bookingId,
        if (departAt != null) 'departAt': departAt,
        if (arriveAt != null) 'arriveAt': arriveAt,
        if (brand != null) 'brand': brand!.toJson(),
        if (fromCity.isNotEmpty) 'fromCity': fromCity,
        if (toCity.isNotEmpty) 'toCity': toCity,
        if (boardingPoint.isNotEmpty) 'boardingPoint': boardingPoint,
        if (platform.isNotEmpty) 'platform': platform,
        if (fare.isNotEmpty) 'fare': fare,
        if (codePayload != null) 'codePayload': codePayload,
        if (codePayloadBase64 != null) 'codePayloadBase64': codePayloadBase64,
        if (codeFormat != null) 'codeFormat': codeFormat,
      };
}

/// Leading comma-separated segment of a free-text stop, which is where
/// operators put the city ("Bengaluru, Kempegowda Bus Station").
String _leadSegment(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return '';
  final int i = value.indexOf(',');
  return i <= 0 ? value : value.substring(0, i).trim();
}
