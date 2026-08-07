import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/history_folder.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_history_category.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';

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
