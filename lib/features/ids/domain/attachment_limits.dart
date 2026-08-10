import 'id_attachment.dart';

/// Maximum allowed image attachments per ID document.
const int kMaxImageAttachments = 3;

/// Maximum allowed PDF attachments per ID document.
const int kMaxPdfAttachments = 1;

/// Maximum allowed file size per attachment (25 MB in bytes).
const int kMaxAttachmentSizeBytes = 25 * 1024 * 1024;

/// Reasons why an attachment operation might be rejected.
enum AttachRejection {
  limitReached,
  unsupportedType,
  tooLarge,
  ioError,
}

/// Outcome of an attachment operation.
///
/// A real sealed class, matching [WalletPassItem] in the passes feature, so
/// callers exhaust it with a `switch` and the analyzer catches a missed case.
/// The earlier shape -- nullable getters on a base class that downcast -- let a
/// caller read `result.attachment` on a failure and silently get null.
sealed class AttachResult {
  const AttachResult();
}

class AttachSuccess extends AttachResult {
  const AttachSuccess(this.attachment);
  final IdAttachment attachment;
}

class AttachFailure extends AttachResult {
  const AttachFailure(this.rejection, this.message);
  final AttachRejection rejection;

  /// Short, user-facing text. Must never contain a file path, a document
  /// number, or anything else drawn from the record itself.
  final String message;
}

/// Determines the attachment kind from a file extension.
///
/// Accepts jpg, jpeg, png, heic, webp as image kinds and pdf as pdf kind.
/// Extension evaluation is case-insensitive. Returns null for unsupported
/// extensions or filenames without a valid extension dot.
IdAttachmentKind? kindForExtension(String fileName) {
  final lastDot = fileName.lastIndexOf('.');
  if (lastDot == -1 || lastDot == fileName.length - 1) {
    return null;
  }
  final ext = fileName.substring(lastDot + 1).toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'heic':
    case 'webp':
      return IdAttachmentKind.image;
    case 'pdf':
      return IdAttachmentKind.pdf;
    default:
      return null;
  }
}

/// Evaluates whether an incoming attachment violates file size or count limits.
///
/// Returns null if the attachment is permitted. Returns [AttachRejection.tooLarge]
/// if size exceeds 25 MB, or [AttachRejection.limitReached] if adding another
/// image or PDF exceeds the respective cap (3 images, 1 PDF).
AttachRejection? rejectionFor({
  required List<IdAttachment> existing,
  required IdAttachmentKind incoming,
  required int sizeBytes,
}) {
  if (sizeBytes > kMaxAttachmentSizeBytes) {
    return AttachRejection.tooLarge;
  }

  if (incoming == IdAttachmentKind.image) {
    final imageCount =
        existing.where((a) => a.kind == IdAttachmentKind.image).length;
    if (imageCount >= kMaxImageAttachments) {
      return AttachRejection.limitReached;
    }
  } else if (incoming == IdAttachmentKind.pdf) {
    final pdfCount =
        existing.where((a) => a.kind == IdAttachmentKind.pdf).length;
    if (pdfCount >= kMaxPdfAttachments) {
      return AttachRejection.limitReached;
    }
  }

  return null;
}
