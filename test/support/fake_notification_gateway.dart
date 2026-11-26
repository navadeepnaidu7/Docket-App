import 'package:docket/features/notifications/data/notification_gateway.dart';
import 'package:docket/features/notifications/domain/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeNotificationGateway implements NotificationGateway {
  @override
  bool pushAvailable = true;
  bool allowed = true;
  String zone = 'UTC';
  String? fcmToken = 'fcm-token';
  int permissionRequests = 0, tokenDeletes = 0;
  final scheduled = <int, PlannedReminder>{};
  final cancelled = <int>[];
  final shown = <PushNotice>[];
  int scheduleCalls = 0;
  @override
  Stream<String> get taps => const Stream.empty();
  @override
  Stream<String> get tokenChanges => const Stream.empty();
  @override
  Stream<PushNotice> get foreground => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<String> timezone() async => zone;
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> openSettings() async {}
  @override
  Future<String?> token() async => fcmToken;
  @override
  Future<void> deleteToken() async {
    tokenDeletes++;
  }

  @override
  Future<List<int>> pendingIds() async => scheduled.keys.toList();
  @override
  Future<void> schedule(PlannedReminder reminder, tz.Location zone) async {
    scheduled[reminder.id] = reminder;
    scheduleCalls++;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> show(PushNotice notice) async {
    shown.add(notice);
  }

  @override
  Future<void> dispose() async {}
}
