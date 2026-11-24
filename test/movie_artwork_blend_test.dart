import 'package:cached_network_image/cached_network_image.dart';
import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/dashboard/application/pass_deck_provider.dart';
import 'package:docket/features/tickets/application/movie_artwork_blend_provider.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/presentation/movie/movie_artwork_backdrop.dart';
import 'package:docket/features/tickets/presentation/movie/movie_brand_style.dart';
import 'package:docket/features/tickets/presentation/movie/movie_blended_poster.dart';
import 'package:docket/features/tickets/presentation/movie/movie_blurred_artwork.dart';
import 'package:docket/features/tickets/presentation/movie/movie_feathered_image.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'package:docket/features/tickets/presentation/movie_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/pass_code_view.dart';
import 'package:docket/features/tickets/presentation/wallet_movie_card.dart';
import 'package:docket/features/tickets/presentation/tickets_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

MoviePass _pass({
  MoviePassBrand brand = MoviePassBrand.bookMyShow,
  String? poster,
  String? logo,
  String? posterAsset,
  String? logoAsset,
  String title = 'Test Film',
  String? codePayload,
}) => MoviePass.fromJson(<String, dynamic>{
  'logoAsset': logoAsset,
  'id': 'blend-test',
  'brand': brand.name,
  'movieTitle': title,
  'cinemaName': 'PVR INOX Phoenix Mall',
  'screen': 'Screen 5',
  'showDate': 'Sat, 12 Apr 2025',
  'showTime': '7:15 PM',
  'status': 'active',
  'posterUrl': poster,
  'logoUrl': logo,
  'posterAsset': posterAsset,
  'codePayload': codePayload,
  'seats': <Map<String, String>>[
    <String, String>{'row': 'H', 'number': '12'},
    <String, String>{'row': 'H', 'number': '13'},
  ],
});

