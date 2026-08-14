import 'pass_status.dart';

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
      };
}
