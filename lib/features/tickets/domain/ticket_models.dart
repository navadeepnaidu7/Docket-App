// Train pass domain models (API-serializable).

import 'pass_status.dart';

export 'pass_status.dart' show TicketStatus, PassKind;

enum HaltState {
  departed,
  arriving,
  upcoming;

  static HaltState fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase() ?? '';
    return switch (s) {
      'departed' || 'past' => HaltState.departed,
      'arriving' || 'current' => HaltState.arriving,
      _ => HaltState.upcoming,
    };
  }

  String toJson() => name;
}

class TicketHalt {
  const TicketHalt({
    required this.time,
    required this.station,
    required this.dateLabel,
    required this.state,
    this.actual,
    this.platform,
  });

  final String time;
  final String? actual;
  final String station;
  final String? platform;
  final HaltState state;
  final String dateLabel;

  factory TicketHalt.fromJson(Map<String, dynamic> json) {
    return TicketHalt(
      time: json['time']?.toString() ?? '',
      actual: json['actual']?.toString(),
      station: json['station']?.toString() ?? '',
      platform: json['platform']?.toString(),
      state: HaltState.fromJson(json['state']),
      dateLabel: json['dateLabel']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time,
        if (actual != null) 'actual': actual,
        'station': station,
        if (platform != null) 'platform': platform,
        'state': state.toJson(),
        'dateLabel': dateLabel,
      };
}

/// One traveller on a booking (max 6).
class TicketPassenger {
  const TicketPassenger({
    required this.name,
    required this.coach,
    required this.seat,
    required this.berth,
    this.age,
    this.gender,
  });

  final String name;
  final String coach;
  final String seat;
  final String berth;
  final int? age;
  final String? gender;

  String get seatLabel => '$coach · $seat · $berth';

  factory TicketPassenger.fromJson(Map<String, dynamic> json) {
    return TicketPassenger(
      name: json['name']?.toString() ?? '',
      coach: json['coach']?.toString() ?? '',
      seat: json['seat']?.toString() ?? '',
      berth: json['berth']?.toString() ?? '',
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse(json['age']?.toString() ?? ''),
      gender: json['gender']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'coach': coach,
        'seat': seat,
        'berth': berth,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
      };
}

/// Train booking pass — primary domain type for rail tickets.
///
/// Prefer ISO fields [departAt]/[arriveAt] when available; display strings
/// remain for the current UI until client formatters replace them.
class TrainPass {
  const TrainPass({
    required this.id,
    required this.operator,
    required this.trainNumber,
    required this.trainName,
    required this.fromCode,
    required this.fromName,
    required this.toCode,
    required this.toName,
    required this.departTime,
    required this.arriveTime,
    required this.date,
    required this.arrivalDate,
    required this.duration,
    required this.ticketClass,
    required this.passengers,
    required this.pnr,
    required this.bookingId,
    required this.status,
    this.bookingStatus = 'Confirmed',
    this.chartStatus = 'Chart Prepared',
    this.liveStatusLabel = 'Running on time',
    this.progressFraction = 0.45,
    this.halts = const <TicketHalt>[],
    this.departAt,
    this.arriveAt,
    this.codeType,
    this.codePayload,
  }) : assert(passengers.length >= 1 && passengers.length <= 6);

  final String id;
  final String operator;
  final String trainNumber;
  final String trainName;
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;

  /// Display time (e.g. "07:10 AM") — keep for current cards.
  final String departTime;
  final String arriveTime;
  final String date;
  final String arrivalDate;
  final String duration;
  final String ticketClass;
  final List<TicketPassenger> passengers;
  final String pnr;
  final String bookingId;
  final TicketStatus status;
  final String bookingStatus;
  final String chartStatus;
  final String liveStatusLabel;
  final double progressFraction;
  final List<TicketHalt> halts;

  /// Preferred machine-readable timestamps (ISO-8601).
  final String? departAt;
  final String? arriveAt;

  /// Optional gate code metadata for future scannable tickets.
  final String? codeType;
  final String? codePayload;

  String get trainTitle => '$trainNumber · $trainName';

  TicketPassenger get primaryPassenger => passengers.first;

  String get passengerName => primaryPassenger.name;
  String get coach => primaryPassenger.coach;
  String get seat => primaryPassenger.seat;
  String get berth => primaryPassenger.berth;
  String get coachSeatLabel => primaryPassenger.seatLabel;
  int get passengerCount => passengers.length;

  String get passengerSummary {
    if (passengers.length == 1) return passengers.first.name;
    final String first = passengers.first.name.split(' ').first;
    return '$first +${passengers.length - 1}';
  }

