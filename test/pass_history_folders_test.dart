import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/history_folder.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
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
      expect(
        folders.every((HistoryFolderSummary f) => f.count > 0),
        isTrue,
      );
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

      expect(trains.count, 3);
      expect(movies.count, 2);
      expect(trains.countLabel, '3 passes');
      expect(movies.countLabel, '2 passes');
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
      expect(trains.lastAddedLabel, startsWith('Last added '));
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
      expect(
        trains.items.map((WalletPassItem i) => i.id),
        <String>['mock_t2', 'mock_t5', 'mock_t6'],
      );
      // movie_bms_2 10 Feb 2025, movie_dist_2 14 Dec 2024
      expect(
        movies.items.map((WalletPassItem i) => i.id),
        <String>['movie_bms_2', 'movie_dist_2'],
      );
    });

    test('last-added label reports the newest pass, not the oldest', () {
      final List<HistoryFolderSummary> folders = buildHistoryFolders(
        buildWalletPassCatalog(
          trains: mockTrainPasses,
          movies: mockMoviePasses,
        ),
      );
      final HistoryFolderSummary trains = folders.firstWhere(
        (HistoryFolderSummary f) => f.category == PassHistoryCategory.train,
      );
      expect(trains.lastAddedLabel, 'Last added 10 Jan 2024');
    });
  });

  group('buildHistoryMonthSections', () {
    List<WalletPassItem> expiredMovies() => mockMoviePasses
        .where((MoviePass m) => m.status == TicketStatus.expired)
        .map(MoviePassItem.new)
        .toList();

    test('returns empty list for empty input', () {
      expect(buildHistoryMonthSections(const <WalletPassItem>[]), isEmpty);
    });

    test('buckets by month, newest section first', () {
      final List<HistoryMonthSection> sections =
          buildHistoryMonthSections(expiredMovies());

      expect(
        sections.map((HistoryMonthSection s) => s.label),
        <String>['February 2025', 'December 2024'],
      );
      expect(sections.first.items.single.id, 'movie_bms_2');
      expect(sections.last.items.single.id, 'movie_dist_2');
    });

    test('two passes in the same month share one section', () {
      final MoviePass first = mockMoviePasses
          .firstWhere((MoviePass m) => m.id == 'movie_bms_2');

      final List<HistoryMonthSection> sections = buildHistoryMonthSections(
        <WalletPassItem>[
          MoviePassItem(first),
          MoviePassItem(
            expiredMovie(id: 'same_month', showDate: 'Fri, 21 Feb 2025'),
          ),
        ],
      );

      expect(sections, hasLength(1));
      expect(sections.single.label, 'February 2025');
      // 21 Feb is newer than 10 Feb.
      expect(
        sections.single.items.map((WalletPassItem i) => i.id),
        <String>['same_month', 'movie_bms_2'],
      );
    });

    test('undated passes land in a trailing section and are never dropped', () {
      final List<HistoryMonthSection> sections = buildHistoryMonthSections(
        <WalletPassItem>[
          MoviePassItem(
            expiredMovie(id: 'no_date', showDate: 'sometime soon'),
          ),
          ...expiredMovies(),
        ],
      );

      expect(sections.last.label, kUndatedSectionLabel);
      expect(sections.last.isUndated, isTrue);
      expect(sections.last.items.single.id, 'no_date');
      expect(
        sections.fold<int>(
          0,
          (int sum, HistoryMonthSection s) => sum + s.items.length,
        ),
        3,
      );
    });
  });

  group('HistoryPassPresentation', () {
    test('train title uses destination city', () {
      final TrainPass ticket = mockTrainPasses.firstWhere(
        (TrainPass t) => t.status == TicketStatus.expired,
      );
      final String title =
          HistoryPassPresentation.title(TrainPassItem(ticket));
      expect(title, 'Train to ${ticket.toName}');
    });

    test('movie title is movieTitle', () {
      final MoviePass pass = mockMoviePasses.firstWhere(
        (MoviePass m) => m.status == TicketStatus.expired,
      );
      final String title =
          HistoryPassPresentation.title(MoviePassItem(pass));
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
          TicketPassenger(
            name: 'Test',
            coach: 'S1',
            seat: '1',
            berth: 'Lower',
          ),
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
    });
  });
}
