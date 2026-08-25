import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_share_summary.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';

TrainPass _train({
  String pnr = '1234567890',
  String bookingId = 'IRCTC1234567890',
  String ticketClass = '3A',
  String? codePayload,
  List<TicketPassenger> passengers = const <TicketPassenger>[
    TicketPassenger(
      name: 'Navadeep Naidu',
      coach: 'B2',
      seat: '41',
      berth: 'Lower',
    ),
  ],
}) {
  return TrainPass(
    id: 't',
    operator: 'IRCTC',
    trainNumber: '12658',
    trainName: 'KSR Bengaluru Express',
    fromCode: 'SBC',
    fromName: 'KSR Bengaluru',
    toCode: 'MAS',
    toName: 'MGR Chennai Central',
    departTime: '22:40',
    arriveTime: '06:15',
    date: '26 Aug 2026',
    arrivalDate: '27 Aug 2026',
    duration: '7h 35m',
    ticketClass: ticketClass,
    passengers: passengers,
    pnr: pnr,
    bookingId: bookingId,
    status: TicketStatus.active,
    bookingStatus: 'CNF',
    chartStatus: 'Chart prepared',
    liveStatusLabel: 'On time',
    runState: TrainRunState.onTime,
    codePayload: codePayload,
  );
}

BusPass _bus({
  String bookingId = 'RB8842119',
  String seatDetails = '12A',
  String fare = '₹650',
  String platform = 'Platform 15',
  String? codePayload,
}) {
  return BusPass(
    id: 'b',
    operator: 'redBus',
    boardingLocation: 'Bengaluru, Kempegowda Bus Station',
    dropLocation: 'Mysuru, Mysuru City Bus Stand',
    departTime: '08:30 AM',
    arriveTime: '11:45 AM',
    date: '20 Aug 2026',
    arrivalDate: '20 Aug 2026',
    status: TicketStatus.active,
    seatDetails: seatDetails,
    passengers: const <BusPassenger>[
      BusPassenger(name: 'Navadeep Naidu', seat: '12A'),
    ],
    bookingId: bookingId,
    fromCity: 'Bengaluru',
    toCity: 'Mysuru',
    boardingPoint: 'Kempegowda Bus Station',
    platform: platform,
    fare: fare,
    codePayload: codePayload,
  );
}

MoviePass _movie({
  String bookingId = 'BMS-8F2K9P1Q',
  String cinemaAddress = 'Phoenix Marketcity, Whitefield, Bengaluru',
  String screen = 'Screen 5 - IMAX',
  String? codePayload,
  List<MovieSeat> seats = const <MovieSeat>[
    MovieSeat(row: 'H', number: '14'),
  ],
}) {
  return MoviePass(
    id: 'm',
    brand: MoviePassBrand.bookMyShow,
    movieTitle: 'Dune: Part Two',
    movieSubtitle: 'English',
    cinemaName: 'PVR INOX Phoenix Mall',
    cinemaAddress: cinemaAddress,
    screen: screen,
    showDate: '26 Aug 2026',
    showTime: '9:45 PM',
    format: 'IMAX 2D',
    language: 'English',
    seats: seats,
    bookingId: bookingId,
    orderId: 'ORD-99120',
    status: TicketStatus.active,
    posterHint: MoviePosterHint.sciFi,
    codePayload: codePayload,
  );
}

