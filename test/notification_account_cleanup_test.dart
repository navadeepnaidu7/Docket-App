import 'dart:convert';
import 'package:docket/features/auth/application/account_cleanup.dart';
import 'package:docket/features/dashboard/presentation/settings/delete_account_sheet.dart';
import 'package:docket/features/tickets/data/api_session_store.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'cleanup uses the documented order and continues after local failures',
    () async {
      final order = <String>[];
      Future<void> step(String name, {bool fail = false}) async {
        order.add(name);
        if (fail) throw StateError('local failure');
      }

      await cleanupAccount(
        unregisterPush: () => step('push'),
        clearSession: () => step('session'),
        clearOfflinePasses: () => step('offline', fail: true),
        clearPendingPasses: () => step('pending'),
        clearIdentity: () => step('identity'),
        cancelServerReminders: () => step('reminders'),
        googleSignOut: () => step('google'),
      );
      expect(order, [
        'push',
        'session',
        'offline',
        'pending',
        'identity',
        'reminders',
        'google',
      ]);
    },
  );
  test(
    'account endpoint requires exactly 204 and preserves local session on failure',
    () async {
      final store = ApiSessionStore.memory();
      await store.write(
        const ApiTokens(accessToken: 'access', refreshToken: 'refresh'),
      );
      var status = 500;
      final api = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/v1/me');
          expect(jsonDecode(request.body), {'confirm': 'DELETE'});
          return http.Response('', status);
        }),
      );
      for (final code in [500, 200]) {
        status = code;
        await expectLater(api.deleteAccount(), throwsException);
        expect((await store.read())!.accessToken, 'access');
      }
      status = 204;
      await api.deleteAccount();
      expect(
        await store.read(),
        isNotNull,
      ); // AuthController owns post-204 cleanup.
    },
  );
  test('device and preference endpoints send contract payloads', () async {
    final store = ApiSessionStore.memory();
    await store.write(
      const ApiTokens(accessToken: 'access', refreshToken: 'refresh'),
    );
    final requests = <http.Request>[];
    final api = DocketApiClient(
      baseUrl: 'https://api.test',
      session: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.method == 'GET' ? '{"bookingUpdates":true}' : '',
          request.method == 'DELETE' ? 204 : 200,
        );
      }),
    );
    await api.registerDevice(token: 'token', timezone: 'Asia/Kolkata');
    await api.unregisterDevice('token');
    expect(await api.fetchNotificationPreferences(), {'bookingUpdates': true});
    await api.putNotificationPreferences({'bookingUpdates': false});
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /v1/devices',
      'DELETE /v1/devices',
      'GET /v1/me/notification-preferences',
      'PUT /v1/me/notification-preferences',
    ]);
    expect(jsonDecode(requests[0].body), {
      'token': 'token',
      'platform': 'android',
      'deviceLabel': 'Docket Android',
      'timezone': 'Asia/Kolkata',
    });
    expect(jsonDecode(requests[1].body), {'token': 'token'});
  });
  test('developer session marker survives refresh writes', () async {
    final store = ApiSessionStore.memory();
    await store.write(
      const ApiTokens(accessToken: 'a', refreshToken: 'r'),
      developerSession: true,
    );
    await store.write(const ApiTokens(accessToken: 'b', refreshToken: 'r'));
    expect((await store.readSession())!.developerSession, isTrue);
  });
  testWidgets(
    'deletion requires typed DELETE, shows kept records and retains failure',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteAccountSheet(
              onDelete: () async {
                calls++;
                throw StateError('offline');
              },
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Passports, IDs, payment cards'),
        findsOneWidget,
      );
      FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete account'),
      );
      expect(button().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();
      expect(button().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Delete account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Nothing was removed'), findsOneWidget);
    },
  );
}
