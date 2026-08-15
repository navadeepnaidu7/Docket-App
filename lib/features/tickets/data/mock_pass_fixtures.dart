import '../domain/movie_pass_models.dart';
import '../domain/ticket_models.dart';

/// TMDB CDN base for mock poster/logo art (design probe only).
///
/// Production will keep using the Docket image proxy — `image.tmdb.org` is blocked on many
/// Indian ISPs. Direct URLs here skip the backend so the logo-glance design can be checked
/// without `MOCK_POSTER_ORIGIN` or a running server.
const String _tmdbImageBase = 'https://image.tmdb.org/t/p';

/// Fixture poster URL (TMDB `w500` one-sheet).
String _mockPosterUrl(String file) => '$_tmdbImageBase/w500/$file';

/// Fixture logo URL (TMDB transparent title art, same size bucket as posters).
String _mockLogoUrl(String file) => '$_tmdbImageBase/w500/$file';

// ── Demo journey dates ────────────────────────────────────────────────────────
//
// The *active* train fixtures date themselves relative to launch. Hardcoded
// dates rot: the wallet card's status band exists to show a countdown, and a
// pinned 2025 date makes every "upcoming" mock pass render as a completed
// journey a few months after it was written. The expired fixtures keep their
// fixed dates on purpose — the archive tests group them by month and assert the
// order.

