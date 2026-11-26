import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/notification_preferences.dart';

final notificationPreferencesProvider =
    StateNotifierProvider<
      NotificationPreferencesController,
      NotificationPreferences
    >((ref) => NotificationPreferencesController());

class NotificationPreferencesController
    extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesController() : super(const NotificationPreferences()) {
    ready = _load();
  }
  static const key = 'notification_preferences_v1';
  late final Future<void> ready;
  bool serverDirty = false;
  int revision = 0;
  NotificationPreferences get value => state;
  Future<void> _writes = Future.value();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(key);
      serverDirty = prefs.getBool('${key}_dirty') ?? false;
      if (raw != null && mounted) {
        state = NotificationPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {
      /* Invalid settings fall back to defaults. */
    }
  }

  Future<void> set(
    NotificationPreferences next, {
    bool fromServer = false,
  }) async {
    await ready;
    revision++;
    if (!fromServer) serverDirty = true;
    state = next;
    await _persist();
  }

  Future<void> markSynced(int expectedRevision) async {
    if (revision != expectedRevision) return;
    serverDirty = false;
    await _persist();
  }

  Future<void> _persist() {
    final data = jsonEncode(state.toJson()), dirty = serverDirty;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, data);
      await prefs.setBool('${key}_dirty', dirty);
    });
    return _writes;
  }
}
