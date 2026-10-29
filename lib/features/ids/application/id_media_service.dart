import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/attachment_limits.dart';

/// Owns only this import's private, short-lived files. Never deletes picker files.
class IdImportSession {
  Directory? _directory;
  bool _closed = false;
  Future<Directory> _dir() async {
    if (_closed) throw StateError('Import closed');
    final existing = _directory;
    if (existing != null) return existing;
    final created = await Directory(
      '${(await getTemporaryDirectory()).path}/id_imports',
    ).create(recursive: true).then((root) => root.createTemp('session-'));
    if (_closed) {
      await created.delete();
      throw StateError('Import closed');
    }
    _directory = created;
    return created;
  }

  Future<File> keepOriginal(File input) async {
    final size = await input.length();
    if (size <= 0 ||
        size > kMaxAttachmentSizeBytes ||
        kindForExtension(input.path) == null) {
      throw const FormatException('Choose an image or PDF up to 25 MB.');
    }
    final handle = await input.open();
    late String extension;
    try {
      final header = await handle.read(1024);
      final text = String.fromCharCodes(header);
      if (text.contains('%PDF-')) {
        extension = 'pdf';
      } else if (header.length > 8 && header[0] == 0x89 && header[1] == 0x50) {
        extension = 'png';
      } else if (header.length > 3 && header[0] == 0xFF && header[1] == 0xD8) {
        extension = 'jpg';
      } else if (header.length > 12 && text.substring(8, 12) == 'WEBP') {
        extension = 'webp';
      } else if (header.length > 12 &&
          text.substring(4, 8) == 'ftyp' &&
          ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].any(text.contains)) {
        extension = 'heic';
      } else {
        throw const FormatException(
          'This file is not a supported image or PDF.',
        );
      }
    } finally {
      await handle.close();
    }
    final dir = await _dir();
    return input.copy(
      '${dir.path}/original-${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
  }

  Future<File> workingImage(Uint8List bytes) async {
    final dir = await _dir();
    return File(
      '${dir.path}/working-${DateTime.now().microsecondsSinceEpoch}.png',
    ).writeAsBytes(bytes, flush: true);
  }

  Future<void> close() async {
    _closed = true;
    final dir = _directory;
    if (dir != null && await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        /* Next startup sweeps stale sessions. */
      }
    }
  }

  static Future<void> sweepStale() async {
    final root = Directory(
      '${(await getTemporaryDirectory()).path}/id_imports',
    );
    if (!await root.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in root.list()) {
      if ((await entity.stat()).modified.isBefore(cutoff)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          /* Best effort. */
        }
      }
    }
  }
}

Future<PdfDocument> openIdPdf(
  Uint8List bytes, {
  PdfPasswordProvider? passwordProvider,
}) async {
  await pdfrxFlutterInitialize();
  return PdfDocument.openData(
    bytes,
    sourceName: 'private-document',
    passwordProvider: passwordProvider,
  );
}

Future<Uint8List> rasterIdPage(PdfPage page, {int longEdge = 1800}) async {
  if (page.width <= 0 || page.height <= 0) {
    throw const FormatException('Invalid page size');
  }
  final scale = longEdge / math.max(page.width, page.height);
  final rendered = await page.render(
    fullWidth: math.max(1, page.width * scale),
    fullHeight: math.max(1, page.height * scale),
    backgroundColor: 0xFFFFFFFF,
  );
  if (rendered == null) throw const FormatException('Could not read PDF page');
  try {
    final image = await rendered.createImage();
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    rendered.dispose();
  }
}

Future<Uint8List> normaliseIdImage(
  Uint8List bytes, {
  int longEdge = 2200,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  // Let Flutter own the descriptor and buffer lifetime. Disposing the descriptor
  // before getNextFrame completes can invalidate the asynchronous native decode.
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      if (width <= 0 || height <= 0 || width * height > 100000000) {
        throw const FormatException(
          'This image is too large to process. Choose a smaller copy.',
        );
      }
      final scale = math.min(1.0, longEdge / math.max(width, height));
      return ui.TargetImageSize(
        width: math.max(1, (width * scale).round()),
        height: math.max(1, (height * scale).round()),
      );
    },
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      // The codec maintains aspect ratio. A second pass bounds tall portrait images.
      final data = (await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      return compute(_boundImage, (data, longEdge));
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Uint8List _boundImage((Uint8List, int) input) {
  var image = img.decodeImage(input.$1);
  if (image == null) {
    throw const FormatException('This image could not be read.');
  }
  if (math.max(image.width, image.height) > input.$2) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? input.$2 : null,
      height: image.height > image.width ? input.$2 : null,
    );
  }
  return img.encodePng(image);
}

/// Four corners are normalised clockwise: top-left, top-right, bottom-right, bottom-left.
Uint8List rectifyIdImage((Uint8List, List<ui.Offset>) input) {
  final image = img.decodeImage(input.$1)!;
  final p = input.$2
      .map(
        (v) => img.Point(v.dx * (image.width - 1), v.dy * (image.height - 1)),
      )
      .toList();
  double distance(img.Point a, img.Point b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  final width = math
      .max(distance(p[0], p[1]), distance(p[3], p[2]))
      .round()
      .clamp(64, 2200);
  final height = math
      .max(distance(p[0], p[3]), distance(p[1], p[2]))
      .round()
      .clamp(64, 2200);
  return img.encodePng(
    img.copyRectify(
      image,
      topLeft: p[0],
      topRight: p[1],
      bottomRight: p[2],
      bottomLeft: p[3],
      toImage: img.Image(width: width, height: height),
      interpolation: img.Interpolation.linear,
    ),
  );
}

String idImageQuality(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return 'Check that all text is readable.';
  final image = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height
        ? math.min(320, decoded.width)
        : null,
    height: decoded.height > decoded.width
        ? math.min(320, decoded.height)
        : null,
  );
  var glare = 0;
  var edges = 0.0;
  var count = 0;
  for (var y = 1; y < image.height - 1; y++) {
    for (var x = 1; x < image.width - 1; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.r > 250 && pixel.g > 250 && pixel.b > 250) glare++;
      final v = pixel.luminance;
      edges +=
          (4 * v -
                  image.getPixel(x - 1, y).luminance -
                  image.getPixel(x + 1, y).luminance -
                  image.getPixel(x, y - 1).luminance -
                  image.getPixel(x, y + 1).luminance)
              .abs();
      count++;
    }
  }
  if (count > 0 && edges / count < 4) {
    return 'Text may be soft. Check focus before continuing.';
  }
  if (count > 0 && glare / count > .55) {
    return 'Check bright areas for glare hiding text.';
  }
  return 'Check names and numbers carefully after scanning.';
}