  String get seatSummary {
    if (passengers.length == 1) return passengers.first.seatLabel;
    return '${passengers.length} seats';
  }

  String get seatsListLabel {
    if (passengers.length == 1) {
      return '${passengers.first.seat} ${passengers.first.berth}';
    }
    return passengers.map((TicketPassenger p) => p.seat).join(', ');
  }

  String get berthsListLabel {
    if (passengers.length == 1) return passengers.first.berth;
    final List<String> shortBerths = passengers.map((TicketPassenger p) {
      final String b = p.berth;
      if (b.toLowerCase().contains('lower')) return 'LB';
      if (b.toLowerCase().contains('middle')) return 'MB';
      if (b.toLowerCase().contains('upper')) return 'UB';
      if (b.toLowerCase().contains('side lower')) return 'SL';
      if (b.toLowerCase().contains('side upper')) return 'SU';
      return b;
    }).toList();
    return shortBerths.toSet().join('/');
  }

  String get coachesListLabel {
    final Set<String> uniqueCoaches =
        passengers.map((TicketPassenger p) => p.coach).toSet();
    return uniqueCoaches.join('/');
  }

  TicketHalt? get nextHalt {
    for (final TicketHalt h in halts) {
      if (h.state == HaltState.arriving || h.state == HaltState.upcoming) {
        return h;
      }
    }
    return null;
  }

  factory TrainPass.fromJson(Map<String, dynamic> json) {
    final List<dynamic> paxRaw =
        json['passengers'] is List ? json['passengers'] as List : const [];
    final List<dynamic> haltRaw =
        json['halts'] is List ? json['halts'] as List : const [];

    final List<TicketPassenger> passengers = paxRaw
        .whereType<Map>()
        .map(
          (Map m) =>
              TicketPassenger.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList();

    if (passengers.isEmpty) {
      passengers.add(
        const TicketPassenger(
          name: 'Passenger',
          coach: '—',
          seat: '—',
          berth: '—',
        ),
      );
    }

    return TrainPass(
      id: json['id']?.toString() ?? '',
      operator: json['operator']?.toString() ?? '',
      trainNumber: json['trainNumber']?.toString() ?? '',
      trainName: json['trainName']?.toString() ?? '',
      fromCode: json['fromCode']?.toString() ?? '',
      fromName: json['fromName']?.toString() ?? '',
      toCode: json['toCode']?.toString() ?? '',
      toName: json['toName']?.toString() ?? '',
      departTime: json['departTime']?.toString() ?? '',
      arriveTime: json['arriveTime']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      arrivalDate: json['arrivalDate']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      ticketClass: json['ticketClass']?.toString() ?? '',
      passengers: passengers,
      pnr: json['pnr']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      status: TicketStatus.fromJson(json['status']),
      bookingStatus: json['bookingStatus']?.toString() ?? 'Confirmed',
      chartStatus: json['chartStatus']?.toString() ?? 'Chart Prepared',
      liveStatusLabel:
          json['liveStatusLabel']?.toString() ?? 'Running on time',
      progressFraction: (json['progressFraction'] is num)
          ? (json['progressFraction'] as num).toDouble()
          : double.tryParse(json['progressFraction']?.toString() ?? '') ??
              0.0,
      halts: haltRaw
          .whereType<Map>()
          .map((Map m) => TicketHalt.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      departAt: json['departAt']?.toString(),
      arriveAt: json['arriveAt']?.toString(),
      codeType: json['codeType']?.toString(),
      codePayload: json['codePayload']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'operator': operator,
        'trainNumber': trainNumber,
        'trainName': trainName,
        'fromCode': fromCode,
        'fromName': fromName,
        'toCode': toCode,
        'toName': toName,
        'departTime': departTime,
        'arriveTime': arriveTime,
        'date': date,
        'arrivalDate': arrivalDate,
        'duration': duration,
        'ticketClass': ticketClass,
        'passengers':
            passengers.map((TicketPassenger p) => p.toJson()).toList(),
        'pnr': pnr,
        'bookingId': bookingId,
        'status': status.toJson(),
        'bookingStatus': bookingStatus,
        'chartStatus': chartStatus,
        'liveStatusLabel': liveStatusLabel,
        'progressFraction': progressFraction,
        'halts': halts.map((TicketHalt h) => h.toJson()).toList(),
        if (departAt != null) 'departAt': departAt,
        if (arriveAt != null) 'arriveAt': arriveAt,
        if (codeType != null) 'codeType': codeType,
        if (codePayload != null) 'codePayload': codePayload,
      };
}

/// Backward-compatible name used across presentation.
typedef MockTicket = TrainPass;
