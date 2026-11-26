import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/storage/secure_document_store.dart';
import '../../tickets/data/docket_api_client.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../data/notification_gateway.dart';
import '../domain/device_registration.dart';
import '../domain/notification_preferences.dart';
import '../domain/reminder_planner.dart';
import 'notification_preferences_provider.dart';

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => PluginNotificationGateway(),
);
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.read(notificationGatewayProvider));
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Serializes reconciliation and account departure, so an in-flight registration
/// cannot finish after unregistration and silently re-enable the old account.
class NotificationService {
  NotificationService(this.gateway);
  final NotificationGateway gateway;
  final _storage = const FlutterSecureStorage(aOptions: kDocketAndroidOptions);
  Future<void> _tail = Future.value();
  Future<void>? _initialization;
  String? _leavingAccount, _preferencesAccount;
  String? _token;
  String? _lastUploaded;
  bool ready = false, permitted = false;
  bool _suppressServerReminders = false;
  String timezone = 'UTC';
  DeviceRegistration? _registration;
  final Map<String, DateTime> _firstSeen = {};
  final Map<int, String> _scheduled = {};
  final Set<int> _serverReminderIds = {};
  static const _registrationKey = 'notification_registration_v1';
  static const _firstSeenKey = 'notification_first_seen_v1';
  static const _scheduledKey = 'notification_scheduled_v1';
  static const _serverIdsKey = 'notification_server_reminders_v1';

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await gateway.initialize();
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_firstSeenKey) ?? '{}') as Map;
      for (final e in raw.entries) {
        final time = DateTime.tryParse('${e.value}');
        if (time != null) _firstSeen['${e.key}'] = time;
      }
      final scheduled =
          jsonDecode(prefs.getString(_scheduledKey) ?? '{}') as Map;
      for (final e in scheduled.entries) {
        _scheduled[int.parse('${e.key}')] = '${e.value}';
      }
      _serverReminderIds.addAll(
        (prefs.getStringList(_serverIdsKey) ?? []).map(int.parse),
      );
    } catch (_) {
      /* Reconciliation repairs invalid metadata. */
    }
    try {
      final raw = await _storage.read(key: _registrationKey);
      if (raw != null) {
        _registration = DeviceRegistration.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {}
    ready = true;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.catchError((Object _) {}).then((_) => operation());
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> reconcile({
    required List<WalletPassItem> passes,
    required NotificationPreferencesController preferences,
    required String? account,
    required DocketApiClient? api,
    required bool serverPasses,
  }) => _enqueue(() async {
    await initialize();
    await preferences.ready;
    timezone = await gateway.timezone();
    final zone = timezone == 'UTC' ? tz.UTC : tz.getLocation(timezone);
    permitted = await gateway.permitted();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    for (final item in passes) {
      _firstSeen.putIfAbsent(item.id, () => now);
    }
    await prefs.setString(
      _firstSeenKey,
      jsonEncode(
        _firstSeen.map((id, at) => MapEntry(id, at.toUtc().toIso8601String())),
      ),
    );
    final desired = permitted && !(serverPasses && _suppressServerReminders)
        ? planReminders(
            passes: passes,
            preferences: preferences.value,
            firstSeen: _firstSeen,
            now: now,
            deviceZone: zone,
          )
        : <PlannedReminder>[];
    final pending = (await gateway.pendingIds()).toSet();
    final wanted = desired.map((r) => r.id).toSet();
    // Pending requests belong to Docket reminders only; foreground pushes are
    // immediate and are deliberately excluded from this list.
    for (final id in {...pending, ..._scheduled.keys}.difference(wanted)) {
      await gateway.cancel(id);
      _scheduled.remove(id);
      _serverReminderIds.remove(id);
    }
    for (final reminder in desired) {
      if (!pending.contains(reminder.id) ||
          _scheduled[reminder.id] != reminder.fingerprint) {
        await gateway.schedule(reminder, zone);
        _scheduled[reminder.id] = reminder.fingerprint;
      }
      if (serverPasses) _serverReminderIds.add(reminder.id);
    }
    await _saveScheduled(prefs);
    if (account == null || account == _leavingAccount || api == null) return;
    _leavingAccount = null;
    if (permitted && gateway.pushAvailable) {
      try {
        final token = _token ?? await gateway.token();
        if (token != null &&
            (_registration?.isStale(account, token, timezone, now) ?? true)) {
          await api.registerDevice(token: token, timezone: timezone);
          _registration = DeviceRegistration(account, token, timezone, now);
          await _storage.write(
            key: _registrationKey,
            value: jsonEncode(_registration!.toJson()),
          );
        }
      } catch (_) {
        /* Preference sync is independent of FCM availability. */
      }
    }
    // GET once per account on open, unless local changes are waiting to upload.
    final revision = preferences.revision;
    if (_preferencesAccount != account && !preferences.serverDirty) {
      final remote = await api.fetchNotificationPreferences();
      if (revision == preferences.revision) {
        final local = preferences.value;
        final merged = NotificationPreferences.fromJson({
          ...local.toJson(),
          ...remote,
        });
        await preferences.set(
          local.copyWith(
            bookingUpdates: remote['bookingUpdates'] as bool?,
            journeyLive: remote['journeyLive'] as bool?,
            quietEnabled: merged.quietEnabled,
            quietStart: merged.quietStart,
            quietEnd: merged.quietEnd,
          ),
          fromServer: true,
        );
      }
    }
    _preferencesAccount = account;
    final uploadRevision = preferences.revision;
    final document = preferences.value.serverJson(timezone);
    final fingerprint = '$account|${jsonEncode(document)}';
    if (_lastUploaded != fingerprint || preferences.serverDirty) {
      await api.putNotificationPreferences(document);
      _lastUploaded = fingerprint;
      await preferences.markSynced(uploadRevision);
    }
  });

  void tokenRefreshed(String token) {
    _token = token;
  }

  Future<void> _saveScheduled(SharedPreferences prefs) async {
    await prefs.setString(
      _scheduledKey,
      jsonEncode(_scheduled.map((id, value) => MapEntry('$id', value))),
    );
    await prefs.setStringList(
      _serverIdsKey,
      _serverReminderIds.map((id) => '$id').toList(),
    );
  }

  /// Called before logout clears credentials; a failed network unregister must
  /// not trap someone in their account. Deleting the FCM token also invalidates
  /// delivery when offline.
  Future<void> leaveAccount(
    String? account,
    DocketApiClient? api, {
    bool deleted = false,
  }) async {
    _leavingAccount = account;
    _suppressServerReminders = true;
    await _enqueue(() async {
      if (!ready) {
        try {
          await initialize();
        } catch (_) {}
      }
      final registration = _registration;
      if (!deleted && registration != null && api != null) {
        try {
          await api.unregisterDevice(registration.token);
        } catch (_) {}
      }
      try {
        await gateway.deleteToken();
      } catch (_) {}
      _token = null;
      _registration = null;
      _preferencesAccount = null;
      _lastUploaded = null;
      try {
        await _storage.delete(key: _registrationKey);
      } catch (_) {}
    });
  }

  Future<void> cancelServerReminders() => _enqueue(() async {
    for (final id in _serverReminderIds.toList()) {
      try {
        await gateway.cancel(id);
      } catch (_) {}
      _scheduled.remove(id);
    }
    _serverReminderIds.clear();
    await _saveScheduled(await SharedPreferences.getInstance());
  });
  void enterAccount(String? account) {
    if (account != null) _suppressServerReminders = false;
    if (account != null && account == _leavingAccount) _leavingAccount = null;
  }

  Future<void> dispose() => gateway.dispose();
}
