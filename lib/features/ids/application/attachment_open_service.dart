import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/attachment_store.dart';
import '../domain/id_attachment.dart';

/// Hands an attachment to whatever viewer the device already has.
///
/// This is the one place in the feature where a decrypted document exists as a
/// plain file. Everything else -- image previews, PDF page rendering -- works
/// from an in-memory buffer precisely so that never happens. An external viewer
/// cannot read a buffer: it needs a path, and on Android a `content://` grant
/// over a real file. So the tradeoff is deliberate and bounded rather than
/// avoided:
///
///  - The file is written to the **cache** directory, never to app documents,
///    so the OS may reclaim it and `allowBackup="false"` keeps it out of any
///    cloud backup.
///  - The directory is purged before every open, when the attachment sheet
///    closes, and again at app start. The plaintext lives for one viewing
///    session, not indefinitely.
///  - Only the file being opened is ever written. There is no bulk export path.
///
/// If that window is ever judged too wide, the fix is to drop external opening
/// and keep the in-app renderer, not to lengthen the lifetime here.
class AttachmentOpenService {
  const AttachmentOpenService._();

  static const String _dirName = 'attachment_open';

  static Future<Directory> _dir() async {
    final Directory cache = await getTemporaryDirectory();
    return Directory('${cache.path}${Platform.pathSeparator}$_dirName');
  }

  /// Decrypts [attachment] to a short-lived cache file and opens it.
  ///
  /// Returns null on success, or a short user-facing reason on failure.
  static Future<String?> openExternally({
    required AttachmentStore store,
    required String docId,
    required IdAttachment attachment,
    required String fileExtension,
  }) async {
    // Purge first, not only after: if a previous session was killed mid-view,
    // its plaintext is still sitting there and this is the next chance to
    // remove it.
    await purge();

    try {
      final Uint8List bytes = await store.resolveBytes(docId, attachment);

      final Directory dir = await _dir();
      await dir.create(recursive: true);

      final File file = File(
        '${dir.path}${Platform.pathSeparator}${attachment.id}.$fileExtension',
      );
      await file.writeAsBytes(bytes, flush: true);

      final OpenResult result = await OpenFilex.open(file.path);
      if (result.type == ResultType.done) return null;

      // Nothing on the device claims the type, or the open was refused. Drop
      // the plaintext immediately rather than waiting for the next purge.
      await purge();
      return switch (result.type) {
        ResultType.noAppToOpen => 'No app on this device can open this file.',
        ResultType.permissionDenied => 'Permission to open the file was denied.',
        _ => 'Could not open the file.',
      };
    } catch (_) {
      await purge();
      return 'Could not open the file.';
    }
  }

  /// Removes every decrypted file this service has written.
  ///
  /// Safe to call at any time and deliberately silent: it only ever touches
  /// this service's own cache directory, and a failure to clean up must not
  /// surface as an error to the user.
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
