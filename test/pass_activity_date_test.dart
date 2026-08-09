import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_activity_date.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';

TrainPass train({String? departAt, required String date}) {
  return TrainPass(
    id: 'test',
    operator: 'IRCTC',
    trainNumber: '12345',
    trainName: 'Test Express',
    fromCode: 'AAA',
    fromName: 'Origin',
    toCode: 'BBB',
    toName: 'Destination',
    departTime: '10:00',
    arriveTime: '18:00',
    date: date,
    arrivalDate: date,
    duration: '8h',
    ticketClass: 'SL',
    passengers: const <TicketPassenger>[
      TicketPassenger(name: 'Test', coach: 'S1', seat: '1', berth: 'Lower'),
    ],
    pnr: '0000000000',
    bookingId: 'E0',
    status: TicketStatus.expired,
    departAt: departAt,
  );
}

MoviePass movie({String? showAt, required String showDate}) {
  return MoviePass(
    id: 'test',
    brand: MoviePassBrand.universal,
    movieTitle: 'Test Film',
    movieSubtitle: 'Drama',
    cinemaName: 'Test Cinema',
    cinemaAddress: 'Somewhere',
    screen: 'Screen 1',
    showDate: showDate,
    showTime: '7:00 PM',
    format: '2D',
    language: 'English',
    seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
    bookingId: 'B0',
    orderId: 'O0',
    status: TicketStatus.expired,
    showAt: showAt,
  );
}

void main() {
  group('PassActivityDate.parse — display forms', () {
    test('day month year', () {
      expect(PassActivityDate.parse('10 Jan 2024'), DateTime(2024, 1, 10));
      expect(PassActivityDate.parse('14 Nov 2023'), DateTime(2023, 11, 14));
    });

    test('zero-padded day', () {
      expect(PassActivityDate.parse('03 Sep 2023'), DateTime(2023, 9, 3));
    });

    test('strips a leading weekday token', () {
      expect(PassActivityDate.parse('Mon, 10 Feb 2025'), DateTime(2025, 2, 10));
      expect(PassActivityDate.parse('Sat, 14 Dec 2024'), DateTime(2024, 12, 14));
    });

    test('long month names', () {
      expect(PassActivityDate.parse('10 January 2024'), DateTime(2024, 1, 10));
      expect(
        PassActivityDate.parse('Wed, 4 September 2024'),
        DateTime(2024, 9, 4),
      );
    });

    test('month-first order', () {
      expect(PassActivityDate.parse('Feb 10, 2025'), DateTime(2025, 2, 10));
    });

    test('two-digit year expands to 2000s', () {
      expect(PassActivityDate.parse('10 Jan 24'), DateTime(2024, 1, 10));
    });
  });

  group('PassActivityDate.parse — ISO', () {
    test('ISO instant wins over display parsing', () {
      // Mid-day UTC so .toLocal() cannot shift the day in any CI timezone.
      final DateTime? parsed = PassActivityDate.parse('2025-02-10T12:00:00Z');
      expect(parsed, isNotNull);
      expect(parsed!.month, 2);
      expect(parsed.day, 10);
      expect(parsed.year, 2025);
    });

    test('date-only ISO parses', () {
      expect(PassActivityDate.parse('2024-01-10'), DateTime(2024, 1, 10));
    });
  });

  group('PassActivityDate.parse — rejections', () {
    test('null, empty and blank', () {
      expect(PassActivityDate.parse(null), isNull);
      expect(PassActivityDate.parse(''), isNull);
      expect(PassActivityDate.parse('   '), isNull);
    });

    test('unrecognised text', () {
      expect(PassActivityDate.parse('not a date'), isNull);
      expect(PassActivityDate.parse('sometime soon'), isNull);
      expect(PassActivityDate.parse('10 Xyz 2024'), isNull);
    });

    test('out-of-range day does not roll over into the next month', () {
      // DateTime(2024, 1, 32) is silently 1 Feb 2024 — must be rejected.
      expect(PassActivityDate.parse('32 Jan 2024'), isNull);
      expect(PassActivityDate.parse('31 Feb 2024'), isNull);
    });

    test('ISO overflow dates do not roll over into the next month', () {
      // DateTime.parse('2024-02-31') is silently 2 Mar 2024, which would file
      // the pass under March.
      expect(PassActivityDate.parse('2024-02-31'), isNull);
      expect(PassActivityDate.parse('2023-02-29'), isNull);
      expect(PassActivityDate.parse('2024-13-01'), isNull);
      expect(PassActivityDate.parse('2024-02-31T10:00:00Z'), isNull);
    });

    test('a UTC offset may legitimately shift the day', () {
      // 01:00 +05:30 is the previous day in UTC. That is a real instant, not
      // an overflow, so it must survive the calendar check.
      expect(PassActivityDate.parse('2024-02-10T01:00:00+05:30'), isNotNull);
      expect(PassActivityDate.parse('2024-02-29'), isNotNull);
    });

    test('non-numeric day and malformed year', () {
      expect(PassActivityDate.parse('+5 Jan 2024'), isNull);
      expect(PassActivityDate.parse('10 Jan 20x4'), isNull);
      expect(PassActivityDate.parse('10 Jan 202'), isNull);
    });
  });

  group('PassActivityDate.of', () {
    test('train prefers departAt over the display date', () {
      final WalletPassItem item = TrainPassItem(
        train(departAt: '2024-06-01T09:00:00Z', date: '10 Jan 2024'),
      );
      expect(PassActivityDate.of(item)!.month, 6);
    });

    test('train falls back when departAt is present but malformed', () {
      final WalletPassItem item = TrainPassItem(
        train(departAt: 'garbage', date: '10 Jan 2024'),
      );
      expect(PassActivityDate.of(item), DateTime(2024, 1, 10));
    });

    test('movie prefers showAt, falls back to showDate', () {
      expect(
        PassActivityDate.of(
          MoviePassItem(movie(showAt: 'garbage', showDate: 'Mon, 10 Feb 2025')),
        ),
        DateTime(2025, 2, 10),
      );
      expect(
        PassActivityDate.of(
          MoviePassItem(
            movie(showAt: '2025-08-09T12:00:00Z', showDate: 'Mon, 10 Feb 2025'),
          ),
        )!.month,
        8,
      );
    });

    test('returns null when nothing parses', () {
      expect(
        PassActivityDate.of(MoviePassItem(movie(showDate: 'sometime soon'))),
        isNull,
      );
    });
  });

  group('PassActivityDate formatting', () {
    test('monthLabel is long month plus year', () {
      expect(PassActivityDate.monthLabel(DateTime(2025, 2, 1)), 'February 2025');
      expect(PassActivityDate.monthLabel(DateTime(2024, 12, 31)), 'December 2024');
    });

    test('shortDayLabel omits the year and does not zero-pad', () {
      expect(PassActivityDate.shortDayLabel(DateTime(2024, 9, 3)), '3 Sep');
      expect(PassActivityDate.shortDayLabel(DateTime(2025, 2, 10)), '10 Feb');
    });

    test('dayLabel carries the year', () {
      expect(PassActivityDate.dayLabel(DateTime(2024, 1, 10)), '10 Jan 2024');
    });
  });
}
