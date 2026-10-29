import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class IdShareArtifact {
  const IdShareArtifact.text(this.text)
    : bytes = null,
      extension = '',
      mimeType = 'text/plain';
  const IdShareArtifact.file(
    this.bytes, {
    required this.extension,
    required this.mimeType,
  }) : text = null;
  final String? text;
  final Uint8List? bytes;
  final String extension;
  final String mimeType;
}

class IdShareService {
  static Future<void> share(IdShareArtifact artifact, Rect origin) async {
    if (artifact.text != null) {
      await SharePlus.instance.share(
        ShareParams(text: artifact.text, sharePositionOrigin: origin),
      );
      return;
    }
    final root = Directory(
      '${(await getTemporaryDirectory()).path}/id_exports',
    );
    await root.create(recursive: true);
    final session = await root.createTemp('share-');
    final file = File('${session.path}/document.${artifact.extension}');
    await file.writeAsBytes(artifact.bytes!, flush: true);
    Timer(const Duration(hours: 1), () async {
      try {
        await file.delete();
        await session.delete();
      } catch (_) {
        /* Startup retries cleanup. */
      }
    });
    // A recipient may read after the chooser completes. Keep its grant usable;
    // the stale-file sweep removes exports after the bounded transfer window.
    if (Platform.isAndroid) {
      await const MethodChannel(
        'com.docket/id_import',
      ).invokeMethod<void>('shareFile', {'path': file.path});
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: artifact.mimeType)],
        sharePositionOrigin: origin,
      ),
    );
  }

  static Future<void> sweepStale() async {
    final root = Directory(
      '${(await getTemporaryDirectory()).path}/id_exports',
    );
    if (!await root.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final entity in root.list()) {
      if ((await entity.stat()).modified.isBefore(cutoff)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          /* Retry next startup. */
        }
      }
    }
  }
}

/// Only raster images enter the new PDF. No original text layers, annotations,
/// embedded files, document metadata or recoverable covered text are copied.
Future<Uint8List> buildRedactedPdf(List<Uint8List> pages) =>
    compute(_encodePdf, pages);

Future<Uint8List> _encodePdf(List<Uint8List> pages) async {
  final document = pw.Document();
  for (final bytes in pages) {
    final image = pw.MemoryImage(bytes);
    final ratio = image.width! / image.height!;
    final format = PdfPageFormat(595, 595 / ratio, marginAll: 0);
    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          image,
          fit: pw.BoxFit.fill,
          width: format.width,
          height: format.height,
        ),
      ),
    );
  }
  return document.save();
}
