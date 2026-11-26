import 'dart:convert';
import 'package:docket/features/notifications/application/notification_preferences_provider.dart';
import 'package:docket/features/notifications/domain/notification_preferences.dart';
import 'package:docket/features/notifications/domain/device_registration.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'round trips local preferences; server payload excludes local settings',
    () {
      final original = NotificationPreferences(
        tripReminders: false,
        bookingUpdates: false,
        journeyLive: false,
        quietStart: 1260,
        quietEnd: 480,
        promptDismissed: true,
        leads: {...NotificationPreferences.defaultLeads, PassKind.movie: 30},
      );
      final restored = NotificationPreferences.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), original.toJson());
      expect(restored.serverJson('Asia/Kolkata'), {
        'bookingUpdates': false,
        'journeyLive': false,
        'quietHours': {'enabled': true, 'start': '21:00', 'end': '08:00'},
        'timezone': 'Asia/Kolkata',
      });
    },
  );
  test('invalid values fall back to defaults; explicit off stays off', () {
    final p = NotificationPreferences.fromJson({
      'quietHours': {'start': '25:10', 'end': 'abc'},
      'leads': {'movie': -1, 'train': 0},
      'tripReminders': 'true',
    });
    expect(p.quietStart, 1350);
    expect(p.quietEnd, 420);
    expect(p.leads[PassKind.movie], 120);
    expect(p.leads[PassKind.train], 0);
    expect(p.tripReminders, isTrue);
  });
  test('persists dismissal and dirty changes across controllers', () async {
    SharedPreferences.setMockInitialValues({});
    final c = NotificationPreferencesController();
    await c.ready;
    await c.set(c.value.copyWith(promptDismissed: true, journeyLive: false));
    final loaded = NotificationPreferencesController();
    await loaded.ready;
    expect(loaded.value.promptDismissed, isTrue);
    expect(loaded.value.journeyLive, isFalse);
    expect(loaded.serverDirty, isTrue);
    await loaded.markSynced(loaded.revision - 1);
    expect(loaded.serverDirty, isTrue);
    await loaded.markSynced(loaded.revision);
    expect(loaded.serverDirty, isFalse);
    c.dispose();
    loaded.dispose();
  });
  test(
    'registration expires at seven days and when identity/token/zone changes',
    () {
      final now = DateTime.utc(2027);
      final r = DeviceRegistration('a', 'token', 'Asia/Kolkata', now);
      expect(
        r.isStale(
          'a',
          'token',
          'Asia/Kolkata',
          now.add(const Duration(days: 7)).subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        r.isStale(
          'a',
          'token',
          'Asia/Kolkata',
          now.add(const Duration(days: 7)),
        ),
        isTrue,
      );
      expect(r.isStale('b', 'token', 'Asia/Kolkata', now), isTrue);
      expect(r.isStale('a', 'new', 'Asia/Kolkata', now), isTrue);
      expect(r.isStale('a', 'token', 'Europe/London', now), isTrue);
      expect(
        r.isStale(
          'a',
          'token',
          'Asia/Kolkata',
          now.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(DeviceRegistration.fromJson(r.toJson())!.toJson(), r.toJson());
    },
  );
}
