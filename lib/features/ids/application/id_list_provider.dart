import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/id_document.dart';
import '../../../core/storage/secure_document_store.dart';

final idListProvider =
    StateNotifierProvider<IdListController, List<IdDocument>>((ref) {
      final controller = IdListController();
      controller.loadDocuments();
      return controller;
    });

class IdListController extends StateNotifier<List<IdDocument>> {
  IdListController() : super([]);

  static const _storageKey = 'saved_id_documents';
  Future<void> _saveQueue = Future<void>.value();

  Future<void> loadDocuments() async {
    final saved = await SecureDocumentStore.readList(_storageKey);
    state = saved.map(_tryParse).whereType<IdDocument>().toList();
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

  IdDocument? _tryParse(String source) {
    try {
      return IdDocument.fromJson(source);
    } catch (_) {
      return null;
    }
  }
}
