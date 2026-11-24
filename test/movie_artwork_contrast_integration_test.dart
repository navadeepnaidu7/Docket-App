import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _preview = bool.fromEnvironment('MOVIE_CONTRAST_PREVIEW');
const _previewDirectory = String.fromEnvironment(
  'MOVIE_CONTRAST_PREVIEW_DIR',
  defaultValue: 'build/movie-contrast-preview',
);
const _captureKey = ValueKey('contrast-face-capture');
const _whitePoster = 'contrast-fixtures/white-poster.png';
const _darkPoster = 'contrast-fixtures/dark-poster.png';
const _busyPoster = 'contrast-fixtures/busy-poster.png';
const _whiteLogo = 'contrast-fixtures/white-logo.png';
const _blackLogo = 'contrast-fixtures/black-logo.png';
const _colorLogo = 'contrast-fixtures/color-logo.png';
const _mixedLogo = 'contrast-fixtures/mixed-logo.png';
const _emptyLogo = 'contrast-fixtures/empty-logo.png';
const _failedLogo = 'contrast-fixtures/broken-logo.png';
const _slowLogo = 'contrast-fixtures/slow-logo.png';
const _disposedLogo = 'contrast-fixtures/disposed-logo.png';

MoviePass _pass(String id, {String? poster, String? logo, String? passId}) =>
    MoviePass(
      id: passId ?? id,
      brand: MoviePassBrand.bookMyShow,
      movieTitle: id,
      movieSubtitle: 'Mock contrast verification',
      cinemaName: 'Fixture Cinema',
      cinemaAddress: 'Fixture Address',
      screen: 'Screen 1',
      showDate: 'Fri, 18 Dec 2026',
      showTime: '7:15 PM',
      format: '2D',
      language: 'English',
      seats: const [MovieSeat(row: 'A', number: '1')],
      bookingId: 'MOCK',
      orderId: 'MOCK',
      status: TicketStatus.active,
      posterHint: MoviePosterHint.sciFi,
      posterAsset: poster,
      logoAsset: logo,
    );

Future<ByteData> _png(
  int width,
  int height,
  void Function(Canvas canvas, Size size) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!;
  } finally {
    image.dispose();
  }
}

Future<ByteData> _logo(List<Color> colors) => _png(300, 120, (canvas, size) {
  final text = TextPainter(
    text: TextSpan(
      children: [
        for (var i = 0; i < 5; i++)
          TextSpan(
            text: 'LUMEN'[i],
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: colors[i % colors.length],
            ),
          ),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(
    canvas,
    Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
  );
});

Future<Map<String, ByteData>> _fixtureAssets() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  AppTheme.lightTheme;
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.inter(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
  final manifest = await rootBundle.load('AssetManifest.bin');
  final white = await _png(200, 300, (canvas, size) {
    canvas.drawColor(const Color(0xFFFFFDF8), BlendMode.src);
    canvas.drawCircle(
      const Offset(105, 150),
      60,
      Paint()..color = const Color(0xFFE8E0D1),
    );
  });
  final dark = await _png(200, 300, (canvas, size) {
    canvas.drawColor(const Color(0xFF05060B), BlendMode.src);
    canvas.drawCircle(
      const Offset(105, 150),
      60,
      Paint()..color = const Color(0xFF112838),
    );
  });
  final busy = await _png(200, 300, (canvas, size) {
    const colors = [Colors.white, Colors.black, Colors.red, Colors.blue];
    for (var y = 0; y < 300; y += 20) {
      for (var x = 0; x < 200; x += 20) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 20, 20),
          Paint()..color = colors[(x ~/ 20 + y ~/ 20) % colors.length],
        );
      }
    }
  });
  return {
    'AssetManifest.bin': manifest,
    _whitePoster: white,
    _darkPoster: dark,
    _busyPoster: busy,
    _whiteLogo: await _logo([Colors.white]),
    _blackLogo: await _logo([Colors.black]),
    _colorLogo: await _logo([Colors.yellow, Colors.green, Colors.red]),
    _mixedLogo: await _logo([Colors.white, Colors.black]),
    _emptyLogo: await _png(300, 120, (canvas, size) {}),
    _failedLogo: ByteData.sublistView(Uint8List.fromList([1, 2, 3, 4])),
  };
}

