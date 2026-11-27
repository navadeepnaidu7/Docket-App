import '../../ids/domain/id_document.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/domain/bus_pass_models.dart';
import '../../tickets/domain/movie_pass_models.dart';
import '../../tickets/domain/ticket_models.dart';

/// Sample documents and passes the onboarding artwork renders through the real
/// wallet card faces. One invented holder across all of them, and nothing here
/// is ever stored.
abstract final class OnboardingDemo {
  static const String holder = 'Aarav Sharma';

  static final IdDocument aadhaar = IdDocument(
    id: 'onboarding_aadhaar',
    type: IdDocumentType.aadhaar,
    holderName: holder,
    documentNumber: '4821 7736 9054',
    dateOfBirth: '12/03/1994',
    gender: 'Male',
    address: '14 Lavelle Road, Bengaluru, Karnataka 560001',
  );

  static final IdDocument pan = IdDocument(
    id: 'onboarding_pan',
    type: IdDocumentType.pan,
    holderName: holder,
    documentNumber: 'BQRPS4821K',
    dateOfBirth: '12/03/1994',
    fatherName: 'Rajesh Sharma',
  );

  static final PassportProfile passport = PassportProfile(
    id: 'onboarding_passport',
    name: holder,
    passportNumber: 'Z4821773',
    nationality: 'IND',
    dateOfBirth: '1994-03-12',
    expiryDate: '2034-03-11',
    issueDate: '2024-03-12',
    placeOfBirth: 'BENGALURU',
    issuingAuthority: 'BENGALURU',
    gender: 'M',
    imagePath: '',
    mrzRaw: '',
    isEPassport: true,
  );

  static String _date(int days) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final DateTime d = DateTime.now().add(Duration(days: days));
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  static String _at(int days, int hour, int minute) {
    final DateTime n = DateTime.now().add(Duration(days: days));
    return DateTime(n.year, n.month, n.day, hour, minute).toIso8601String();
  }

  /// A Rajdhani running late, so the live scene has something to report.
  static TrainPass train() => TrainPass(
    id: 'onboarding_train',
    operator: 'IRCTC',
    trainNumber: '22691',
    trainName: 'Rajdhani Express',
    fromCode: 'SBC',
    fromName: 'KSR Bengaluru',
    toCode: 'NDLS',
    toName: 'New Delhi',
    departTime: '20:00',
    arriveTime: '06:00',
    date: _date(1),
    arrivalDate: _date(3),
    departAt: _at(1, 20, 0),
    duration: '34h 00m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: holder,
        coach: 'B2',
        seat: '34',
        berth: 'Lower',
        age: 32,
        gender: 'M',
      ),
    ],
    pnr: '4521378960',
    bookingId: 'IRCTC4521378960',
    codePayload: 'IRCTC|4521378960|SBC|NDLS|2A',
    status: TicketStatus.active,
    progressFraction: 0.0,
    liveStatusLabel: 'Running 40 minutes late',
    runState: TrainRunState.delayed,
    delayMinutes: 40,
  );

  static BusPass bus() => BusPass(
    id: 'onboarding_bus',
    operator: 'redBus',
    brand: BusPassBrand.redBus,
    fromCity: 'Bengaluru',
    toCity: 'Mysuru',
    boardingLocation: 'Bengaluru, Kempegowda Bus Station',
    dropLocation: 'Mysuru, Mysuru City Bus Stand',
    boardingPoint: 'Kempegowda Bus Station',
    platform: 'Platform 15',
    departTime: '08:30 AM',
    arriveTime: '11:45 AM',
    date: _date(2),
    arrivalDate: _date(2),
    departAt: _at(2, 8, 30),
    arriveAt: _at(2, 11, 45),
    seatDetails: '12A',
    fare: '₹650',
    passengers: const <BusPassenger>[BusPassenger(name: holder, seat: '12A')],
    bookingId: 'RB8842119',
    codePayload: 'RBQR8842119LP3KD7NQ',
    status: TicketStatus.active,
  );

  static MoviePass movie() => MoviePass(
    id: 'onboarding_movie',
    brand: MoviePassBrand.bookMyShow,
    movieTitle: 'Dune: Part Three',
    movieSubtitle: 'Sci-Fi · UA 13+',
    cinemaName: 'PVR INOX Phoenix Mall',
    cinemaAddress: 'Phoenix Marketcity, Whitefield, Bengaluru',
    screen: 'Screen 5 · IMAX',
    showDate: 'Fri, 18 Dec 2026',
    showAt: '2026-12-18T19:15:00+05:30',
    showTime: '7:15 PM',
    format: 'IMAX 2D',
    language: 'English',
    seats: const <MovieSeat>[
      MovieSeat(row: 'H', number: '12'),
      MovieSeat(row: 'H', number: '13'),
    ],
    bookingId: 'BMS-8F2K9P1Q',
    codePayload: 'BMSQR8F2K9P1QW4XN7T2',
    orderId: 'ORD99763JS',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.sciFi,
    certification: 'UA 13+',
    runtime: '2h 40m',
    gateType: 'QR Scan',
    posterAsset: 'assets/passes/fixtures/dune_part_three_poster.jpg',
    logoAsset: 'assets/passes/fixtures/dune_part_three_logo.png',
  );
}
