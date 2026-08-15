import 'package:flutter_test/flutter_test.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_repository.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
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

  group('MoviePass poster resolution', () {
    MoviePass passWith({String? posterUrl, String? logoUrl}) => MoviePass(
      id: 'p',
      brand: MoviePassBrand.bookMyShow,
      movieTitle: 'Some Film Nobody Has Heard Of',
      movieSubtitle: '',
      cinemaName: 'C',
      cinemaAddress: 'A',
      screen: '1',
      showDate: 'd',
      showTime: 't',
      format: '2D',
      language: 'English',
      seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
      bookingId: 'b',
      orderId: 'o',
      status: TicketStatus.active,
      posterUrl: posterUrl,
      logoUrl: logoUrl,
    );

    // Regression: this used to fall through to a hardcoded Spider-Man poster, so every
    // unmatched film rendered the wrong art instead of the gradient fallback.
    test('returns null when the server sent no poster', () {
      expect(passWith().resolvedPosterUrl, isNull);
    });

    test('treats an empty or blank posterUrl as no poster', () {
      expect(passWith(posterUrl: '').resolvedPosterUrl, isNull);
      expect(passWith(posterUrl: '   ').resolvedPosterUrl, isNull);
    });

    test('trims surrounding whitespace', () {
      expect(
        passWith(
          posterUrl: '  https://api.docket.app/img/poster/w500/a.jpg  ',
        ).resolvedPosterUrl,
        'https://api.docket.app/img/poster/w500/a.jpg',
      );
    });

    test('survives a JSON round trip', () {
      const String url =
          'https://api.docket.app/img/poster/w500/abc123abc123abc123abc12.jpg';
      final MoviePass again = MoviePass.fromJson(
        passWith(posterUrl: url).toJson(),
      );
      expect(again.resolvedPosterUrl, url);
    });

    // Design probe: fixtures hit TMDB CDN directly (no proxy / MOCK_POSTER_ORIGIN).
    test('fixtures use absolute TMDB CDN poster URLs', () {
      for (final MoviePass m in mockMoviePasses) {
        final String? url = m.resolvedPosterUrl;
        expect(url, isNotNull, reason: '${m.movieTitle} missing poster');
        expect(
          url,
          startsWith('https://image.tmdb.org/t/p/'),
          reason: '${m.movieTitle} is not a TMDB CDN poster URL',
        );
      }
    });

    // The static poster JPEGs were removed with the TMDB switch.
    test('no fixture references a bundled poster asset', () {
      for (final MoviePass m in mockMoviePasses) {
        expect(
          m.posterAsset,
          isNull,
          reason: '${m.movieTitle} still pins a local asset',
        );
      }
    });

    test('treats blank logoUrl as no logo', () {
      expect(passWith(logoUrl: '').resolvedLogoUrl, isNull);
      expect(passWith(logoUrl: '  ').resolvedLogoUrl, isNull);
    });

    test('logoUrl survives a JSON round trip', () {
      const String logo =
          'https://api.docket.app/img/poster/w500/eYvF1LhPKuoBxOAmWjFTAK7EPWl.png';
      final MoviePass again = MoviePass.fromJson(
        passWith(logoUrl: logo).toJson(),
      );
      expect(again.resolvedLogoUrl, logo);
    });

    // The logo exists so the glance card has legible art, and only an active
    // pass renders a glance card. Archived fixtures carry a poster and no
    // logo on purpose — the detail face they open into uses the poster.
    test('active fixtures use absolute TMDB CDN logo PNGs', () {
      final Iterable<MoviePass> active = mockMoviePasses.where(
        (MoviePass m) => m.status == TicketStatus.active,
      );
      expect(active, isNotEmpty);

      for (final MoviePass m in active) {
        final String? url = m.resolvedLogoUrl;
        expect(url, isNotNull, reason: '${m.movieTitle} missing logo');
        expect(
          url,
          startsWith('https://image.tmdb.org/t/p/'),
          reason: '${m.movieTitle} is not a TMDB CDN logo URL',
        );
        expect(
          url,
          endsWith('.png'),
          reason: '${m.movieTitle} logo should be PNG',
        );
      }
    });

    // Whatever the archive does about logos, every fixture needs a poster:
    // it is the only art the archive grid and the detail face have.
    test('every fixture carries an absolute TMDB CDN poster', () {
      for (final MoviePass m in mockMoviePasses) {
        final String? url = m.resolvedPosterUrl;
        expect(url, isNotNull, reason: '${m.movieTitle} missing poster');
        expect(
          url,
          startsWith('https://image.tmdb.org/t/p/'),
          reason: '${m.movieTitle} is not a TMDB CDN poster URL',
        );
        expect(
          url,
          endsWith('.jpg'),
          reason: '${m.movieTitle} poster should be JPG',
        );
      }
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

    test('parses a bus envelope', () {
      final PassListResponse res = PassListResponse.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'bus',
            'bus': <String, dynamic>{
              'id': 'bus-1',
              'operator': 'Orange Travels',
              'boardingLocation': 'Hyderabad',
              'dropLocation': 'Bengaluru',
              'departTime': '09:00 PM',
              'arriveTime': '06:00 AM',
              'date': '14 Aug 2026',
              'arrivalDate': '15 Aug 2026',
              'status': 'active',
              'seatDetails': 'L12',
            },
          },
        ],
      });
      expect(res.items, hasLength(1));
      expect(res.items.single, isA<BusPassItem>());
      final BusPass pass = (res.items.single as BusPassItem).pass;
      expect(pass.operator, 'Orange Travels');
      expect(pass.status, TicketStatus.active);
      expect(pass.routeLabel, 'Hyderabad → Bengaluru');
    });

    test('round-trips catalog envelope', () {
      final List<WalletPassItem> catalog = buildWalletPassCatalog(
        trains: mockTrainPasses,
        movies: mockMoviePasses,
      );
      final PassListResponse original = PassListResponse(items: catalog);
      final PassListResponse again = PassListResponse.fromJson(
        original.toJson(),
      );
      expect(again.items.length, original.items.length);
      expect(
        again.items.map((WalletPassItem e) => e.id).toList(),
        original.items.map((WalletPassItem e) => e.id).toList(),
      );
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

      final List<WalletPassItem> active = await repo.fetchPasses(
        status: TicketStatus.active,
      );
      expect(
        active.every((WalletPassItem p) => p.status == TicketStatus.active),
        isTrue,
      );
    });

    test('fetchPassById', () async {
      final MockPassRepository repo = MockPassRepository(
        artificialDelay: Duration.zero,
      );
      final WalletPassItem? found = await repo.fetchPassById(
        mockTrainPasses.first.id,
      );
      expect(found, isNotNull);
      expect(found!.id, mockTrainPasses.first.id);
      expect(await repo.fetchPassById('missing'), isNull);
    });
  });
}
