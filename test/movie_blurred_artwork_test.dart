import 'dart:async';
import 'dart:ui' as ui;

import 'package:docket/features/tickets/presentation/movie/movie_blurred_artwork.dart';
import 'package:docket/features/tickets/presentation/movie/movie_feathered_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(ImageInfo, ImageStreamCompleter?)> _resolve(
  ImageProvider provider,
) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final result = Completer<ImageInfo>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, sync) {
      stream.removeListener(listener);
      result.complete(image);
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      result.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return (await result.future, stream.completer);
}

void main() {
  testWidgets(
    'feathered poster keeps sharp pixels and intersects soft edge alpha once',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final sourceImage = await picture.toImage(32, 48);
        picture.dispose();
        final source = _PendingImage(
          Future.value(ImageInfo(image: sourceImage)),
        );
        MovieFeatheredImage image() => MovieFeatheredImage(
          source: source,
          colors: const [Colors.red, Colors.red],
          width: 64,
          height: 96,
          sideFraction: .1,
          topFraction: .1,
          bottomFraction: .2,
        );
        final first = await _resolve(image());
        final second = await _resolve(image());
        expect(identical(first.$2, second.$2), isTrue);
        final pixels = (await first.$1.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int channel(int x, int y, int c) =>
            pixels.getUint8((y * 64 + x) * 4 + c);
        expect(channel(32, 48, 3), 255);
        expect(channel(32, 48, 2), closeTo((Colors.blue.b * 255).round(), 2));
        expect(channel(32, 48, 1), closeTo((Colors.blue.g * 255).round(), 2));
        expect(channel(32, 48, 0), closeTo((Colors.blue.r * 255).round(), 2));
        expect(channel(0, 0, 3), lessThan(5));
        expect(channel(32, 1, 3), inExclusiveRange(0, 128));
        expect(channel(32, 89, 3), lessThan(channel(32, 6, 3)));
        await image().evict();
        first.$1.dispose();
        expect(second.$1.image.width, 64);
        second.$1.dispose();
        await source.evict();
      });
    },
  );

  testWidgets(
    'prepared blur is reused, bounded and survives cache eviction while displayed',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 32, 48),
          Paint()..color = Colors.orange,
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 16, 48),
          Paint()..color = Colors.blue,
        );
        final picture = recorder.endRecording();
        final sourceImage = await picture.toImage(32, 48);
        picture.dispose();
        final bytes = await sourceImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        sourceImage.dispose();
        final source = MemoryImage(bytes!.buffer.asUint8List());
        MovieBlurredImage image({int width = 64, BoxFit fit = BoxFit.cover}) =>
            MovieBlurredImage(
              source: source,
              width: width,
              height: 96,
              sigma: 4,
              fit: fit,
              overscan: 1.18,
            );
        final first = await _resolve(image());
        final second = await _resolve(image());
        expect(identical(first.$2, second.$2), isTrue);
        expect(first.$1.image.width, 64);
        expect(first.$1.image.height, 96);
        expect(image(), isNot(image(width: 65)));
        expect(image(), isNot(image(fit: BoxFit.fill)));
        await image().evict();
        // Active listeners own image handles independently of the cache's handle.
        expect(first.$1.image.width, 64);
        final third = await _resolve(image());
        expect(identical(first.$2, third.$2), isFalse);
        for (final info in [first.$1, second.$1, third.$1]) {
          info.dispose();
        }
        await image().evict();
        await source.evict();
      });
    },
  );

  testWidgets('a route can close while its artwork is still preparing', (
    tester,
  ) async {
    final source = Completer<ImageInfo>();
    final provider = MovieBlurredImage(
      source: _PendingImage(source.future),
      width: 64,
      height: 96,
      sigma: 4,
      fit: BoxFit.cover,
      overscan: 1.18,
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Image(
          image: provider,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
      final picture = recorder.endRecording();
      source.complete(ImageInfo(image: await picture.toImage(2, 2)));
      picture.dispose();
    });
    // Stream callbacks run in the fake-async zone; rasterization finishes
    // outside it. Advance both without awaiting a fake-zone future in runAsync.
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Image(image: provider),
      ),
    );
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 64);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.evict();
    expect(tester.takeException(), isNull);
  });
}

class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage(this.image);
  final Future<ImageInfo> image;
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PendingImage>(this);
  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(image);
}