void main() {
  group('buildPassShareText', () {
    test('train carries route, timing, seat and references', () {
      final String text = buildPassShareText(TrainPassItem(_train()));

      expect(text, contains('12658 · KSR Bengaluru Express'));
      expect(text, contains('KSR Bengaluru to MGR Chennai Central'));
      expect(text, contains('Depart: 26 Aug 2026 · 22:40'));
      expect(text, contains('Arrive: 27 Aug 2026 · 06:15'));
      expect(text, contains('Class: 3A'));
      expect(text, contains('Coach: B2'));
      expect(text, contains('PNR: 1234567890'));
    });

    test('train pluralises seat and passenger labels', () {
      final TrainPass one = _train();
      expect(buildPassShareText(TrainPassItem(one)), contains('Seat: '));
      expect(buildPassShareText(TrainPassItem(one)), contains('Passenger: '));

      final TrainPass two = _train(
        passengers: const <TicketPassenger>[
          TicketPassenger(
            name: 'Navadeep Naidu',
            coach: 'B2',
            seat: '41',
            berth: 'Lower',
          ),
          TicketPassenger(
            name: 'Asha Rao',
            coach: 'B2',
            seat: '42',
            berth: 'Middle',
          ),
        ],
      );
      final String text = buildPassShareText(TrainPassItem(two));
      expect(text, contains('Seats: '));
      expect(text, contains('Passengers: '));
      expect(text, contains('Asha Rao'));
    });

    test('bus falls back from boarding point to boarding location', () {
      final String text = buildPassShareText(BusPassItem(_bus()));

      expect(text, contains('redBus'));
      expect(text, contains('Bengaluru to Mysuru'));
      expect(text, contains('Boarding: Kempegowda Bus Station'));
      expect(text, contains('Fare: ₹650'));
      expect(text, contains('Booking ID: RB8842119'));
    });

    test('movie carries venue, screen and seats', () {
      final String text = buildPassShareText(MoviePassItem(_movie()));

      expect(text, contains('Dune: Part Two'));
      expect(text, contains('IMAX 2D · English'));
      expect(text, contains('Show: 26 Aug 2026 · 9:45 PM'));
      expect(text, contains('Venue: PVR INOX Phoenix Mall'));
      expect(text, contains('Screen: Screen 5 - IMAX'));
      expect(text, contains('Seat: H14'));
    });

    // Almost every field on these models defaults to '' rather than null, so
    // the risk is not a crash but a line reading "Screen:" with nothing after
    // it going out to someone else's phone.
    test('blank fields drop their whole line rather than emitting a bare label',
        () {
      final String text = buildPassShareText(
        MoviePassItem(_movie(cinemaAddress: '', screen: '   ')),
      );

      expect(text, isNot(contains('Address')));
      expect(text, isNot(contains('Screen')));
      expect(text, contains('Venue: PVR INOX Phoenix Mall'));
      for (final String line in text.split('\n')) {
        expect(line.trim(), isNotEmpty);
        expect(line.trim(), isNot(endsWith(':')));
      }
    });

    test('bus with every optional field blank still shares as something', () {
      final String text = buildPassShareText(
        BusPassItem(_bus(bookingId: '', seatDetails: '', fare: '', platform: '')),
      );

      expect(text, isNotEmpty);
      expect(text, isNot(contains('Fare')));
      expect(text, isNot(contains('Bay')));
    });
  });

  group('passShareCodePayload', () {
    test('returns the payload when the pass carries one', () {
      expect(
        passShareCodePayload(TrainPassItem(_train(codePayload: 'ABC123'))),
        'ABC123',
      );
      expect(
        passShareCodePayload(BusPassItem(_bus(codePayload: 'BUS999'))),
        'BUS999',
      );
      expect(
        passShareCodePayload(MoviePassItem(_movie(codePayload: 'MOV777'))),
        'MOV777',
      );
    });

    // The whole point of the rule: a QR that scans to a booking reference is
    // not the code a gate reads, and printing one into a shared image is worse
    // than printing none.
    test('never substitutes a PNR or booking ID when the payload is absent',
        () {
      expect(passShareCodePayload(TrainPassItem(_train())), isNull);
      expect(passShareCodePayload(BusPassItem(_bus())), isNull);
      expect(passShareCodePayload(MoviePassItem(_movie())), isNull);
    });

    test('treats a whitespace-only payload as absent', () {
      expect(
        passShareCodePayload(TrainPassItem(_train(codePayload: '   '))),
        isNull,
      );
    });
  });

  group('passShareFileName', () {
    test('is kind-prefixed and slugged', () {
      expect(
        passShareFileName(TrainPassItem(_train())),
        'docket-train-t',
      );
    });

    test('strips anything a file system or share target could choke on', () {
      final MoviePass pass = MoviePass(
        id: 'BMS/8F2K 9P1Q..\\x',
        brand: MoviePassBrand.bookMyShow,
        movieTitle: 'X',
        movieSubtitle: '',
        cinemaName: '',
        cinemaAddress: '',
        screen: '',
        showDate: '',
        showTime: '',
        format: '',
        language: '',
        seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
        bookingId: '',
        orderId: '',
        status: TicketStatus.active,
        posterHint: MoviePosterHint.action,
      );
      final String name = passShareFileName(MoviePassItem(pass));

      expect(name, 'docket-movie-bms-8f2k-9p1q-x');
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(name), isTrue);
    });

    test('falls back when an id slugs away to nothing', () {
      final BusPass pass = _bus();
      final BusPass blank = BusPass(
        id: '///',
        operator: pass.operator,
        boardingLocation: pass.boardingLocation,
        dropLocation: pass.dropLocation,
        departTime: pass.departTime,
        arriveTime: pass.arriveTime,
        date: pass.date,
        arrivalDate: pass.arrivalDate,
        status: pass.status,
      );
      expect(passShareFileName(BusPassItem(blank)), 'docket-bus-pass');
    });
  });

  group('passShareCodeCaption', () {
    test('is the PNR for a train and the booking for the rest', () {
      expect(
        passShareCodeCaption(TrainPassItem(_train())),
        'PNR 1234567890',
      );
      expect(
        passShareCodeCaption(BusPassItem(_bus())),
        'Booking RB8842119',
      );
      expect(
        passShareCodeCaption(MoviePassItem(_movie())),
        'Booking BMS-8F2K9P1Q',
      );
    });

    test('is null when there is no reference to print', () {
      expect(passShareCodeCaption(MoviePassItem(_movie(bookingId: ''))), isNull);
    });
  });
}
