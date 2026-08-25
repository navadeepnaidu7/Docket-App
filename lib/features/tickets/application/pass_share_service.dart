import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/movie_pass_models.dart';
import '../domain/pass_catalog.dart';
import '../domain/pass_share_summary.dart';
import '../presentation/share/pass_share_card.dart';

/// Outcome of a share or save, as a value rather than an exception.
///
/// Refusing a permission and closing a share sheet are ordinary things a person
/// does, not failures — modelling them as thrown exceptions would push normal
/// flow through `catch` blocks at every call site.
enum PassShareStatus { ok, denied, failed }

@immutable
class PassShareResult {
  const PassShareResult(this.status, [this.message]);

  const PassShareResult.ok() : this(PassShareStatus.ok, null);

  final PassShareStatus status;

  /// Short user-facing reason. Null when [status] is [PassShareStatus.ok].
  final String? message;

  bool get isOk => status == PassShareStatus.ok;
}

/// Renders a pass to a PNG and hands it to the OS.
///
/// This is the second place in the app where personal data exists as a plain
/// file, after `AttachmentOpenService`, and it follows the same written policy
/// for the same reasons: **cache directory only, one file at a time, and a
/// bounded lifetime.** A share sheet needs a real path — it cannot take a buffer
/// — so the tradeoff is bounded rather than avoided. If that window is ever
/// judged too wide the fix is to drop file sharing, not to lengthen the
/// lifetime here.
///
/// Nothing in this class logs pass contents.
class PassShareService {
  const PassShareService._();

  static const String _dirName = 'pass_share';

  /// Cap on the exported image's long edge, in device pixels.
  ///
  /// A full 3x capture of a ~1000pt card is a multi-megabyte PNG, and some
  /// share targets silently drop or recompress attachments past a few MB. This
  /// trades a little sharpness for an image that actually arrives.
  static const double _maxPixelHeight = 2400;

  /// How long to wait for the movie hero art before giving up on it.
  static const Duration _artTimeout = Duration(seconds: 4);

