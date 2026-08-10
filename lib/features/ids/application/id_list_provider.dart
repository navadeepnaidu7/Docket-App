import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_document_store.dart';
import '../../dashboard/application/wallet_loading_provider.dart';
import '../domain/attachment_limits.dart';
import '../domain/id_attachment.dart';
import '../domain/id_document.dart';
import 'attachment_providers.dart';

final idListProvider =
    StateNotifierProvider<IdListController, List<IdDocument>>((ref) {
      final controller = IdListController(ref);
      controller.loaded = controller.loadDocuments();
      return controller;
    });

class IdListController extends StateNotifier<List<IdDocument>> {
  IdListController(this.ref) : super([]);
  final Ref ref;

  static const _storageKey = 'saved_id_documents';
  Future<void> _saveQueue = Future<void>.value();

  /// Completes when the initial read has finished, successfully or not.
  ///
  /// Anything that reasons about "every document that exists" -- the attachment
  /// orphan sweep in particular -- has to wait on this. Acting on the empty
  /// list this controller starts with would read as "there are no documents"
  /// and delete real files.
  late final Future<void> loaded;

  Future<void> loadDocuments() async {
    final List<String> saved;
    try {
      saved = await SecureDocumentStore.readList(_storageKey);
    } catch (_) {
      // See PassportListController.loadPassports: fail visible-but-harmless
      // rather than letting an empty list get saved over real documents.
      ref.read(idLoadingProvider.notifier).state = false;
      return;
    }
    state = saved.map(_tryParse).whereType<IdDocument>().toList();
    ref.read(idLoadingProvider.notifier).state = false;
  }

  Future<void> _save(List<IdDocument> docs) async {
    await SecureDocumentStore.writeList(
      _storageKey,
      docs.map((d) => d.toJson()).toList(),
    );
  }

  void _queueSave(List<IdDocument> docs) {
    _saveQueue = _saveQueue.then((_) => _save(docs));
  }

  void addDocument(IdDocument doc) {
    final next = [doc, ...state];
    state = next;
    _queueSave(next);
  }

  void removeDocument(String id) {
    final next = state.where((d) => d.id != id).toList();
    state = next;
    _queueSave(next);
  }

  void updateDocument(int index, IdDocument doc) {
    if (index < 0 || index >= state.length) return;
    final next = [...state];
    next[index] = doc;
    state = next;
    _queueSave(next);
  }

  /// Adds a file attachment to an existing ID document.
  ///
  /// Enforces limits before performing file I/O to avoid orphaned files on disk.
  /// Writes encrypted bytes first, and only updates document metadata and persists
  /// after the file write completes cleanly.
  Future<AttachResult> addAttachment(
    String docId,
    File file, {
    String source = 'picker',
  }) async {
    // (a) Resolve kind from file extension
    final kind = kindForExtension(file.path);
    if (kind == null) {
      return const AttachFailure(
        AttachRejection.unsupportedType,
        'Unsupported file format.',
      );
    }

    // (b) Look up document and check limits before touching disk
    final docIndex = state.indexWhere((d) => d.id == docId);
    if (docIndex == -1) {
      return const AttachFailure(
        AttachRejection.ioError,
        'Document not found.',
      );
    }

    final doc = state[docIndex];
    final int sizeBytes;
    try {
      sizeBytes = await file.length();
    } catch (_) {
      return const AttachFailure(
        AttachRejection.ioError,
        'Unable to read attachment file.',
      );
    }

    final rejection = rejectionFor(
      existing: doc.attachments,
      incoming: kind,
      sizeBytes: sizeBytes,
    );

    if (rejection != null) {
      final String message;
      switch (rejection) {
        case AttachRejection.limitReached:
          message = 'Attachment limit reached for this file type.';
          break;
        case AttachRejection.tooLarge:
          message = 'File size exceeds maximum allowed 25 MB limit.';
          break;
        case AttachRejection.unsupportedType:
          message = 'Unsupported file format.';
          break;
        case AttachRejection.ioError:
          message = 'File access error.';
          break;
      }
      return AttachFailure(rejection, message);
    }

    // (c) Save encrypted file to disk via single shared AttachmentStore provider
    final IdAttachment savedAttachment;
    try {
      final store = ref.read(attachmentStoreProvider);
      savedAttachment = await store.save(
        docId: docId,
        file: file,
        kind: kind,
        source: source,
      );
    } catch (_) {
      return const AttachFailure(
        AttachRejection.ioError,
        'Failed to save attachment to storage.',
      );
    }

    // (d) Only after file write succeeds, update metadata row and persist
    final latestIndex = state.indexWhere((d) => d.id == docId);
    if (latestIndex == -1) {
      // The document was deleted while the encrypted write was in flight, so
      // the file just landed with no record to reference it. Drop it now
      // rather than leaving it for the startup sweep to find.
      try {
        await ref.read(attachmentStoreProvider).delete(docId, savedAttachment);
      } catch (_) {
        // Best effort; sweepOrphans is the backstop.
      }
      return const AttachFailure(
        AttachRejection.ioError,
        'Document was removed before save completed.',
      );
    }

    final latestDoc = state[latestIndex];
    final updatedDoc = latestDoc.copyWith(
      attachments: [...latestDoc.attachments, savedAttachment],
    );

    updateDocument(latestIndex, updatedDoc);
    return AttachSuccess(savedAttachment);
  }

  /// Removes an attachment from an ID document.
  ///
  /// Removes the metadata row and persists first, then deletes the encrypted file.
  Future<void> removeAttachment(String docId, String attachmentId) async {
    final docIndex = state.indexWhere((d) => d.id == docId);
    if (docIndex == -1) return;

    final doc = state[docIndex];
    final attachmentIndex =
        doc.attachments.indexWhere((a) => a.id == attachmentId);
    if (attachmentIndex == -1) return;

    final targetAttachment = doc.attachments[attachmentIndex];
    final updatedAttachments =
        doc.attachments.where((a) => a.id != attachmentId).toList();
    final updatedDoc = doc.copyWith(attachments: updatedAttachments);

    // Remove metadata row and queue persist first
    updateDocument(docIndex, updatedDoc);

    // Delete encrypted file from disk via store
    try {
      final store = ref.read(attachmentStoreProvider);
      await store.delete(docId, targetAttachment);
    } catch (_) {
      // Swallowed so disk cleanup failures do not surface unhandled to UI
    }
  }

  IdDocument? _tryParse(String source) {
    try {
      return IdDocument.fromJson(source);
    } catch (_) {
      return null;
    }
  }
}
