// flutter test --no-pub tool/movie_artwork_preview_test.dart --update-goldens
// Uses the conversation's downloaded fixture artwork, without network or phone.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/presentation/wallet_movie_card.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _seed(String url, String file, int width) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  final provider = ResizeImage(CachedNetworkImageProvider(url), width: width);
  final key = await provider.obtainKey(ImageConfiguration.empty);
  PaintingBinding.instance.imageCache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(
      Future<ImageInfo>.value(ImageInfo(image: frame.image)),
    ),
  );
}

void main() {
  testWidgets('render the approved blend with the original partner logos', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 720);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      for (final weight in [
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w800,
      ]) {
        GoogleFonts.inter(fontWeight: weight);
      }
      await GoogleFonts.pendingFonts();
      for (var i = 0; i < 2; i++) {
        final pass = mockMoviePasses[i];
        final film = i == 0 ? 'dune' : 'odyssey';
        await _seed(
          pass.resolvedPosterUrl!,
          'outputs/pass-blend-preview/$film-poster.jpg',
          360,
        );
        for (final width in [354, 426]) {
          await _seed(
            pass.resolvedPosterUrl!,
            'outputs/pass-blend-preview/$film-poster.jpg',
            width,
          );
        }
        await _seed(
          pass.resolvedLogoUrl!,
          'outputs/pass-blend-preview/$film-logo.png',
          387,
        );
      }
    });
    for (var i = 0; i < 2; i++) {
      for (final blend in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 382,
                  height: 620,
                  child: WalletMovieCard(
                    pass: mockMoviePasses[i],
                    artworkBlend: blend,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../build/movie-artwork-preview/${i == 0 ? 'dune' : 'odyssey'}_${blend ? 'blend' : 'classic'}.png',
          ),
        );
      }
    }
    tester.view.physicalSize = const Size(430, 1400);
    for (var i = 0; i < 2; i++) {
      for (final blend in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: MovieTicketFace(
                  pass: mockMoviePasses[i],
                  density: MovieTicketDensity.detail,
                  useBrandColors: true,
                  artworkBlend: blend,
                  onOpenCodes: () {},
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../build/movie-artwork-preview/${i == 0 ? 'dune' : 'odyssey'}_detail_${blend ? 'blend' : 'classic'}.png',
          ),
        );
      }
    }
  });
}