  static Future<Directory> _dir() async {
    final Directory cache = await getTemporaryDirectory();
    return Directory('${cache.path}${Platform.pathSeparator}$_dirName');
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  /// Rasterises [item]'s share card to PNG bytes, or null if it could not be
  /// drawn.
  ///
  /// Works by parking a [PassShareCard] in the app's [Overlay] far off-screen
  /// and capturing its [RepaintBoundary]. It has to be a real overlay entry:
  /// `Offstage` does not paint, so `toImage` on an offstage subtree returns a
  /// blank image rather than failing — the kind of bug that ships because
  /// nothing throws.
  static Future<Uint8List?> renderPng(
    BuildContext context,
    WalletPassItem item,
  ) async {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    // Warm the network art first. The movie hero is a CachedNetworkImage;
    // captured cold it paints its shimmer placeholder, and the exported card
    // would show a loading state forever.
    await _precacheArt(context, item);
    if (!context.mounted) return null;

    final GlobalKey boundaryKey = GlobalKey();
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext _) => Positioned(
        // Far enough left to be outside any plausible viewport, while staying
        // in the tree so it lays out and paints.
        left: -10000,
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          child: PassShareCard(item: item),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // One frame to lay out and paint, a second so any image that resolved
      // during the first is actually on the canvas.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final RenderObject? object =
          boundaryKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return null;

      final double pixelRatio = _pixelRatioFor(object.size.height);
      final ui.Image image = await object.toImage(pixelRatio: pixelRatio);
      try {
        final ByteData? data =
            await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    } finally {
      // Always, on every path — a leaked entry would sit invisibly in the
      // overlay for the rest of the session. Guarded because `remove` asserts
      // on an overlay that has already gone, which can happen if the app is
      // torn down mid-capture, and a failed cleanup must not become the
      // error the user sees.
      try {
        entry.remove();
      } catch (_) {
        // Nothing left to remove it from.
      }
    }
  }

  /// Capture scale, clamped so the long edge stays within [_maxPixelHeight].
  static double _pixelRatioFor(double logicalHeight) {
    if (logicalHeight <= 0) return 1;
    return math.min(3.0, _maxPixelHeight / logicalHeight).clamp(1.0, 3.0);
  }

  /// Best effort warm-up of the movie hero art.
  ///
  /// Deliberately swallows everything: offline, a blocked host, or a film with
  /// no artwork are all normal, and the face already falls back to its
  /// `posterHint` gradient. An export must not fail because a poster did not
  /// load.
  static Future<void> _precacheArt(
    BuildContext context,
    WalletPassItem item,
  ) async {
    if (item is! MoviePassItem) return;
    final MoviePass pass = item.pass;
    // Glance density draws the logo when there is one, so warm that first and
    // only fall back to the poster the face would use in its place.
    final String? url = pass.resolvedLogoUrl ?? pass.resolvedPosterUrl;
    if (url == null) return;

    try {
      await precacheImage(CachedNetworkImageProvider(url), context)
          .timeout(_artTimeout);
    } catch (_) {
      // Gradient fallback it is.
    }
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  /// Renders [item] and opens the system share sheet with the PNG and its
  /// summary text.
  static Future<PassShareResult> share(
    BuildContext context,
    WalletPassItem item,
  ) async {
    final Uint8List? bytes = await renderPng(context, item);
    if (bytes == null) {
      return const PassShareResult(
        PassShareStatus.failed,
        'Could not prepare the pass image.',
      );
    }

    // Purge on the way in. Deliberately not on the way out as well: `share`
    // resolves when the sheet is dismissed, which is not when the receiving app
    // is done with the file — a mail client can hold the content:// URI until
    // the draft is sent. Deleting there would yank a ticket out of a half-sent
    // message. The lifetime is bounded by this call and by the sweep at app
    // start instead.
    await purge();

    try {
      final Directory dir = await _dir();
      await dir.create(recursive: true);

      final File file = File(
        '${dir.path}${Platform.pathSeparator}${passShareFileName(item)}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          text: buildPassShareText(item),
        ),
      );
      return const PassShareResult.ok();
    } catch (_) {
      // The file may already be on disk. Drop it now rather than leaving
      // plaintext behind for a share that never happened.
      await purge();
      return const PassShareResult(
        PassShareStatus.failed,
        'Could not share the pass.',
      );
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Renders [item] and writes the PNG to the device photo library.
  ///
  /// Never touches the cache directory — `gal` takes the bytes straight to
  /// MediaStore / PHPhotoLibrary, so there is no intermediate plaintext file
  /// to clean up.
  static Future<PassShareResult> saveToGallery(
    BuildContext context,
    WalletPassItem item,
  ) async {
    final Uint8List? bytes = await renderPng(context, item);
    if (bytes == null) {
      return const PassShareResult(
        PassShareStatus.failed,
        'Could not prepare the pass image.',
      );
    }

    try {
      // gal's put* methods throw on a missing permission rather than asking for
      // one, so the prompt has to be raised here. Without this the very first
      // save on iOS fails with "no access" and the person is never actually
      // asked. On Android 29+ this returns true without showing anything.
      if (!await Gal.requestAccess()) {
        return const PassShareResult(
          PassShareStatus.denied,
          'Docket needs photo access to save the pass.',
        );
      }

      await Gal.putImageBytes(bytes, name: passShareFileName(item));
      return const PassShareResult.ok();
    } on GalException catch (e) {
      return switch (e.type) {
        GalExceptionType.accessDenied => const PassShareResult(
            PassShareStatus.denied,
            'Docket needs photo access to save the pass.',
          ),
        GalExceptionType.notEnoughSpace => const PassShareResult(
            PassShareStatus.failed,
            'Not enough space to save the pass.',
          ),
        _ => const PassShareResult(
            PassShareStatus.failed,
            'Could not save the pass.',
          ),
      };
    } catch (_) {
      return const PassShareResult(
        PassShareStatus.failed,
        'Could not save the pass.',
      );
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Removes every file this service has written.
  ///
  /// Safe to call at any time and deliberately silent: it only touches this
  /// service's own cache directory, and a failed cleanup must not surface to
  /// the user as an error about sharing.
  static Future<void> purge() async {
    try {
      final Directory dir = await _dir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best effort.
    }
  }
}