Future<void> _pumpFace(
  WidgetTester tester,
  MoviePass pass, {
  bool blend = false,
  MovieTicketDensity density = MovieTicketDensity.glance,
  double width = 382,
  VoidCallback? onOpenCodes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: MovieTicketFace(
              pass: pass,
              density: density,
              artworkBlend: blend,
              onOpenCodes: onOpenCodes,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('starts off, persists opt-in and restores the choice', () async {
    final first = MovieArtworkBlendNotifier();
    expect(first.state, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(first.state, isFalse);
    await first.setEnabled(true);
    first.dispose();

    final restored = MovieArtworkBlendNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(restored.state, isTrue);
    await restored.setEnabled(false);
    restored.dispose();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(movieArtworkBlendPreferenceKey), isFalse);
  });

  test('an immediate choice wins over hydration and ordered writes', () async {
    final notifier = MovieArtworkBlendNotifier();
    final writes = <Future<void>>[
      notifier.setEnabled(true),
      notifier.setEnabled(false),
      notifier.setEnabled(true),
    ];
    expect(notifier.state, isTrue);
    await Future.wait(writes);
    expect(notifier.state, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(movieArtworkBlendPreferenceKey), isTrue);
    notifier.dispose();
  });

  testWidgets(
    'both faces stay classic by default and blend only when enabled',
    (tester) async {
      await _pumpFace(tester, _pass());
      expect(find.byType(MovieArtworkBackdrop), findsNothing);
      await _pumpFace(tester, _pass(), blend: true);
      expect(find.byType(MovieArtworkBackdrop), findsOneWidget);
      expect(find.text('7:15 PM'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      await _pumpFace(tester, _pass(), density: MovieTicketDensity.detail);
      expect(find.byType(MovieArtworkBackdrop), findsNothing);
      await _pumpFace(
        tester,
        _pass(),
        blend: true,
        density: MovieTicketDensity.detail,
      );
      expect(find.byType(MovieArtworkBackdrop), findsOneWidget);
      expect(find.byType(MovieBlendedPoster), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brand in <MoviePassBrand>[
    MoviePassBrand.bookMyShow,
    MoviePassBrand.district,
  ]) {
    for (final density in MovieTicketDensity.values) {
      testWidgets(
        '${brand.name} ${density.name} keeps its original SVG, size and footer alignment',
        (tester) async {
          final pass = _pass(brand: brand);
          await _pumpFace(tester, pass, density: density);
          final oldLogo = tester.widget<SvgPicture>(find.byType(SvgPicture));
          final oldRect = tester.getRect(find.byType(SvgPicture));
          final oldFace = tester.getRect(find.byType(MovieTicketFace));
          await _pumpFace(tester, pass, blend: true, density: density);
          final newLogo = tester.widget<SvgPicture>(find.byType(SvgPicture));
          final style = MovieBrandStyle.forPass(pass);
          expect(
            newLogo.bytesLoader,
            isA<SvgAssetLoader>().having(
              (loader) => loader.assetName,
              'original SVG asset',
              style.footerLogoAsset ?? style.logoAsset,
            ),
          );
          expect(newLogo.height, oldLogo.height);
          expect(newLogo.colorFilter, oldLogo.colorFilter);
          expect(newLogo.fit, oldLogo.fit);
          expect(newLogo.alignment, oldLogo.alignment);
          final newRect = tester.getRect(find.byType(SvgPicture));
          final newFace = tester.getRect(find.byType(MovieTicketFace));
          expect(newRect.size, oldRect.size);
          expect(newRect.center.dx, oldRect.center.dx);
          expect(
            newFace.bottom - newRect.bottom,
            closeTo(oldFace.bottom - oldRect.bottom, 0.001),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final width in <double>[280, 382, 460]) {
    testWidgets('the blended expanded poster remains a full 2:3 at $width', (
      tester,
    ) async {
      await _pumpFace(
        tester,
        _pass(),
        width: width,
        blend: true,
        density: MovieTicketDensity.detail,
      );
      final hero = tester.getRect(find.byKey(MovieTicketFace.heroKey));
      expect(hero.width / hero.height, closeTo(2 / 3, 0.001));
      expect(hero.width, closeTo(width - 28, 0.001));
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'expanded artwork uses the poster, not its transparent title logo',
    (tester) async {
      const poster = 'https://example.invalid/movie-poster.jpg';
      await _pumpFace(
        tester,
        _pass(poster: poster, logo: 'https://example.invalid/movie-logo.png'),
        blend: true,
        density: MovieTicketDensity.detail,
      );
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .where(
            (image) =>
                image.image is MovieFeatheredImage &&
                (image.image as MovieFeatheredImage).source != null,
          );
      expect(images, hasLength(1));
      expect(find.byType(MovieBlurredArtwork), findsNWidgets(2));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      final sharp = images.single.image as MovieFeatheredImage;
      expect(sharp.width, lessThanOrEqualTo(780));
      expect(
        ((sharp.source as ResizeImage).imageProvider
                as CachedNetworkImageProvider)
            .url,
        poster,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a bundled title treatment takes priority over its network logo',
    (tester) async {
      const asset = 'assets/passes/fixtures/dune_part_three_logo.png';
      await _pumpFace(
        tester,
        _pass(logoAsset: asset, logo: 'https://example.invalid/old-film.png'),
        blend: true,
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
      final titles = tester
          .widgetList<Image>(find.byType(Image))
          .where(
            (image) =>
                image.image is ResizeImage &&
                (image.image as ResizeImage).imageProvider is AssetImage &&
                ((image.image as ResizeImage).imageProvider as AssetImage)
                        .assetName ==
                    asset,
          );
      expect(titles, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'idle warm-up reuses the exact expanded sharp and halo cache keys',
    (tester) async {
      final pass = _pass(posterAsset: 'assets/archive/covers/movies.jpg');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.runAsync(() => MovieBlendedPoster.warmUp(pass, context));
      await tester.pump();
      await _pumpFace(
        tester,
        pass,
        width: 358,
        blend: true,
        density: MovieTicketDensity.detail,
      );
      // 390 - 32 list padding - 28 hero padding = 330, exactly as in detail.
      final poster = find.byType(MovieBlendedPoster);
      final images = tester.widgetList<Image>(
        find.descendant(of: poster, matching: find.byType(Image)),
      );
      // Only the halo and sharp image stay mounted. Keeping a second masked
      // gradient underneath the loaded poster doubles edge alpha into a rim.
      expect(images, hasLength(2));
      for (final image in images) {
        final key = await image.image.obtainKey(ImageConfiguration.empty);
        expect(
          PaintingBinding.instance.imageCache.statusForKey(key).keepAlive,
          isTrue,
          reason: 'The expanded layer must reuse the image prepared at idle',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded preference changes live without altering the entry code',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final pass = _pass(codePayload: 'entry-code-test');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: MoviePassDetailScreen(pass: pass)),
        ),
      );
      await tester.pump();
      expect(find.byType(MovieBlendedPoster), findsNothing);
      await container.read(movieArtworkBlendProvider.notifier).setEnabled(true);
      await tester.pump();
      expect(find.byType(MovieBlendedPoster), findsOneWidget);
      expect(
        tester.widget<PassCodeView>(find.byType(PassCodeView)).code.text,
        pass.passCode!.text,
      );
      await container
          .read(movieArtworkBlendProvider.notifier)
          .setEnabled(false);
      await tester.pump();
      expect(find.byType(MovieBlendedPoster), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the blended face opens real codes and omits absent codes', (
    tester,
  ) async {
    var opened = false;
    await _pumpFace(
      tester,
      _pass(codePayload: 'entry-code-test'),
      blend: true,
      density: MovieTicketDensity.detail,
      onOpenCodes: () => opened = true,
    );
    await tester.ensureVisible(find.byType(PassCodeView));
    await tester.tap(find.byType(PassCodeView));
    expect(opened, isTrue);
    await _pumpFace(
      tester,
      _pass(),
      blend: true,
      density: MovieTicketDensity.detail,
    );
    expect(find.byType(PassCodeView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('poster atmosphere and a sharp contained logo load separately', (
    tester,
  ) async {
    const poster = 'https://example.invalid/movie-poster.jpg';
    const logo = 'https://example.invalid/movie-logo.png';
    await _pumpFace(tester, _pass(poster: poster, logo: logo), blend: true);
    final images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .toList();
    final background = tester.widget<MovieBlurredArtwork>(
      find.byType(MovieBlurredArtwork),
    );
    final foreground = images.singleWhere((image) => image.imageUrl == logo);
    expect(background.fit, BoxFit.cover);
    expect(background.pass.resolvedPosterUrl, poster);
    final prepared =
        tester
                .widget<Image>(
                  find.descendant(
                    of: find.byType(MovieBlurredArtwork),
                    matching: find.byType(Image),
                  ),
                )
                .image
            as MovieBlurredImage;
    expect(prepared.width, lessThanOrEqualTo(128));
    expect(prepared.height, lessThanOrEqualTo(256));
    expect((prepared.source as ResizeImage).width, 360);
    expect(foreground.fit, BoxFit.contain);
    expect(
      find.ancestor(
        of: find.byWidget(foreground),
        matching: find.byType(ImageFiltered),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final deck in [false, true]) {
    testWidgets(
      'the preference updates live in ${deck ? 'deck' : 'roll'} mode',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            activePassesProvider.overrideWith(
              (ref) => AsyncData(<WalletPassItem>[
                MoviePassItem.fromJson(_pass().toJson()),
              ]),
            ),
            devFlagsProvider.overrideWith(
              (ref) => DevFlagsNotifier.fixed(
                const DevFlags(useMockPasses: true, apiBaseUrl: ''),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        if (deck) await container.read(passDeckModeProvider.notifier).toggle();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: TicketsTab(isActive: true)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(WalletMovieCard), findsOneWidget);
        expect(find.byType(MovieArtworkBackdrop), findsNothing);
        await container
            .read(movieArtworkBlendProvider.notifier)
            .setEnabled(true);
        await tester.pump();
        expect(find.byType(MovieArtworkBackdrop), findsOneWidget);
        await container
            .read(movieArtworkBlendProvider.notifier)
            .setEnabled(false);
        await tester.pump();
        expect(find.byType(MovieArtworkBackdrop), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final density in MovieTicketDensity.values) {
    testWidgets(
      'a ${density.name} poster asset takes priority over a network poster',
      (tester) async {
        await _pumpFace(
          tester,
          _pass(
            posterAsset: 'assets/passes/history_clock.svg',
            poster: 'https://example.invalid/movie-poster.jpg',
          ),
          blend: true,
          density: density,
        );
        expect(find.byType(CachedNetworkImage), findsNothing);
      },
    );
  }

  for (final size in <Size>[const Size(320, 568), const Size(851, 393)]) {
    testWidgets('a long movie title fits the wallet at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: WalletMovieCard(
                  pass: _pass(
                    title: 'An Extremely Long Movie Title: The Final Chapter',
                  ),
                  artworkBlend: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final face = tester.getRect(find.byType(MovieTicketFace));
      final footer = tester.getRect(find.byType(SvgPicture));
      expect(footer.bottom, lessThanOrEqualTo(face.bottom + 0.1));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(WalletCardCanvas)).height,
        lessThanOrEqualTo(size.height),
      );
    });
  }
}
