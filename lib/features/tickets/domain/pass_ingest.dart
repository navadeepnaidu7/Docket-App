import 'pass_status.dart';

/// Leaf category sent as the extract `category` hint.
enum PassInputCategory {
  train,
  bus,
  movie;

  String get hint => name;

  PassKind get kind => switch (this) {
        PassInputCategory.train => PassKind.train,
        PassInputCategory.bus => PassKind.bus,
        PassInputCategory.movie => PassKind.movie,
      };
}

/// How the user is providing the ticket.
enum PassInputSource { pnr, photo, pdf }

/// Matches the server's `EXTRACT_MAX_UPLOAD_BYTES` default (12 MiB).
const int kExtractMaxUploadBytes = 12 * 1024 * 1024;

abstract final class PassUpload {
  PassUpload._();

  static const List<String> imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static const List<String> fileExtensions = <String>[
    ...imageExtensions,
    'pdf',
  ];

  static String? mimeForPath(String path) {
    final String ext = extensionOf(path);
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }

  static String extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }
}

enum PassIngestCode {
  needsRemote,
  needsAuth,
  invalidPnr,
  fileTooLarge,
  unsupportedFile,
  rateLimited,
  unreadable,
  failed,
}

class PassIngestException implements Exception {
  const PassIngestException(
    this.code,
    this.message, {
    this.retryAfterSeconds,
    this.window,
  });

  final PassIngestCode code;
  final String message;
  final int? retryAfterSeconds;
  final String? window;

  @override
  String toString() => message;
}
