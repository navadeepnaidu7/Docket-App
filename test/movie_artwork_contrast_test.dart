import 'dart:async';

import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/presentation/movie/movie_artwork_contrast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pixels(List<Color> colors, {int repeat = 30}) => Uint8List.fromList([
  for (var i = 0; i < repeat; i++)
    for (final color in colors) ...[
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      (color.a * 255).round(),
    ],
]);

MovieArtworkContrastResult _analyze(List<Color> logo, List<Color> poster) =>
    MovieArtworkContrastPolicy.analyze(
      logoRgba: _pixels(logo),
      posterRgba: _pixels(poster),
      fallbackColors: const [0xFF192038, 0xFF0C1020],
    );

MoviePass _pass(String artwork) => MoviePass.fromJson({
  'id': 'same-booking',
  'brand': 'district',
  'movieTitle': 'Mock movie',
  'posterUrl': 'https://example.invalid/$artwork.jpg',
  'logoUrl': 'https://example.invalid/$artwork.png',
  'seats': [
    {'row': 'A', 'number': '1'},
  ],
});

void main() {
  test('luminance linearizes sRGB before computing contrast', () {
    expect(
      MovieArtworkContrastPolicy.luminance(.5, .5, .5),
      closeTo(.21404, .0001),
    );
    expect(MovieArtworkContrastPolicy.contrastRatio(0, 1), 21);
  });

  test('white lettering over a pale poster receives a dark veil', () {
    final result = _analyze([Colors.white], [Colors.white]);
    expect(result.showLogo, isTrue);
    expect(result.veilColor, 0xFF000000);
    expect(result.opacity, greaterThan(0));
  });

  test('black lettering over dark artwork receives a light veil', () {
    final result = _analyze([Colors.black], [Colors.black]);
    expect(result.showLogo, isTrue);
    expect(result.veilColor, 0xFFFFFFFF);
    expect(result.opacity, greaterThan(0));
  });

  test('natural contrast does not require a veil', () {
    final result = _analyze([Colors.white], [Colors.black]);
    expect(result.showLogo, isTrue);
    expect(result.opacity, 0);
  });

  test('transparent padding does not alter the visible ink decision', () {
    final normal = _analyze([Colors.white], [Colors.white]);
    final padded = _analyze(
      [Colors.white, ...List.filled(100, const Color(0x0000FF00))],
      [Colors.white],
    );
    expect(padded.showLogo, normal.showLogo);
    expect(padded.veilColor, normal.veilColor);
    expect(padded.opacity, normal.opacity);
    expect(_analyze([Colors.transparent], [Colors.white]).showLogo, isFalse);
  });

  test('partly transparent ink uses its composited contrast', () {
    final opaque = _analyze([Colors.white], [Colors.white]);
    final translucent = _analyze([const Color(0x99FFFFFF)], [Colors.white]);
    expect(translucent.showLogo, isTrue);
    expect(translucent.opacity, greaterThanOrEqualTo(opaque.opacity));
    expect(
      _analyze([const Color(0x10FFFFFF)], [Colors.white]).showLogo,
      isFalse,
    );
  });

  for (final logo in [
    [Colors.white, Colors.black],
    [Colors.yellow, Colors.blue],
    [Colors.red, Colors.green, Colors.white, Colors.black],
  ]) {
    test('mixed ink is checked individually: $logo', () {
      final result = _analyze(logo, [Colors.white, Colors.black, Colors.blue]);
      if (!result.showLogo) return;
      // Independent Color blending checks each real ink color, not its average.
      for (final color in logo) {
        for (final background in [Colors.white, Colors.black, Colors.blue]) {
          final veil = Color(
            result.veilColor,
          ).withValues(alpha: result.opacity);
          final adjusted = Color.alphaBlend(veil, background);
          final ratio = MovieArtworkContrastPolicy.contrastRatio(
            color.computeLuminance(),
            adjusted.computeLuminance(),
          );
          expect(ratio, greaterThanOrEqualTo(3));
        }
      }
    });
  }

  test('source types and fallback hint participate in the artwork key', () {
    final network = _pass('one');
    final asset = MoviePass.fromJson({
      ...network.toJson(),
      'posterAsset': network.posterUrl,
    });
    final other = _pass('two');
    expect(
      MovieArtworkContrastKey.forPass(network),
      isNot(MovieArtworkContrastKey.forPass(asset)),
    );
    expect(
      MovieArtworkContrastKey.forPass(network),
      isNot(MovieArtworkContrastKey.forPass(other)),
    );
    final hint = MoviePass.fromJson({
      ...network.toJson(),
      'posterHint': 'romance',
    });
    expect(
      MovieArtworkContrastKey.forPass(network),
      isNot(MovieArtworkContrastKey.forPass(hint)),
    );
  });

  test(
    'cache deduplicates work, bounds pending requests and evicts least recently used results',
    () async {
      final completions = <String, Completer<MovieArtworkContrastResult>>{};
      var starts = 0;
      final service = MovieArtworkContrastService(
        capacity: 2,
        maxPending: 1,
        analyzeOverride: (pass) {
          starts++;
          return completions.putIfAbsent(pass.posterUrl!, Completer.new).future;
        },
      );
      final one = service.resolveContrast(_pass('one'));
      expect(identical(one, service.resolveContrast(_pass('one'))), isTrue);
      final rejected = await service.resolveContrast(_pass('two'));
      expect(rejected.showLogo, isFalse);
      expect(rejected.cacheable, isFalse);
      expect(service.pendingCount, 1);
      expect(starts, 1);
      completions.values.single.complete(
        const MovieArtworkContrastResult(showLogo: true),
      );
      await one;
      for (final key in ['two', 'three']) {
        final result = service.resolveContrast(_pass(key));
        completions['https://example.invalid/$key.jpg']!.complete(
          const MovieArtworkContrastResult(showLogo: true),
        );
        await result;
        if (key == 'two')
          service.getCached(MovieArtworkContrastKey.forPass(_pass('one')));
      }
      expect(service.cachedCount, 2);
      expect(
        service.getCached(MovieArtworkContrastKey.forPass(_pass('one'))),
        isNotNull,
      );
      expect(
        service.getCached(MovieArtworkContrastKey.forPass(_pass('two'))),
        isNull,
      );
      expect(service.pendingCount, 0);
    },
  );

  test(
    'transient failures can retry and clear prevents stale completions repopulating the cache',
    () async {
      var fail = true;
      final gate = Completer<MovieArtworkContrastResult>();
      final service = MovieArtworkContrastService(
        analyzeOverride: (pass) {
          if (fail) throw StateError('Mock image unavailable');
          return gate.future;
        },
      );
      expect((await service.resolveContrast(_pass('one'))).cacheable, isFalse);
      expect(service.cachedCount, 0);
      fail = false;
      final pending = service.resolveContrast(_pass('one'));
      service.clear();
      expect(service.pendingCount, 1);
      gate.complete(const MovieArtworkContrastResult(showLogo: true));
      expect((await pending).showLogo, isTrue);
      expect(service.cachedCount, 0);
      expect(service.pendingCount, 0);
    },
  );
}
