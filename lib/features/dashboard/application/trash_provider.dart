import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../ids/application/id_list_provider.dart';
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
  TrashController() : super(const TrashState(passports: [], idDocs: []));

  static const _passportsKey = 'trash_passports';
  static const _idsKey = 'trash_ids';

  Future<void> loadTrash() async {
    final prefs = await SharedPreferences.getInstance();
    final pData = prefs.getStringList(_passportsKey) ?? [];
    final idData = prefs.getStringList(_idsKey) ?? [];

    state = TrashState(
      passports: pData.map((s) => PassportProfile.fromJson(s)).toList(),
      idDocs: idData.map((s) => IdDocument.fromJson(s)).toList(),
    );
  }

  Future<void> moveToTrash(Object item) async {
    final prefs = await SharedPreferences.getInstance();
    if (item is PassportProfile) {
      final updated = [...state.passports, item];
      state = state.copyWith(passports: updated);
      await prefs.setStringList(_passportsKey, updated.map((p) => p.toJson()).toList());
    } else if (item is IdDocument) {
      final updated = [...state.idDocs, item];
      state = state.copyWith(idDocs: updated);
      await prefs.setStringList(_idsKey, updated.map((d) => d.toJson()).toList());
    }
  }

  Future<void> restoreItem(Object item, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    if (item is PassportProfile) {
      // 1. Remove from trash
      final updated = state.passports.where((p) => p.id != item.id).toList();
      state = state.copyWith(passports: updated);
      await prefs.setStringList(_passportsKey, updated.map((p) => p.toJson()).toList());
      // 2. Add back to active passports
      ref.read(passportListProvider.notifier).addPassport(item);
      // 3. Add to order
      ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(item.id);
    } else if (item is IdDocument) {
      // 1. Remove from trash
      final updated = state.idDocs.where((d) => d.id != item.id).toList();
      state = state.copyWith(idDocs: updated);
      await prefs.setStringList(_idsKey, updated.map((d) => d.toJson()).toList());
      // 2. Add back to active IDs
      ref.read(idListProvider.notifier).addDocument(item);
      // 3. Add to order
      ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(item.id);
    }
  }

  Future<void> permanentlyDeleteItem(Object item) async {
    final prefs = await SharedPreferences.getInstance();
    if (item is PassportProfile) {
      final updated = state.passports.where((p) => p.id != item.id).toList();
      state = state.copyWith(passports: updated);
      await prefs.setStringList(_passportsKey, updated.map((p) => p.toJson()).toList());
    } else if (item is IdDocument) {
      final updated = state.idDocs.where((d) => d.id != item.id).toList();
      state = state.copyWith(idDocs: updated);
      await prefs.setStringList(_idsKey, updated.map((d) => d.toJson()).toList());
    }
  }
}

final trashProvider = StateNotifierProvider<TrashController, TrashState>((ref) {
  final controller = TrashController();
  controller.loadTrash();
  return controller;
});
