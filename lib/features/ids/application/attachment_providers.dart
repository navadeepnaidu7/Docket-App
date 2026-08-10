import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/attachment_store.dart';
import '../../../core/storage/secure_document_store.dart';
import '../../dashboard/application/trash_provider.dart';
import '../domain/id_document.dart';
import 'id_list_provider.dart';

/// Provides a single shared [AttachmentStore] instance for the app's lifetime.
///
/// Do NOT construct [AttachmentStore] directly at call sites or in temporary widgets.
/// [AttachmentStore] relies on its static write-serialisation queue and an
/// instance-level decrypted-bytes LRU cache. Maintaining a single shared instance
/// ensures that concurrent writes do not interleave and decrypted cache hits
/// persist properly across operations.
final attachmentStoreProvider =
    Provider<AttachmentStore>((ref) => AttachmentStore());

/// Deletes attachment files that no record points at any more.
///
/// A backstop for bytes stranded by a crash between writing a file and saving
/// the record, so it is deliberately timid. Three things have to hold before it
/// deletes anything, because every one of them would otherwise turn this into a
/// data-loss bug rather than a cleanup:
///
///  - Both the live list and the trash have finished loading. Both start empty,
///    and sweeping against an empty list means deleting every attachment.
///  - Neither underlying key is marked unreadable. A failed decrypt surfaces as
///    an empty list, which is indistinguishable from "no documents" here.
///  - Trashed records count as live. They still own their files; deleting them
///    would make restore lossy, which is the whole reason trash keeps them.
Future<void> sweepAttachmentOrphans(WidgetRef ref) async {
  try {
    await ref.read(idListProvider.notifier).loaded;
    await ref.read(trashProvider.notifier).loaded;
  } catch (_) {
    // A load that threw leaves us with no trustworthy picture of what exists.
    return;
  }

  if (SecureDocumentStore.isUnreadable('saved_id_documents') ||
      SecureDocumentStore.isUnreadable('trash_ids')) {
    return;
  }

  final List<IdDocument> known = <IdDocument>[
    ...ref.read(idListProvider),
    ...ref.read(trashProvider).idDocs,
  ];

  try {
    await ref.read(attachmentStoreProvider).sweepOrphans(known);
  } catch (_) {
    // Cleanup is best effort; it must never break start-up.
  }
}
