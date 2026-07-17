// Train pass models and mock data for the Passes tab.

enum TicketStatus { active, expired }

enum HaltState { departed, arriving, upcoming }

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
}

class MockTicket {
  const MockTicket({
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
  }) : assert(passengers.length >= 1 && passengers.length <= 6);

  final String id;
  final String operator;
  final String trainNumber;
  final String trainName;
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;
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

  TicketHalt? get nextHalt {
    for (final TicketHalt h in halts) {
      if (h.state == HaltState.arriving || h.state == HaltState.upcoming) {
        return h;
      }
    }
    return null;
  }
}

// ── Mock catalogue ────────────────────────────────────────────────────────────

final List<MockTicket> mockTickets = <MockTicket>[
  MockTicket(
    id: 'mock_t1',
    operator: 'IRCTC',
    trainNumber: '12427',
    trainName: 'Rajdhani Express',
    fromCode: 'NZM',
    fromName: 'H. Nizamuddin',
    toCode: 'NDLS',
    toName: 'New Delhi',
    departTime: '08:40',
    arriveTime: '13:10',
    date: '23 Mar 2024',
    arrivalDate: '23 Mar 2024',
    duration: '4h 30m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'B2',
        seat: '23',
        berth: 'Lower',
        age: 28,
        gender: 'M',
      ),
      TicketPassenger(
        name: 'Ananya Rao',
        coach: 'B2',
        seat: '24',
        berth: 'Upper',
        age: 26,
        gender: 'F',
      ),
      TicketPassenger(
        name: 'Vikram Rao',
        coach: 'B2',
        seat: '25',
        berth: 'Middle',
        age: 54,
        gender: 'M',
      ),
    ],
    pnr: '2432587612',
    bookingId: 'E12345678',
    status: TicketStatus.active,
    progressFraction: 0.48,
    liveStatusLabel: 'Running on time',
    halts: const <TicketHalt>[
      TicketHalt(
        time: '08:40',
        station: 'H. Nizamuddin (NZM)',
        dateLabel: 'Sat, 23 Mar',
        state: HaltState.departed,
        platform: 'PF 5',
      ),
      TicketHalt(
        time: '10:15',
        station: 'Mathura Jn (MTJ)',
        dateLabel: 'Sat, 23 Mar',
        state: HaltState.departed,
        platform: 'PF 2',
      ),
      TicketHalt(
        time: '11:40',
        actual: '11:48',
        station: 'Agra Cantt (AGC)',
        dateLabel: 'Sat, 23 Mar',
        state: HaltState.arriving,
        platform: 'PF 3',
      ),
      TicketHalt(
        time: '12:20',
        station: 'Hazrat Nizamuddin (NZM)',
        dateLabel: 'Sat, 23 Mar',
        state: HaltState.upcoming,
        platform: 'PF 1',
      ),
      TicketHalt(
        time: '13:10',
        station: 'New Delhi (NDLS)',
        dateLabel: 'Sat, 23 Mar',
        state: HaltState.upcoming,
        platform: 'PF 12',
      ),
    ],
  ),
  MockTicket(
    id: 'mock_t3',
    operator: 'IRCTC',
    trainNumber: '22691',
    trainName: 'Rajdhani Express',
    fromCode: 'SBC',
    fromName: 'KSR Bengaluru',
    toCode: 'NDLS',
    toName: 'New Delhi',
    departTime: '20:00',
    arriveTime: '06:00',
    date: '02 Jun 2024',
    arrivalDate: '04 Jun 2024',
    duration: '34h 00m',
    ticketClass: 'AC 1 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'H1',
        seat: '04',
        berth: 'Lower',
        age: 28,
        gender: 'M',
      ),
    ],
    pnr: '4109823761',
    bookingId: 'E23456789',
    status: TicketStatus.active,
    progressFraction: 0.12,
    liveStatusLabel: 'Running on time',
    halts: const <TicketHalt>[
      TicketHalt(
        time: '20:00',
        station: 'KSR Bengaluru (SBC)',
        dateLabel: 'Sun, 02 Jun',
        state: HaltState.departed,
        platform: 'PF 8',
      ),
      TicketHalt(
        time: '23:45',
        station: 'Guntakal Jn (GTL)',
        dateLabel: 'Sun, 02 Jun',
        state: HaltState.arriving,
        platform: 'PF 2',
        actual: '23:52',
      ),
      TicketHalt(
        time: '06:30',
        station: 'Jhansi Jn (JHS)',
        dateLabel: 'Mon, 03 Jun',
        state: HaltState.upcoming,
        platform: 'PF 4',
      ),
      TicketHalt(
        time: '06:00',
        station: 'New Delhi (NDLS)',
        dateLabel: 'Tue, 04 Jun',
        state: HaltState.upcoming,
        platform: 'PF 14',
      ),
    ],
  ),
  MockTicket(
    id: 'mock_t4',
    operator: 'IRCTC',
    trainNumber: '12163',
    trainName: 'Chennai Express',
    fromCode: 'NDLS',
    fromName: 'New Delhi',
    toCode: 'MAS',
    toName: 'Chennai Central',
    departTime: '22:30',
    arriveTime: '19:45',
    date: '15 Jun 2024',
    arrivalDate: '16 Jun 2024',
    duration: '21h 15m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'A2',
        seat: '12',
        berth: 'Side Upper',
      ),
      TicketPassenger(
        name: 'Priya Sharma',
        coach: 'A2',
        seat: '13',
        berth: 'Side Lower',
      ),
      TicketPassenger(
        name: 'Arjun Sharma',
        coach: 'A2',
        seat: '14',
        berth: 'Lower',
      ),
      TicketPassenger(
        name: 'Meera Sharma',
        coach: 'A2',
        seat: '15',
        berth: 'Upper',
      ),
      TicketPassenger(
        name: 'Kabir Mehta',
        coach: 'A3',
        seat: '01',
        berth: 'Lower',
      ),
      TicketPassenger(
        name: 'Saanvi Mehta',
        coach: 'A3',
        seat: '02',
        berth: 'Upper',
      ),
    ],
    pnr: '6637291048',
    bookingId: 'E34567890',
    status: TicketStatus.active,
    progressFraction: 0.0,
    liveStatusLabel: 'Scheduled',
    chartStatus: 'Chart not prepared',
    bookingStatus: 'Confirmed',
    halts: const <TicketHalt>[
      TicketHalt(
        time: '22:30',
        station: 'New Delhi (NDLS)',
        dateLabel: 'Sat, 15 Jun',
        state: HaltState.upcoming,
        platform: 'PF 9',
      ),
      TicketHalt(
        time: '19:45',
        station: 'Chennai Central (MAS)',
        dateLabel: 'Sun, 16 Jun',
        state: HaltState.upcoming,
        platform: 'PF 5',
      ),
    ],
  ),
  MockTicket(
    id: 'mock_t2',
    operator: 'IRCTC',
    trainNumber: '12951',
    trainName: 'Mumbai Rajdhani',
    fromCode: 'NDLS',
    fromName: 'New Delhi',
    toCode: 'BCT',
    toName: 'Mumbai Central',
    departTime: '16:55',
    arriveTime: '08:15',
    date: '10 Jan 2024',
    arrivalDate: '11 Jan 2024',
    duration: '15h 20m',
    ticketClass: 'AC 3 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'A1',
        seat: '45',
        berth: 'Upper',
      ),
      TicketPassenger(
        name: 'Rohan Iyer',
        coach: 'A1',
        seat: '46',
        berth: 'Middle',
      ),
    ],
    pnr: '8821456730',
    bookingId: 'E98765432',
    status: TicketStatus.expired,
    bookingStatus: 'Completed',
    liveStatusLabel: 'Journey completed',
    progressFraction: 1.0,
    halts: const <TicketHalt>[
      TicketHalt(
        time: '16:55',
        station: 'New Delhi (NDLS)',
        dateLabel: 'Wed, 10 Jan',
        state: HaltState.departed,
        platform: 'PF 6',
      ),
      TicketHalt(
        time: '08:15',
        station: 'Mumbai Central (BCT)',
        dateLabel: 'Thu, 11 Jan',
        state: HaltState.departed,
        platform: 'PF 3',
      ),
    ],
  ),
  MockTicket(
    id: 'mock_t5',
    operator: 'IRCTC',
    trainNumber: '12650',
    trainName: 'Karnataka Express',
    fromCode: 'SBC',
    fromName: 'KSR Bengaluru',
    toCode: 'NZM',
    toName: 'H. Nizamuddin',
    departTime: '19:45',
    arriveTime: '06:30',
    date: '14 Nov 2023',
    arrivalDate: '16 Nov 2023',
    duration: '34h 45m',
    ticketClass: 'AC 3 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'B4',
        seat: '32',
        berth: 'Middle',
      ),
    ],
    pnr: '3312984756',
    bookingId: 'E87654321',
    status: TicketStatus.expired,
    bookingStatus: 'Completed',
    liveStatusLabel: 'Journey completed',
    progressFraction: 1.0,
  ),
  MockTicket(
    id: 'mock_t6',
    operator: 'IRCTC',
    trainNumber: '12028',
    trainName: 'Shatabdi Express',
    fromCode: 'MAS',
    fromName: 'Chennai Central',
    toCode: 'SBC',
    toName: 'KSR Bengaluru',
    departTime: '06:00',
    arriveTime: '11:00',
    date: '03 Sep 2023',
    arrivalDate: '03 Sep 2023',
    duration: '5h 00m',
    ticketClass: 'CC Chair Car',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'C3',
        seat: '67',
        berth: 'Seat',
      ),
    ],
    pnr: '9901234567',
    bookingId: 'E76543210',
    status: TicketStatus.expired,
    bookingStatus: 'Completed',
    liveStatusLabel: 'Journey completed',
    progressFraction: 1.0,
  ),
];
