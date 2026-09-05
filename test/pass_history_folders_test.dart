import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/history_folder.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_activity_date.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_history_category.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal expired movie pass — only the fields these tests care about vary.
MoviePass expiredMovie({required String id, required String showDate}) {
  return MoviePass(
    id: id,
    brand: MoviePassBrand.universal,
    movieTitle: 'Test Screening',
    movieSubtitle: 'Drama',
    cinemaName: 'Test Cinema',
    cinemaAddress: 'Somewhere',
    screen: 'Screen 1',
    showDate: showDate,
    showTime: '7:00 PM',
    format: '2D',
    language: 'English',
    seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
    bookingId: 'TEST-$id',
    orderId: 'ORD-$id',
    status: TicketStatus.expired,
  );
}

void main() {
  group('buildHistoryFolders', () {
    test('groups only expired passes and omits empty categories', () {
      final List<WalletPassItem> all = buildWalletPassCatalog(
        trains: mockTrainPasses,
        movies: mockMoviePasses,
      );

      final List<HistoryFolderSummary> folders = buildHistoryFolders(all);

      expect(folders, isNotEmpty);
      expect(folders.every((HistoryFolderSummary f) => f.count > 0), isTrue);
      expect(
        folders.map((HistoryFolderSummary f) => f.category),
        isNot(contains(PassHistoryCategory.flight)),
      );

      final HistoryFolderSummary trains = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.train,
      );
      final HistoryFolderSummary movies = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.movie,
      );

      // Counted from the fixtures rather than pinned, so adding an archive
      // fixture does not break this — what matters is that the folder holds
      // every expired pass of its kind and nothing active.
      final int expiredTrains = mockTrainPasses
          .where((TrainPass t) => t.status == TicketStatus.expired)
          .length;
      final int expiredMoviesCount = mockMoviePasses
          .where((MoviePass m) => m.status == TicketStatus.expired)
          .length;

      expect(trains.count, expiredTrains);
      expect(movies.count, expiredMoviesCount);
      expect(trains.countLabel, '$expiredTrains passes');
      expect(movies.countLabel, '$expiredMoviesCount passes');
    });

    test('sorts folders trains then movies', () {
      final List<WalletPassItem> all = buildWalletPassCatalog(
        trains: mockTrainPasses,
        movies: mockMoviePasses,
      );
      final List<HistoryFolderSummary> folders = buildHistoryFolders(all);

      expect(folders.first.category, PassHistoryCategory.train);
      expect(folders[1].category, PassHistoryCategory.movie);
    });

    test('returns empty list when no expired passes', () {
      final List<WalletPassItem> activeOnly = buildWalletPassCatalog(
        trains: mockTrainPasses
            .where((TrainPass t) => t.status == TicketStatus.active)
            .toList(),
        movies: mockMoviePasses
            .where((MoviePass m) => m.status == TicketStatus.active)
            .toList(),
      );

      expect(buildHistoryFolders(activeOnly), isEmpty);
    });

    test('includes last-added label when activity date exists', () {
      final List<HistoryFolderSummary> folders = buildHistoryFolders(
        buildWalletPassCatalog(
          trains: mockTrainPasses,
          movies: mockMoviePasses,
        ),
      );
      final HistoryFolderSummary trains = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.train,
      );
      expect(trains.lastAddedLabel, isNotNull);
      expect(trains.lastAddedLabel, startsWith('Most recent '));
    });

    test('orders folder items newest first by resolved date', () {
      final List<HistoryFolderSummary> folders = buildHistoryFolders(
        buildWalletPassCatalog(
          trains: mockTrainPasses,
          movies: mockMoviePasses,
        ),
      );
      final HistoryFolderSummary trains = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.train,
      );
      final HistoryFolderSummary movies = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.movie,
      );

      // mock_t2 10 Jan 2024, mock_t5 14 Nov 2023, mock_t6 03 Sep 2023
      expect(trains.items.map((WalletPassItem i) => i.id), <String>[
        'mock_t2',
        'mock_t5',
        'mock_t6',
      ]);
      // Newest archived booking is Kalki (10 Feb 2025), oldest is Oppenheimer
      // (22 Jul 2023). Asserted as an ordering rather than a fixed list so
      // adding an archive fixture does not break this.
      expect(movies.items.first.id, 'movie_bms_2');
      expect(movies.items.last.id, 'movie_uni_3');
      final List<DateTime> dates = movies.items
          .map((WalletPassItem i) => PassActivityDate.of(i)!)
          .toList();
      for (int i = 1; i < dates.length; i++) {
        expect(
          dates[i].isAfter(dates[i - 1]),
          isFalse,
          reason: '${dates[i]} should not precede ${dates[i - 1]}',
        );
      }
    });

    // "Most recent", not "Last added": the sort key is the journey date, and no
    // pass model records when it was imported.
    test('activity label reports the newest pass, not the oldest', () {
      final List<HistoryFolderSummary> folders = buildHistoryFolders(
        buildWalletPassCatalog(
          trains: mockTrainPasses,
          movies: mockMoviePasses,
        ),
      );
      final HistoryFolderSummary trains = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.train,
      );
      expect(trains.lastAddedLabel, 'Most recent 10 Jan 2024');
    });
  });

  group('HistoryPassPresentation', () {
    test('train title uses destination city', () {
      final TrainPass ticket = mockTrainPasses.firstWhere(
        (TrainPass t) => t.status == TicketStatus.expired,
      );
      final String title = HistoryPassPresentation.title(TrainPassItem(ticket));
      expect(title, 'Train to ${ticket.toName}');
    });

    test('movie title is movieTitle', () {
      final MoviePass pass = mockMoviePasses.firstWhere(
        (MoviePass m) => m.status == TicketStatus.expired,
      );
      final String title = HistoryPassPresentation.title(MoviePassItem(pass));
      expect(title, pass.movieTitle);
    });

    test('train falls back when destination name empty', () {
      final TrainPass bare = TrainPass(
        id: 'bare',
        operator: 'IRCTC',
        trainNumber: '1',
        trainName: 'Express',
        fromCode: 'A',
        fromName: 'A',
        toCode: 'HYB',
        toName: '',
        departTime: '10:00',
        arriveTime: '12:00',
        date: '1 Jan 2024',
        arrivalDate: '1 Jan 2024',
        duration: '2h',
        ticketClass: 'SL',
        passengers: const <TicketPassenger>[
          TicketPassenger(name: 'Test', coach: 'S1', seat: '1', berth: 'Lower'),
        ],
        pnr: '0000000000',
        bookingId: 'E0',
        status: TicketStatus.expired,
      );
      expect(
        HistoryPassPresentation.title(TrainPassItem(bare)),
        'Train to HYB',
      );
    });
  });

  group('PassHistoryCategory', () {
    test('maps PassKind', () {
      expect(PassKind.train.historyCategory, PassHistoryCategory.train);
      expect(PassKind.movie.historyCategory, PassHistoryCategory.movie);
      expect(PassKind.bus.historyCategory, PassHistoryCategory.bus);
    });
  });
}