const List<String> _monthsShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime get _today {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Display date [days] from today, e.g. "16 Aug 2026".
String _dateIn(int days) {
  final DateTime d = _today.add(Duration(days: days));
  final String dd = d.day.toString().padLeft(2, '0');
  return '$dd ${_monthsShort[d.month - 1]} ${d.year}';
}

/// Machine-readable departure [days] from today at [hour]:[minute], local.
String _departsIn(int days, int hour, int minute) {
  final DateTime d = _today.add(Duration(days: days));
  return DateTime(d.year, d.month, d.day, hour, minute).toIso8601String();
}

/// Demo train bookings (same content as the previous mock catalogue).
final List<TrainPass> mockTrainPasses = <TrainPass>[
  TrainPass(
    id: 'mock_t1',
    operator: 'IRCTC',
    trainNumber: '12932',
    trainName: 'Rajdhani Express',
    fromCode: 'HYB',
    fromName: 'Hyderabad',
    toCode: 'BLR',
    toName: 'Bengaluru',
    departTime: '07:10 AM',
    arriveTime: '02:40 PM',
    date: _dateIn(3),
    arrivalDate: _dateIn(3),
    departAt: _departsIn(3, 7, 10),
    duration: '7h 30m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'B2',
        seat: '32',
        berth: 'Lower',
        age: 28,
        gender: 'M',
      ),
      TicketPassenger(
        name: 'Ananya Rao',
        coach: 'B2',
        seat: '33',
        berth: 'Upper',
        age: 26,
        gender: 'F',
      ),
      TicketPassenger(
        name: 'Vikram Rao',
        coach: 'B2',
        seat: '34',
        berth: 'Middle',
        age: 54,
        gender: 'M',
      ),
    ],
    pnr: '1234567890',
    bookingId: 'IRCTC1234567890',
    status: TicketStatus.active,
    progressFraction: 0.48,
    liveStatusLabel: 'Running 45 minutes late',
    runState: TrainRunState.delayed,
    delayMinutes: 45,
    halts: const <TicketHalt>[
      TicketHalt(
        time: '07:10',
        station: 'Hyderabad Decan (HYB)',
        dateLabel: 'Sun, 20 Jul',
        state: HaltState.departed,
        platform: 'PF 5',
      ),
      TicketHalt(
        time: '09:15',
        station: 'Kazipet Jn (KZJ)',
        dateLabel: 'Sun, 20 Jul',
        state: HaltState.departed,
        platform: 'PF 2',
      ),
      TicketHalt(
        time: '11:40',
        actual: '11:48',
        station: 'Vijayawada Jn (BZA)',
        dateLabel: 'Sun, 20 Jul',
        state: HaltState.arriving,
        platform: 'PF 3',
      ),
      TicketHalt(
        time: '12:20',
        station: 'Guntur Jn (GNT)',
        dateLabel: 'Sun, 20 Jul',
        state: HaltState.upcoming,
        platform: 'PF 1',
      ),
      TicketHalt(
        time: '14:40',
        station: 'KSR Bengaluru (SBC)',
        dateLabel: 'Sun, 20 Jul',
        state: HaltState.upcoming,
        platform: 'PF 12',
      ),
    ],
  ),
  TrainPass(
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
    date: _dateIn(1),
    arrivalDate: _dateIn(2),
    departAt: _departsIn(1, 20, 0),
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
    runState: TrainRunState.onTime,
    delayMinutes: 0,
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
  TrainPass(
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
    date: _dateIn(9),
    arrivalDate: _dateIn(10),
    departAt: _departsIn(9, 22, 30),
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
    runState: TrainRunState.scheduled,
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
  TrainPass(
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
    runState: TrainRunState.arrived,
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
  TrainPass(
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
    runState: TrainRunState.arrived,
    progressFraction: 1.0,
  ),
  TrainPass(
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
    runState: TrainRunState.arrived,
    progressFraction: 1.0,
  ),
];

/// Demo movie bookings.
final List<MoviePass> mockMoviePasses = <MoviePass>[
  MoviePass(
    id: 'movie_bms_1',
    brand: MoviePassBrand.bookMyShow,
    movieTitle: 'Dune: Part Two',
    movieSubtitle: 'Sci-Fi · UA 13+',
    cinemaName: 'PVR INOX Phoenix Mall',
    cinemaAddress: 'Phoenix Marketcity, Whitefield, Bengaluru',
    screen: 'Screen 5 · IMAX',
    showDate: 'Sat, 12 Apr 2025',
    showTime: '7:15 PM',
    format: 'IMAX 2D',
    language: 'English',
    seats: const <MovieSeat>[
      MovieSeat(row: 'H', number: '12'),
      MovieSeat(row: 'H', number: '13'),
    ],
    bookingId: 'BMS-8F2K9P1Q',
    orderId: 'ORD99763JS',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.sciFi,
    certification: 'UA 13+',
    runtime: '2h 46m',
    gateType: 'QR Scan',
    // TMDB 693134 — live poster + English title logo (transparent PNG).
    posterUrl: _mockPosterUrl('heM4XKC0jA8fTSNe8F7oUkcJV7Z.jpg'),
    logoUrl: _mockLogoUrl('eYvF1LhPKuoBxOAmWjFTAK7EPWl.png'),
  ),
  MoviePass(
    id: 'movie_dist_1',
    brand: MoviePassBrand.district,
    movieTitle: 'The Odyssey',
    movieSubtitle: 'Adventure · UA',
    cinemaName: 'Cinepolis Nexus Mall',
    cinemaAddress: 'Nexus Koramangala, Bengaluru',
    screen: 'Audi 3',
    showDate: 'Sun, 13 Apr 2025',
    showTime: '10:00 PM',
    format: 'Dolby Atmos',
    language: 'English',
    seats: const <MovieSeat>[
      MovieSeat(row: 'F', number: '08'),
      MovieSeat(row: 'F', number: '09'),
      MovieSeat(row: 'F', number: '10'),
    ],
    bookingId: 'DST-4A71C2E9',
    orderId: 'DZM8821456',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.sciFi,
    certification: 'UA',
    runtime: '2h 18m',
    gateType: 'QR Scan',
    // TMDB 1368337
    posterUrl: _mockPosterUrl('5rhTDKUhPYvpdQIijFIs5VoWsON.jpg'),
    logoUrl: _mockLogoUrl('kX6ZX4GL7km04332caiOVapR2lb.png'),
  ),
  MoviePass(
    id: 'movie_uni_1',
    brand: MoviePassBrand.universal,
    movieTitle: 'Spider-Man: Brand New Day',
    movieSubtitle: 'Action · UA',
    cinemaName: 'Miraj Cinemas Orion',
    cinemaAddress: 'Orion Mall, Rajajinagar, Bengaluru',
    screen: 'Screen 2',
    showDate: 'Fri, 18 Apr 2025',
    showTime: '6:30 PM',
    format: '2D',
    language: 'English',
    seats: const <MovieSeat>[
      MovieSeat(row: 'J', number: '05'),
      MovieSeat(row: 'J', number: '06'),
    ],
    bookingId: 'TKT-GBD99763',
    orderId: 'GBD99763JS',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.action,
    certification: 'UA',
    runtime: '2h 15m',
    gateType: 'Barcode',
    sourcePlatform: 'PVR',
    codeType: MovieTicketCodeType.barcode,
    // TMDB 969681
    posterUrl: _mockPosterUrl('lH6LQcUhkVOK6ekvXzthQAogUnR.jpg'),
    logoUrl: _mockLogoUrl('vbZcDHC5IFylYuRnp3eyOs5rTV1.png'),
  ),
  MoviePass(
    id: 'movie_bms_2',
    brand: MoviePassBrand.bookMyShow,
    movieTitle: 'Kalki 2898 AD',
    movieSubtitle: 'Sci-Fi · UA',
    cinemaName: 'INOX Garuda Mall',
    cinemaAddress: 'Magrath Road, Bengaluru',
    screen: 'Screen 1',
    showDate: 'Mon, 10 Feb 2025',
    showTime: '4:00 PM',
    format: '4DX',
    language: 'Hindi',
    seats: const <MovieSeat>[MovieSeat(row: 'D', number: '14')],
    bookingId: 'BMS-1A2B3C4D',
    orderId: 'ORD44120XZ',
    status: TicketStatus.expired,
    posterHint: MoviePosterHint.sciFi,
    certification: 'UA',
    runtime: '3h 01m',
    // TMDB 801688
    posterUrl: _mockPosterUrl('4P3K5medethmTlsuN7UN5bmnATq.jpg'),
    logoUrl: _mockLogoUrl('phv0D4lpztKSUqNByCJkP1HB1IS.png'),
  ),
  MoviePass(
    id: 'movie_dist_2',
    brand: MoviePassBrand.district,
    movieTitle: 'Pushpa 2: The Rule',
    movieSubtitle: 'Action · UA',
    cinemaName: 'PVR Forum Mall',
    cinemaAddress: 'Koramangala, Bengaluru',
    screen: 'Audi 7',
    showDate: 'Sat, 14 Dec 2024',
    showTime: '9:45 PM',
    format: 'IMAX 2D',
    language: 'Telugu',
    seats: const <MovieSeat>[
      MovieSeat(row: 'K', number: '18'),
      MovieSeat(row: 'K', number: '19'),
    ],
    bookingId: 'DST-9C2E11A0',
    orderId: 'DZM4419082',
    status: TicketStatus.expired,
    posterHint: MoviePosterHint.action,
    certification: 'UA',
    runtime: '3h 20m',
    // TMDB 857598 — Telugu logo (stronger local mark than sparse EN set).
    posterUrl: _mockPosterUrl('mXQRQUhrISOwlQTVOtPCoBltnOG.jpg'),
    logoUrl: _mockLogoUrl('cCNpEDPa6QA8VfDS4UTAEKnNDwc.png'),
  ),
];

/// @deprecated Use [mockTrainPasses].
final List<TrainPass> mockTickets = mockTrainPasses;