Future<void> _pumpFace(WidgetTester tester, MoviePass pass) =>
    tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: RepaintBoundary(
                key: _captureKey,
                child: SizedBox(
                  width: 382,
                  child: MovieTicketFace(
                    pass: pass,
                    density: MovieTicketDensity.glance,
                    artworkBlend: true,
                    widthFactor: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _finishArtwork(WidgetTester tester) async {
  // Decode/render work runs outside FakeAsync; settling shimmer timers is unsafe.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _heroTitle(String title) => find.descendant(
  of: find.byKey(MovieTicketFace.heroKey),
  matching: find.text(title),
);

String? _assetName(ImageProvider provider) => switch (provider) {
  AssetImage() => provider.assetName,
  ResizeImage() => _assetName(provider.imageProvider),
  _ => null,
};

Future<void> _expectVisibleLogoContrast(
  WidgetTester tester,
  String asset,
  ByteData png,
) async {
  final logo = find.descendant(
    of: find.byKey(MovieTicketFace.heroKey),
    matching: find.byWidgetPredicate(
      (widget) => widget is Image && _assetName(widget.image) == asset,
    ),
  );
  expect(
    logo,
    findsOneWidget,
    reason: 'A usable logo should retain its original art',
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final paintedImage = find.descendant(
    of: logo,
    matching: find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.fit == BoxFit.contain,
    ),
  );
  expect(paintedImage, findsOneWidget);
  final imageRect = tester
      .getRect(paintedImage)
      .shift(-tester.getTopLeft(find.byKey(_captureKey)));
  final result = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(Uint8List.sublistView(png));
    final frame = await codec.getNextFrame();
    codec.dispose();
    final rendered = await boundary.toImage(pixelRatio: 1);
    try {
      final mask = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final pixels = (await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final sourceSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      final destination = Alignment.center.inscribe(
        applyBoxFit(BoxFit.contain, sourceSize, imageRect.size).destination,
        imageRect,
      );
      int alpha(int x, int y) =>
          mask.getUint8((y * frame.image.width + x) * 4 + 3);
      Color pixelAt(int sourceX, int sourceY) {
        final x =
            (destination.left +
                    (sourceX + .5) * destination.width / sourceSize.width)
                .floor()
                .clamp(0, rendered.width - 1);
        final y =
            (destination.top +
                    (sourceY + .5) * destination.height / sourceSize.height)
                .floor()
                .clamp(0, rendered.height - 1);
        final index = (y * rendered.width + x) * 4;
        return Color.fromARGB(
          255,
          pixels.getUint8(index),
          pixels.getUint8(index + 1),
          pixels.getUint8(index + 2),
        );
      }

      var samples = 0;
      var readable = 0;
      for (var y = 2; y < frame.image.height - 2; y += 3) {
        for (var x = 2; x < frame.image.width - 2; x += 3) {
          if (alpha(x, y) < 250 ||
              alpha(x - 1, y) < 250 ||
              alpha(x + 1, y) < 250 ||
              alpha(x, y - 1) < 250 ||
              alpha(x, y + 1) < 250) {
            continue;
          }
          int? nearby;
          for (final delta in [-6, 6, -12, 12, -18, 18, -24, 24]) {
            final other = x + delta;
            if (other >= 0 &&
                other < frame.image.width &&
                alpha(other, y) < 5) {
              nearby = other;
              break;
            }
          }
          if (nearby == null) continue;
          final foreground = pixelAt(x, y).computeLuminance();
          final background = pixelAt(nearby, y).computeLuminance();
          final ratio = foreground > background
              ? (foreground + .05) / (background + .05)
              : (background + .05) / (foreground + .05);
          samples++;
          if (ratio >= 3) readable++;
        }
      }
      return (samples, readable / samples);
    } finally {
      frame.image.dispose();
      rendered.dispose();
    }
  });
  expect(result, isNotNull);
  expect(result!.$1, greaterThan(30));
  expect(
    result.$2,
    greaterThanOrEqualTo(.9),
    reason:
        'The actual rendered logo strokes must contrast with nearby background pixels',
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_preview) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final output = File('$_previewDirectory/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(Uint8List.sublistView(bytes));
    } finally {
      image.dispose();
    }
  });
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, ByteData> assets;
  Completer<ByteData>? slowLogo;

  setUpAll(() async => assets = await _fixtureAssets());
  setUp(() {
    slowLogo = null;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final name = Uri.decodeFull(utf8.decode(Uint8List.sublistView(message!)));
      if (name == _slowLogo || name == _disposedLogo) return slowLogo!.future;
      if (assets.containsKey(name)) return assets[name];
      for (final file in [File(name), File('build/unit_test_assets/$name')]) {
        if (await file.exists()) {
          return ByteData.sublistView(await file.readAsBytes());
        }
      }
      return null;
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('synthetic assets resolve through the production asset loader', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final stream = const AssetImage(
        _whitePoster,
      ).resolve(ImageConfiguration.empty);
      final result = Completer<ImageInfo>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, sync) {
          stream.removeListener(listener);
          result.complete(info);
        },
        onError: (Object error, StackTrace? stack) {
          stream.removeListener(listener);
          result.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      final info = await result.future;
      expect(info.image.width, 200);
      expect(info.image.height, 300);
      info.dispose();
    });
  });

  for (final scenario in [
    ('white-poster-white-logo', _whitePoster, _whiteLogo),
    ('dark-poster-black-logo', _darkPoster, _blackLogo),
    ('white-poster-black-logo', _whitePoster, _blackLogo),
    ('dark-poster-white-logo', _darkPoster, _whiteLogo),
    ('busy-poster-colored-logo', _busyPoster, _colorLogo),
    ('busy-poster-mixed-logo', _busyPoster, _mixedLogo),
    ('missing-poster-white-logo', null, _whiteLogo),
  ]) {
    testWidgets('the actual wallet face handles ${scenario.$1}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pass = _pass(scenario.$1, poster: scenario.$2, logo: scenario.$3);
      await _pumpFace(tester, pass);
      await _finishArtwork(tester);
      final heroImages = tester.widgetList<Image>(
        find.descendant(
          of: find.byKey(MovieTicketFace.heroKey),
          matching: find.byType(Image),
        ),
      );
      expect(
        heroImages.isNotEmpty ||
            _heroTitle(pass.movieTitle).evaluate().isNotEmpty,
        isTrue,
        reason:
            'The hero must retain the title logo or a readable title fallback',
      );
      if (scenario.$1.startsWith('white-poster-white') ||
          scenario.$1.startsWith('dark-poster-black')) {
        expect(
          heroImages,
          isNotEmpty,
          reason: 'Simple light/dark logos should remain artwork',
        );
        await _expectVisibleLogoContrast(
          tester,
          scenario.$3,
          assets[scenario.$3]!,
        );
      }
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, scenario.$1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final logo in <String?>[null, _emptyLogo, _failedLogo]) {
    testWidgets('unusable logo $logo leaves a title inside the hero', (
      tester,
    ) async {
      final pass = _pass('Readable fallback', poster: _whitePoster, logo: logo);
      await _pumpFace(tester, pass);
      expect(
        _heroTitle(pass.movieTitle),
        findsOneWidget,
        reason: 'Loading must be readable immediately',
      );
      await _finishArtwork(tester);
      expect(_heroTitle(pass.movieTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        logo == null
            ? 'missing-logo'
            : logo == _emptyLogo
            ? 'transparent-logo'
            : 'failed-logo',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'late artwork cannot replace a new pass or update a disposed face',
    (tester) async {
      slowLogo = Completer<ByteData>();
      await _pumpFace(
        tester,
        _pass(
          'Old movie',
          poster: _whitePoster,
          logo: _slowLogo,
          passId: 'same-id',
        ),
      );
      expect(_heroTitle('Old movie'), findsOneWidget);
      await _pumpFace(
        tester,
        _pass('New movie', poster: _darkPoster, passId: 'same-id'),
      );
      expect(_heroTitle('New movie'), findsOneWidget);
      await tester.runAsync(() async {
        slowLogo!.complete(assets[_whiteLogo]!);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await _finishArtwork(tester);
      expect(_heroTitle('Old movie'), findsNothing);
      expect(_heroTitle('New movie'), findsOneWidget);
      slowLogo = Completer<ByteData>();
      await _pumpFace(
        tester,
        _pass('Disposed movie', poster: _whitePoster, logo: _disposedLogo),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        slowLogo!.complete(assets[_blackLogo]!);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await _finishArtwork(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a reused pass ID does not retain another logo after a source change',
    (tester) async {
      await _pumpFace(
        tester,
        _pass('Movie', poster: _whitePoster, logo: _whiteLogo),
      );
      await _finishArtwork(tester);
      await _pumpFace(
        tester,
        _pass('Movie', poster: _darkPoster, logo: _blackLogo),
      );
      final oldLogo = find.descendant(
        of: find.byKey(MovieTicketFace.heroKey),
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && _assetName(widget.image) == _whiteLogo,
        ),
      );
      expect(oldLogo, findsNothing);
      await _finishArtwork(tester);
      await _expectVisibleLogoContrast(tester, _blackLogo, assets[_blackLogo]!);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
