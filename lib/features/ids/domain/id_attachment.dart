import 'dart:math';

enum IdAttachmentKind { image, pdf }

/// Generates a unique attachment identifier using timestamp and random suffix.
String _generateAttachmentId() {
  final rand = Random();
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '$ts${rand.nextInt(99999).toString().padLeft(5, '0')}';
}

/// Metadata model for a single file attachment associated with an ID document.
///
/// Attachment files are stored encrypted on disk in app-private storage.
/// To remain safe across iOS container UUID rotations and app reinstalls,
/// [fileName] must always store a relative filename stem (e.g. `<id>.enc`)
/// rather than an absolute filesystem path.
class IdAttachment {
  IdAttachment({
    String? id,
    required this.kind,
    required this.fileName,
    required this.sizeBytes,
    DateTime? addedAt,
    this.source = '',
  })  : id = id ?? _generateAttachmentId(),
        addedAt = addedAt ?? DateTime.now();

  final String id;
  final IdAttachmentKind kind;
  final String fileName;
  final int sizeBytes;
  final DateTime addedAt;
  final String source;

  IdAttachment copyWith({
    String? id,
    IdAttachmentKind? kind,
    String? fileName,
    int? sizeBytes,
    DateTime? addedAt,
    String? source,
  }) {
    return IdAttachment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.name,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'source': source,
      };

  factory IdAttachment.fromMap(Map<String, dynamic> map) {
    final rawKind = map['kind'];
    final kind = IdAttachmentKind.values.firstWhere(
      (e) => e.name == rawKind,
      orElse: () => IdAttachmentKind.image,
    );

    final rawAddedAt = map['addedAt'];
    DateTime addedAt;
    if (rawAddedAt is String) {
      addedAt = DateTime.tryParse(rawAddedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    } else {
      addedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final rawSizeBytes = map['sizeBytes'];
    final sizeBytes = rawSizeBytes is int
        ? rawSizeBytes
        : (rawSizeBytes is num ? rawSizeBytes.toInt() : 0);

    return IdAttachment(
      id: map['id'] as String?,
      kind: kind,
      fileName: (map['fileName'] as String?) ?? '',
      sizeBytes: sizeBytes,
      addedAt: addedAt,
      source: (map['source'] as String?) ?? '',
    );
  }
}
