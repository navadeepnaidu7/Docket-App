import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/attachment_store.dart';

/// Provides a single shared [AttachmentStore] instance for the app's lifetime.
///
/// Do NOT construct [AttachmentStore] directly at call sites or in temporary widgets.
/// [AttachmentStore] relies on its static write-serialisation queue and an
/// instance-level decrypted-bytes LRU cache. Maintaining a single shared instance
/// ensures that concurrent writes do not interleave and decrypted cache hits
/// persist properly across operations.
final attachmentStoreProvider =
    Provider<AttachmentStore>((ref) => AttachmentStore());
