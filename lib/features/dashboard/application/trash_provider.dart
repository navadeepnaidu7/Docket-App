import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_document_store.dart';
import '../../../core/storage/document_record_decoder.dart';
import '../../ids/application/attachment_providers.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import 'wallet_order_provider.dart';

class TrashState {
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;

  const TrashState({required this.passports, required this.idDocs});

  TrashState copyWith({
    List<PassportProfile>? passports,
    List<IdDocument>? idDocs,
  }) {
    return TrashState(
      passports: passports ?? this.passports,
      idDocs: idDocs ?? this.idDocs,
    );
  }
}

class TrashController extends StateNotifier<TrashState> {
  TrashController(this.ref)
    : super(const TrashState(passports: [], idDocs: []));

  final Ref ref;

  static const _passportsKey = 'trash_passports';
  static const _idsKey = 'trash_ids';

  /// Completes when the initial read has finished. See [IdListController.loaded]
  /// -- trashed records still own their attachment files, so a sweep that ran
  /// before this settled would delete them and make restore lossy.
  late final Future<void> loaded;
  Future<void>? _loadFuture;

  /// The current trash contents, readable from outside the notifier.
  /// See [IdListController.documents] for why this exists.
  TrashState get contents => state;

  Future<void> loadTrash() => _loadFuture ??= _loadTrash();

  Future<List<String>> _readForStartup(String key) async {
    try {
      return await SecureDocumentStore.readList(key);
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _loadTrash() async {
    final lists = await Future.wait([
      _readForStartup(_passportsKey),
      _readForStartup(_idsKey),
    ]);
    if (!mounted) return;
    final passports = await decodeStoredRecords(
      lists[0],
      decodePassportRecords,
    );
    final ids = await decodeStoredRecords(lists[1], decodeIdRecords);
    if (!mounted) return;
    if (passports.hasInvalidRecords) {
      SecureDocumentStore.markUnreadable(_passportsKey);
    }
    if (ids.hasInvalidRecords) SecureDocumentStore.markUnreadable(_idsKey);
    state = TrashState(passports: passports.records, idDocs: ids.records);
  }

  Future<void> moveToTrash(Object item) async {
    await loaded;
    if (!mounted) return;
    if (item is PassportProfile) {
      final updated = [...state.passports, item];
      state = state.copyWith(passports: updated);
      await SecureDocumentStore.writeList(
        _passportsKey,
        updated.map((p) => p.toJson()).toList(),
      );
    } else if (item is IdDocument) {
      final updated = [...state.idDocs, item];
      state = state.copyWith(idDocs: updated);
      await SecureDocumentStore.writeList(
        _idsKey,
        updated.map((d) => d.toJson()).toList(),
      );
    }
  }

  Future<void> restoreItem(Object item, WidgetRef ref) async {
    await loaded;
    if (!mounted) return;
    if (item is PassportProfile) {
      // 1. Remove from trash
      final updated = state.passports.where((p) => p.id != item.id).toList();
      state = state.copyWith(passports: updated);
      await SecureDocumentStore.writeList(
        _passportsKey,
        updated.map((p) => p.toJson()).toList(),
      );
      // 2. Add back to active passports
      ref.read(passportListProvider.notifier).addPassport(item);
      // 3. Add to order
      ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(item.id);
    } else if (item is IdDocument) {
      // 1. Remove from trash
      final updated = state.idDocs.where((d) => d.id != item.id).toList();
      state = state.copyWith(idDocs: updated);
      await SecureDocumentStore.writeList(
        _idsKey,
        updated.map((d) => d.toJson()).toList(),
      );
      // 2. Add back to active IDs
      ref.read(idListProvider.notifier).addDocument(item);
      // 3. Add to order
      ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(item.id);
    }
  }

  Future<void> permanentlyDeleteItem(Object item) async {
    await loaded;
    if (!mounted) return;
    if (item is PassportProfile) {
      final updated = state.passports.where((p) => p.id != item.id).toList();
      state = state.copyWith(passports: updated);
      await SecureDocumentStore.writeList(
        _passportsKey,
        updated.map((p) => p.toJson()).toList(),
      );
    } else if (item is IdDocument) {
      final updated = state.idDocs.where((d) => d.id != item.id).toList();
      state = state.copyWith(idDocs: updated);
      await SecureDocumentStore.writeList(
        _idsKey,
        updated.map((d) => d.toJson()).toList(),
      );

      // Clean up encrypted attachment files for permanently deleted ID document
      try {
        await ref.read(attachmentStoreProvider).deleteAllFor(item.id);
      } catch (_) {
        // Swallowed so storage cleanup failures do not prevent trash item removal
      }
    }
  }
}

final trashProvider = StateNotifierProvider<TrashController, TrashState>((ref) {
  final controller = TrashController(ref);
  controller.loaded = controller.loadTrash();
  return controller;
});
