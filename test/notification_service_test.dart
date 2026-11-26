import 'dart:convert';
import 'package:docket/features/notifications/application/notification_service.dart';
import 'package:docket/features/notifications/application/notification_preferences_provider.dart';
import 'package:docket/features/tickets/data/api_session_store.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'support/fake_notification_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'scheduler is idempotent, repairs lost pending requests, cancels removed passes; no launch prompt',
    () async {
      final gateway = FakeNotificationGateway()..pushAvailable = false;
      final service = NotificationService(gateway),
          preferences = NotificationPreferencesController();
      final item = walletPassItemFromJson({
        'kind': 'train',
        'train': {
          'id': 'train',
          'status': 'active',
          'departAt': DateTime.now()
              .add(const Duration(days: 2))
              .toUtc()
              .toIso8601String(),
        },
      });
      Future<void> sync(List<WalletPassItem> passes) => service.reconcile(
        passes: passes,
        preferences: preferences,
        account: null,
        api: null,
        serverPasses: false,
      );
      await sync([item]);
      await sync([item]);
      expect(gateway.scheduled, hasLength(1));
      expect(gateway.scheduleCalls, 1);
      expect(gateway.permissionRequests, 0);
      gateway.scheduled.clear();
      await sync([item]);
      expect(gateway.scheduleCalls, 2);
      await sync([]);
      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelled, hasLength(1));
      preferences.dispose();
      await service.dispose();
    },
  );
  test(
    'registration skips no-account sessions, refreshes token/zone/account, unregisters before logout',
    () async {
      final gateway = FakeNotificationGateway();
      final service = NotificationService(gateway),
          preferences = NotificationPreferencesController();
      final store = ApiSessionStore.memory();
      await store.write(const ApiTokens(accessToken: 'a', refreshToken: 'r'));
      final requests = <String>[];
      final api = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient((r) async {
          expect(await store.read(), isNotNull);
          requests.add('${r.method} ${r.url.path}');
          return http.Response(r.method == 'GET' ? '{}' : '', 200);
        }),
      );
      Future<void> sync(String? account) => service.reconcile(
        passes: [],
        preferences: preferences,
        account: account,
        api: api,
        serverPasses: true,
      );
      await sync(null);
      expect(requests, isEmpty);
      await sync('a');
      await sync('a');
      expect(requests.where((s) => s == 'POST /v1/devices'), hasLength(1));
      service.tokenRefreshed('new-token');
      await sync('a');
      gateway.zone = 'Asia/Kolkata';
      await sync('a');
      await sync('b');
      expect(requests.where((s) => s == 'POST /v1/devices'), hasLength(4));
      await service.leaveAccount('b', api);
      expect(requests.last, 'DELETE /v1/devices');
      expect(gateway.tokenDeletes, 1);
      await store.clear();
      await sync(null);
      expect(requests.last, 'DELETE /v1/devices');
      preferences.dispose();
      await service.dispose();
    },
  );
  test(
    'unavailable Firebase still schedules locally and uploads preferences; retries offline edits',
    () async {
      final gateway = FakeNotificationGateway()..pushAvailable = false;
      final service = NotificationService(gateway),
          preferences = NotificationPreferencesController();
      await preferences.ready;
      await preferences.set(preferences.value.copyWith(bookingUpdates: false));
      final store = ApiSessionStore.memory();
      await store.write(const ApiTokens(accessToken: 'a', refreshToken: 'r'));
      var fail = true;
      final api = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient((r) async {
          expect(r.method, 'PUT');
          expect(jsonDecode(r.body)['bookingUpdates'], isFalse);
          return http.Response('', fail ? 500 : 200);
        }),
      );
      Future<void> sync() => service.reconcile(
        passes: [],
        preferences: preferences,
        account: 'a',
        api: api,
        serverPasses: true,
      );
      await expectLater(sync(), throwsException);
      expect(preferences.serverDirty, isTrue);
      fail = false;
      await sync();
      expect(preferences.serverDirty, isFalse);
      preferences.dispose();
      await service.dispose();
    },
  );
}
