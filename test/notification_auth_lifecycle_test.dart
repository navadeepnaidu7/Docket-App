import 'dart:convert';
import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/auth/application/auth_session_provider.dart';
import 'package:docket/features/auth/application/google_auth_gateway.dart';
import 'package:docket/features/notifications/application/notification_service.dart';
import 'package:docket/features/tickets/application/api_providers.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/application/pending_pass_queue.dart';
import 'package:docket/features/tickets/data/api_session_store.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:docket/features/tickets/data/pass_offline_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_notification_gateway.dart';

class _Store extends ApiSessionStore {
  _Store(this.events) : super.memory();
  final List<String> events;
  @override
  Future<void> clear() async {
    events.add('session');
    await super.clear();
  }
}

class _Notifications extends NotificationService {
  _Notifications(this.events, this.store) : super(FakeNotificationGateway());
  final List<String> events;
  final ApiSessionStore store;
  @override
  Future<void> leaveAccount(
    String? account,
    DocketApiClient? api, {
    bool deleted = false,
  }) async {
    expect(await store.read(), isNotNull);
    events.add('push');
  }

  @override
  Future<void> cancelServerReminders() async {
    expect(await store.read(), isNull);
    events.add('reminders');
  }
}

class _Offline extends PassOfflineStore {
  _Offline(this.events);
  final List<String> events;
  @override
  Future<void> clearAll() async {
    events.add('offline');
  }
}

class _Pending extends PendingPassQueue {
  _Pending(this.events);
  final List<String> events;
  @override
  List<PendingPass> build() => [];
  @override
  Future<void> clearAll() async {
    events.add('pending');
  }
}

class _Google implements GoogleAuthGateway {
  _Google(this.events);
  final List<String> events;
  @override
  Future<String?> signIn() async => 'google';
  @override
  Future<void> signOut() async {
    events.add('google');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final deletion in [false, true]) {
    test(
      '${deletion ? 'delete' : 'sign-out'} controller unregisters while authenticated and cleans account caches',
      () async {
        SharedPreferences.setMockInitialValues({});
        final events = <String>[];
        // Keep recording store and fake services on the same ordered log.
        final recordedStore = _Store(events);
        const user = ApiUser(id: 'user', publicId: '1', displayName: 'Test');
        await recordedStore.write(
          const ApiTokens(accessToken: 'a', refreshToken: 'r'),
          user: user,
        );
        final api = DocketApiClient(
          baseUrl: 'https://api.test',
          session: recordedStore,
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(jsonEncode(user.toJson()), 200);
            }
            events.add(request.method == 'DELETE' ? 'delete204' : 'logout');
            return http.Response('', request.method == 'DELETE' ? 204 : 200);
          }),
        );
        final container = ProviderContainer(
          overrides: [
            devFlagsProvider.overrideWith(
              (ref) => DevFlagsNotifier.fixed(
                const DevFlags(
                  useMockPasses: false,
                  apiBaseUrl: 'https://api.test',
                ),
              ),
            ),
            apiSessionStoreProvider.overrideWithValue(recordedStore),
            docketApiClientProvider.overrideWithValue(api),
            notificationServiceProvider.overrideWithValue(
              _Notifications(events, recordedStore),
            ),
            passOfflineStoreProvider.overrideWithValue(_Offline(events)),
            pendingPassQueueProvider.overrideWith(() => _Pending(events)),
            googleAuthGatewayProvider.overrideWithValue(_Google(events)),
          ],
        );
        addTearDown(container.dispose);
        final auth = container.read(authControllerProvider.notifier);
        for (
          var i = 0;
          i < 10 && !container.read(authControllerProvider).realAccount;
          i++
        ) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(container.read(authControllerProvider).realAccount, isTrue);
        if (deletion) {
          await auth.deleteAccount();
        } else {
          await auth.signOut();
        }
        expect(
          events,
          deletion
              ? [
                  'delete204',
                  'push',
                  'session',
                  'offline',
                  'pending',
                  'reminders',
                  'google',
                ]
              : [
                  'push',
                  'logout',
                  'session',
                  'offline',
                  'pending',
                  'reminders',
                  'google',
                ],
        );
        expect(
          container.read(authControllerProvider).session.isSignedIn,
          isFalse,
        );
        expect(await recordedStore.read(), isNull);
      },
    );
  }
  test(
    'failed deletion leaves session, identity and all cleanup collaborators untouched',
    () async {
      SharedPreferences.setMockInitialValues({});
      final events = <String>[], store = _Store([]);
      const user = ApiUser(id: 'user', publicId: '1', displayName: 'Test');
      await store.write(
        const ApiTokens(accessToken: 'a', refreshToken: 'r'),
        user: user,
      );
      final api = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient(
          (r) async => http.Response(
            r.method == 'GET' ? jsonEncode(user.toJson()) : '',
            r.method == 'GET' ? 200 : 500,
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          devFlagsProvider.overrideWith(
            (ref) => DevFlagsNotifier.fixed(
              const DevFlags(
                useMockPasses: false,
                apiBaseUrl: 'https://api.test',
              ),
            ),
          ),
          apiSessionStoreProvider.overrideWithValue(store),
          docketApiClientProvider.overrideWithValue(api),
          notificationServiceProvider.overrideWithValue(
            _Notifications(events, store),
          ),
          passOfflineStoreProvider.overrideWithValue(_Offline(events)),
          pendingPassQueueProvider.overrideWith(() => _Pending(events)),
          googleAuthGatewayProvider.overrideWithValue(_Google(events)),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authControllerProvider.notifier);
      for (
        var i = 0;
        i < 10 && !container.read(authControllerProvider).realAccount;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        auth.deleteAccount(),
        throwsA(isA<GoogleAuthFailure>()),
      );
      expect(events, isEmpty);
      expect(container.read(authControllerProvider).session.id, 'user');
      expect((await store.read())!.accessToken, 'a');
    },
  );
}
