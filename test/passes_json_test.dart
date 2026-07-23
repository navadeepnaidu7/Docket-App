import 'package:flutter_test/flutter_test.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_repository.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';

void main() {
  group('TrainPass JSON', () {
    test('round-trips fixtures', () {
      for (final TrainPass t in mockTrainPasses) {
        final TrainPass again = TrainPass.fromJson(t.toJson());
        expect(again.id, t.id);
        expect(again.pnr, t.pnr);
        expect(again.passengers.length, t.passengers.length);
        expect(again.status, t.status);
      }
    });
  });

  group('MoviePass JSON', () {
    test('round-trips fixtures', () {
      for (final MoviePass m in mockMoviePasses) {
        final MoviePass again = MoviePass.fromJson(m.toJson());
        expect(again.id, m.id);
        expect(again.brand, m.brand);
        expect(again.seats.length, m.seats.length);
        expect(again.codeType, m.codeType);
      }
    });

    test('unknown brand maps to universal', () {
      final MoviePass m = MoviePass.fromJson(<String, dynamic>{
        'id': 'x',
        'brand': 'SomeNewAggregator',
        'movieTitle': 'Test',
        'movieSubtitle': '',
        'cinemaName': 'C',
        'cinemaAddress': 'A',
        'screen': '1',
        'showDate': 'd',
        'showTime': 't',
        'format': '2D',
        'language': 'en',
        'seats': <Map<String, String>>[
          <String, String>{'row': 'A', 'number': '1'},
        ],
        'bookingId': 'b',
        'orderId': 'o',
        'status': 'active',
      });
      expect(m.brand, MoviePassBrand.universal);
    });
  });

  group('Pass list envelope', () {
    test('parses mixed kinds', () {
      final PassListResponse res = PassListResponse.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'movie',
            'movie': mockMoviePasses.first.toJson(),
          },
          <String, dynamic>{
            'kind': 'train',
            'train': mockTrainPasses.first.toJson(),
          },
        ],
        'updatedAt': '2025-01-01T00:00:00Z',
      });
      expect(res.items.length, 2);
      expect(res.items[0], isA<MoviePassItem>());
      expect(res.items[1], isA<TrainPassItem>());
      expect(res.updatedAt, isNotNull);
    });

    test('round-trips catalog envelope', () {
      final List<WalletPassItem> catalog = buildWalletPassCatalog(
        trains: mockTrainPasses,
        movies: mockMoviePasses,
      );
      final PassListResponse original = PassListResponse(items: catalog);
      final PassListResponse again =
          PassListResponse.fromJson(original.toJson());
      expect(again.items.length, original.items.length);
      expect(again.items.map((WalletPassItem e) => e.id).toList(),
          original.items.map((WalletPassItem e) => e.id).toList());
    });
  });

  group('MockPassRepository', () {
    test('returns catalog with active and expired', () async {
      final MockPassRepository repo = MockPassRepository(
        artificialDelay: Duration.zero,
      );
      final List<WalletPassItem> all = await repo.fetchPasses();
      expect(all, isNotEmpty);
      expect(
        all.any((WalletPassItem p) => p.status == TicketStatus.active),
        isTrue,
      );
      expect(
        all.any((WalletPassItem p) => p.status == TicketStatus.expired),
        isTrue,
      );

      final List<WalletPassItem> active =
          await repo.fetchPasses(status: TicketStatus.active);
      expect(
        active.every((WalletPassItem p) => p.status == TicketStatus.active),
        isTrue,
      );
    });

    test('fetchPassById', () async {
      final MockPassRepository repo = MockPassRepository(
        artificialDelay: Duration.zero,
      );
      final WalletPassItem? found =
          await repo.fetchPassById(mockTrainPasses.first.id);
      expect(found, isNotNull);
      expect(found!.id, mockTrainPasses.first.id);
      expect(await repo.fetchPassById('missing'), isNull);
    });
  });
}
