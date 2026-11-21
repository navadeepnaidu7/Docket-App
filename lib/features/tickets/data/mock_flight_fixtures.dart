import '../domain/flight_pass_models.dart';

// Flights are dated relative to the current *instant*, not just the day, so
// each fixture sits in the state it exists to show (delayed before departure,
// timetable only, in the air) whenever the app is opened. Times carry the
// airport's +05:30 offset, the shape the server sends.

const Duration _ist = Duration(hours: 5, minutes: 30);

/// The instant [from] now, rounded down to five minutes.
DateTime _instant(Duration from) {
  final DateTime t = DateTime.now().toUtc().add(from);
  return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute - t.minute % 5);
}

String _utc(Duration from) => _instant(from).toIso8601String();

/// RFC3339 at an Indian airport, [from] now.
String _istIn(Duration from) {
  final DateTime l = _instant(from).add(_ist);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}'
      'T${two(l.hour)}:${two(l.minute)}:00+05:30';
}

/// Demo boarding passes.
final List<FlightPass> mockFlightPasses = <FlightPass>[
  // Delayed 25 min with a gate change: the Updates feed's showcase.
  FlightPass.fromJson(<String, dynamic>{
    'id': 'mock_f1',
    'airline': 'IndiGo',
    'airlineCode': '6E',
    'flightNumber': '6E 2134',
    'bookingRef': 'X7KQ2M',
    'origin': <String, dynamic>{
      'code': 'BLR',
      'city': 'Bengaluru',
      'airport': 'Kempegowda International',
      'terminal': '1',
    },
    'destination': <String, dynamic>{
      'code': 'DEL',
      'city': 'New Delhi',
      'airport': 'Indira Gandhi International',
      'terminal': '1',
    },
    'departAt': _istIn(const Duration(hours: 2, minutes: 40)),
    'arriveAt': _istIn(const Duration(hours: 5, minutes: 30)),
    'boardingAt': _istIn(const Duration(hours: 2)),
    'gate': '12',
    'seat': '14C',
    'cabin': 'Economy',
    'boardingGroup': '3',
    'sequence': '42',
    'status': 'active',
    'passengers': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Navadeep Naidu', 'seat': '14C'},
      <String, dynamic>{'name': 'Ananya Rao', 'seat': '14D'},
    ],
    'live': <String, dynamic>{
      'state': 'scheduled',
      'departEstimatedAt': _istIn(const Duration(hours: 3, minutes: 5)),
      'arriveEstimatedAt': _istIn(const Duration(hours: 5, minutes: 50)),
      'departGate': '17',
      'departTerminal': '1',
      'arriveTerminal': '1',
      'aircraft': 'Airbus A320neo',
      'registration': 'VT-IPZ',
      // Parked at Bengaluru: ADS-B sees it on the ground before departure.
      'lat': 13.1986,
      'lon': 77.7066,
      'aircraftPhotoUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/IndiGo_VT-IJB_A320neo_Mumbai_Apr22_R16_05934.jpg/960px-IndiGo_VT-IJB_A320neo_Mumbai_Apr22_R16_05934.jpg',
      'aircraftPhotoCredit':
          'Pictured: VT-IJB, same type and livery. Photo T. A. Gonsalves, '
          'CC BY-SA 4.0',
      'updatedAt': _utc(const Duration(minutes: -3)),
    },
    'updates': <Map<String, dynamic>>[
      <String, dynamic>{
        'at': _utc(const Duration(hours: -5)),
        'type': 'gateAssigned',
        'to': '12',
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -35)),
        'type': 'aircraftFound',
        'to': 'VT-IPZ',
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -50)),
        'type': 'delay',
        'minutes': 25,
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -20)),
        'type': 'gateChange',
        'from': '12',
        'to': '17',
      },
    ],
    // A BCBP string, as the scanner hands it back off a PDF417.
    'codePayload':
        'M1NAIDU/NAVADEEP      EX7KQ2M BLRDEL6E 2134 325Y014C0042 100',
    'codeFormat': 'pdf417',
  }),

  // Timetable only: no feed yet, so the face counts down and claims nothing.
  FlightPass.fromJson(<String, dynamic>{
    'id': 'mock_f2',
    'airline': 'Air India',
    'airlineCode': 'AI',
    'flightNumber': 'AI 803',
    'bookingRef': 'Q4ZP8L',
    'origin': <String, dynamic>{
      'code': 'DEL',
      'city': 'New Delhi',
      'airport': 'Indira Gandhi International',
      'terminal': '3',
    },
    'destination': <String, dynamic>{
      'code': 'BOM',
      'city': 'Mumbai',
      'airport': 'Chhatrapati Shivaji Maharaj International',
      'terminal': '2',
    },
    'departAt': _istIn(const Duration(days: 3, hours: 4)),
    'arriveAt': _istIn(const Duration(days: 3, hours: 6, minutes: 10)),
    'boardingAt': _istIn(const Duration(days: 3, hours: 3, minutes: 25)),
    'seat': '3A',
    'cabin': 'Business',
    'status': 'active',
    'passengers': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Navadeep Naidu', 'seat': '3A'},
    ],
    'codePayload':
        'M1NAIDU/NAVADEEP      EQ4ZP8L DELBOMAI 0803 328C003A0011 100',
    'codeFormat': 'aztec',
  }),

  // In the air, running ten minutes behind.
  FlightPass.fromJson(<String, dynamic>{
    'id': 'mock_f3',
    'airline': 'Akasa Air',
    'airlineCode': 'QP',
    'flightNumber': 'QP 1406',
    'bookingRef': 'MN3T7V',
    'origin': <String, dynamic>{
      'code': 'BOM',
      'city': 'Mumbai',
      'airport': 'Chhatrapati Shivaji Maharaj International',
      'terminal': '1',
    },
    'destination': <String, dynamic>{
      'code': 'GOX',
      'city': 'Goa (Mopa)',
      'airport': 'Manohar International',
    },
    'departAt': _istIn(const Duration(minutes: -45)),
    'arriveAt': _istIn(const Duration(minutes: 25)),
    'boardingAt': _istIn(const Duration(minutes: -80)),
    'gate': '4',
    'seat': '21F',
    'status': 'active',
    'passengers': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Navadeep Naidu', 'seat': '21F'},
    ],
    'live': <String, dynamic>{
      'state': 'enRoute',
      'departActualAt': _istIn(const Duration(minutes: -35)),
      'arriveEstimatedAt': _istIn(const Duration(minutes: 35)),
      'aircraft': 'Boeing 737 MAX 8',
      'registration': 'VT-YAO',
      // Two thirds of the way down the coast, starting the descent.
      'lat': 16.65,
      'lon': 73.25,
      'altitudeFt': 21400,
      'groundSpeedKt': 386,
      'aircraftPhotoUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Akasa_Air_VT-YAO_Mumbai_Jul25_A7CR_05993.jpg/960px-Akasa_Air_VT-YAO_Mumbai_Jul25_A7CR_05993.jpg',
      'aircraftPhotoCredit': 'Photo of VT-YAO by T. A. Gonsalves, CC BY-SA 4.0',
      'updatedAt': _utc(const Duration(minutes: -1)),
    },
    'updates': <Map<String, dynamic>>[
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -110)),
        'type': 'aircraftFound',
        'to': 'VT-YAO',
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -80)),
        'type': 'boarding',
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -35)),
        'type': 'departed',
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -18)),
        'type': 'cruising',
        'to': '32000',
      },
      <String, dynamic>{
        'at': _utc(const Duration(minutes: -4)),
        'type': 'descending',
      },
    ],
  }),
];
