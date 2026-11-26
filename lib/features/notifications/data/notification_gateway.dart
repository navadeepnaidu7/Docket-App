import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/reminder_planner.dart';

class PushNotice {
  const PushNotice({
    required this.ticketId,
    required this.channel,
    required this.title,
    required this.body,
  });
  final String ticketId, channel, title, body;
  static PushNotice? fromMessage(RemoteMessage message) {
    final id = message.data['ticketId'], channel = message.data['channel'];
    if (id is! String ||
        id.isEmpty ||
        !['booking_updates', 'journey_live'].contains(channel)) {
      return null;
    }
    return PushNotice(
      ticketId: id,
      channel: channel as String,
      title: message.notification?.title ?? 'Docket',
      body: message.notification?.body ?? '',
    );
  }
}

abstract class NotificationGateway {
  bool get pushAvailable;
  Stream<String> get tokenChanges;
  Stream<String> get taps;
  Stream<PushNotice> get foreground;
  Future<void> initialize();
  Future<String> timezone();
  Future<bool> permitted();
  Future<bool> requestPermission();
  Future<void> openSettings();
  Future<String?> token();
  Future<void> deleteToken();
  Future<List<int>> pendingIds();
  Future<void> schedule(PlannedReminder reminder, tz.Location zone);
  Future<void> cancel(int id);
  Future<void> show(PushNotice notice);
  Future<void> dispose();
}

class PluginNotificationGateway implements NotificationGateway {
  final _local = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  final _foreground = StreamController<PushNotice>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _push = false;
  @override
  bool get pushAvailable => _push;
  @override
  Stream<String> get taps => _taps.stream;
  @override
  Stream<PushNotice> get foreground => _foreground.stream;
  @override
  Stream<String> get tokenChanges => _tokens.stream;
  AndroidFlutterLocalNotificationsPlugin? get _android => _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  void _tap(String? id) {
    if (id != null && id.isNotEmpty) _taps.add(id);
  }

  @override
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    if (!Platform.isAndroid) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) => _tap(response.payload),
    );
    for (final channel in const [
      AndroidNotificationChannel(
        'trip_reminders',
        'Trip reminders',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'booking_updates',
        'Booking updates',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'journey_live',
        'Live journey',
        importance: Importance.defaultImportance,
      ),
    ]) {
      await _android?.createNotificationChannel(channel);
    }
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _tap(launch?.notificationResponse?.payload);
    }
    try {
      await Firebase.initializeApp();
      // Initialization never asks for permission. Only the explanation sheet can.
      _push = true;
      _subscriptions.add(
        // HTTP v1 requires the FCM token; the replacement API emits an FID.
        // ignore: deprecated_member_use
        FirebaseMessaging.instance.onTokenRefresh.listen(_tokens.add),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (m) => _tap(PushNotice.fromMessage(m)?.ticketId),
        ),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((m) {
          final notice = PushNotice.fromMessage(m);
          if (notice != null) _foreground.add(notice);
        }),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _tap(PushNotice.fromMessage(initial)?.ticketId);
    } catch (_) {
      _push = false; /* Unconfigured builds retain local reminders. */
    }
  }

  @override
  Future<String> timezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
  @override
  Future<bool> permitted() async =>
      await _android?.areNotificationsEnabled() ?? false;
  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;
  @override
  Future<void> openSettings() => const MethodChannel(
    'com.docket/notifications',
  ).invokeMethod<void>('openSettings');
  @override
  Future<String?> token() async =>
      // ignore: deprecated_member_use
      _push ? FirebaseMessaging.instance.getToken() : null;
  @override
  Future<void> deleteToken() async {
    // ignore: deprecated_member_use
    if (_push) await FirebaseMessaging.instance.deleteToken();
  }

  @override
  Future<List<int>> pendingIds() async =>
      (await _local.pendingNotificationRequests()).map((p) => p.id).toList();
  NotificationDetails _details(String channel, {String? tag}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          switch (channel) {
            'trip_reminders' => 'Trip reminders',
            'journey_live' => 'Live journey',
            _ => 'Booking updates',
          },
          icon: 'ic_notification',
          importance: channel == 'journey_live'
              ? Importance.defaultImportance
              : Importance.high,
          priority: channel == 'journey_live'
              ? Priority.defaultPriority
              : Priority.high,
          visibility: NotificationVisibility.private,
          tag: tag,
        ),
      );
  @override
  Future<void> schedule(PlannedReminder r, tz.Location zone) =>
      _local.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at, zone),
        notificationDetails: _details('trip_reminders'),
        payload: r.ticketId,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
  @override
  Future<void> cancel(int id) => _local.cancel(id: id);
  @override
  Future<void> show(PushNotice notice) => _local.show(
    // FCM uses Android id 0 with a tag for notification messages. Match both
    // so foreground and background deliveries replace each other.
    id: 0,
    title: notice.title,
    body: notice.body,
    payload: notice.ticketId,
    notificationDetails: _details(
      notice.channel,
      tag: '${notice.ticketId}:${notice.channel}',
    ),
  );
  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _tokens.close();
    await _taps.close();
    await _foreground.close();
  }
}
