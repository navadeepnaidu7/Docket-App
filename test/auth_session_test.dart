import 'dart:convert';

import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/dashboard/application/auth_session_provider.dart';
import 'package:docket/features/dashboard/application/google_auth_gateway.dart';
import 'package:docket/features/tickets/application/api_providers.dart';
import 'package:docket/features/tickets/data/api_session_store.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiUser', () {
    test('parses the server membership profile', () {
      final ApiUser user = ApiUser.fromJson(<String, dynamic>{
        'id': 'user-1',
        'publicId': '4377',
        'displayName': 'Alex Rivera',
        'email': 'alex@gmail.com',
        'avatarUrl': 'https://example.com/a.jpg',
        'joinedAt': '2026-07-15T10:22:00Z',
      });
      expect(user.id, 'user-1');
      expect(user.publicId, '4377');
      expect(user.email, 'alex@gmail.com');
      expect(user.joinedAt, DateTime.utc(2026, 7, 15, 10, 22));
    });

    test('treats blank optional fields as missing', () {
      final ApiUser user = ApiUser.fromJson(<String, dynamic>{
        'id': 'user-1',
        'publicId': '12',
        'displayName': 'A',
        'email': '  ',
        'avatarUrl': '',
      });
      expect(user.email, isNull);
      expect(user.avatarUrl, isNull);
    });
  });

  group('AuthSession', () {
    test('formats the membership card date and number', () {
      final AuthSession session = AuthSession(
        isSignedIn: true,
        publicId: '4377',
        displayName: 'Alex Rivera',
        joinedAt: DateTime.utc(2026, 7, 15),
      );
      expect(session.joinedLabel, 'July 2026');
      expect(session.membershipNumber, '#4377');
    });

    test('demo identity still paints the preview card', () {
      expect(AuthSession.demo.isSignedIn, isTrue);
      expect(AuthSession.demo.joinedLabel, 'July 2026');
      expect(AuthSession.demo.membershipNumber, '#4377');
    });
  });

  group('DocketApiClient.loginWithGoogle', () {
    test('stores tokens and the user snapshot', () async {
      final ApiSessionStore store = ApiSessionStore.memory();
      final DocketApiClient client = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient((http.Request request) async {
          expect(request.url.path, '/v1/auth/google');
          final Object? body = jsonDecode(request.body);
          expect(body, isA<Map>());
          expect((body as Map)['idToken'], 'google-id-token');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'user': <String, dynamic>{
                'id': 'user-1',
                'publicId': '1001',
                'displayName': 'Sam',
                'email': 'sam@gmail.com',
                'joinedAt': '2026-09-17T08:00:00Z',
              },
              'accessToken': 'access-1',
              'refreshToken': 'refresh-1',
              'expiresIn': 900,
              'tokenType': 'Bearer',
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final ApiUser user = await client.loginWithGoogle('google-id-token');
      expect(user.displayName, 'Sam');
      expect(user.publicId, '1001');

      final StoredApiSession? stored = await store.readSession();
      expect(stored!.tokens.accessToken, 'access-1');
      expect(stored.user!.email, 'sam@gmail.com');
    });
  });

  group('AuthController', () {
    test('exchanges a Google id token and signs out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ApiSessionStore store = ApiSessionStore.memory();
      final _FakeGoogle google = _FakeGoogle();
      final DocketApiClient client = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient((http.Request request) async {
          if (request.url.path == '/v1/auth/google') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'user': <String, dynamic>{
                  'id': 'user-1',
                  'publicId': '88',
                  'displayName': 'Sam',
                  'email': 'sam@gmail.com',
                  'joinedAt': '2026-01-01T00:00:00Z',
                },
                'accessToken': 'access-1',
                'refreshToken': 'refresh-1',
                'expiresIn': 900,
                'tokenType': 'Bearer',
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          if (request.url.path == '/v1/auth/logout') {
            return http.Response('{"ok":true}', 200);
          }
          if (request.url.path == '/v1/me') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'user-1',
                'publicId': '88',
                'displayName': 'Sam',
                'email': 'sam@gmail.com',
                'joinedAt': '2026-01-01T00:00:00Z',
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          fail('unexpected ${request.method} ${request.url}');
        }),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          devFlagsProvider.overrideWith(
            (Ref ref) => DevFlagsNotifier.fixed(
              const DevFlags(
                useMockPasses: false,
                apiBaseUrl: 'https://api.test',
              ),
            ),
          ),
          apiSessionStoreProvider.overrideWithValue(store),
          docketApiClientProvider.overrideWithValue(client),
          googleSignInConfiguredProvider.overrideWithValue(true),
          googleAuthGatewayProvider.overrideWithValue(google),
        ],
      );
      addTearDown(container.dispose);

      final bool signedIn =
          await container.read(authControllerProvider.notifier).signInWithGoogle();
      expect(signedIn, isTrue);
      expect(container.read(authSessionProvider).displayName, 'Sam');
      expect(container.read(authSessionProvider).membershipNumber, '#88');

      await container.read(authControllerProvider.notifier).signOut();
      expect(container.read(authSessionProvider).isSignedIn, isFalse);
      expect(google.signOuts, 1);
      expect(await store.read(), isNull);
    });

    test('cancel leaves the session signed out', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          devFlagsProvider.overrideWith(
            (Ref ref) => DevFlagsNotifier.fixed(
              const DevFlags(
                useMockPasses: false,
                apiBaseUrl: 'https://api.test',
              ),
            ),
          ),
          apiSessionStoreProvider.overrideWithValue(ApiSessionStore.memory()),
          googleSignInConfiguredProvider.overrideWithValue(true),
          googleAuthGatewayProvider.overrideWithValue(
            _FakeGoogle()..idToken = null,
          ),
          docketApiClientProvider.overrideWithValue(
            DocketApiClient(
              baseUrl: 'https://api.test',
              session: ApiSessionStore.memory(),
              httpClient: MockClient((_) async => fail('no HTTP on cancel')),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final bool signedIn =
          await container.read(authControllerProvider.notifier).signInWithGoogle();
      expect(signedIn, isFalse);
      expect(container.read(authSessionProvider).isSignedIn, isFalse);
    });

    test('debug bypass token signs in without Google OAuth', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ApiSessionStore store = ApiSessionStore.memory();
      final _FakeGoogle google = _FakeGoogle();
      final DocketApiClient client = DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient((http.Request request) async {
          expect(request.url.path, '/v1/auth/google');
          final Object? body = jsonDecode(request.body);
          expect((body as Map)['idToken'], 'dev-google-token');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'user': <String, dynamic>{
                'id': 'dev-1',
                'publicId': '4267',
                'displayName': 'Dev User',
                'email': 'dev.user@example.com',
                'joinedAt': '2026-01-01T00:00:00Z',
              },
              'accessToken': 'access-dev',
              'refreshToken': 'refresh-dev',
              'expiresIn': 900,
              'tokenType': 'Bearer',
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          devFlagsProvider.overrideWith(
            (Ref ref) => DevFlagsNotifier.fixed(
              const DevFlags(
                useMockPasses: false,
                apiBaseUrl: 'https://api.test',
                devAuthIdToken: 'dev-google-token',
              ),
            ),
          ),
          apiSessionStoreProvider.overrideWithValue(store),
          docketApiClientProvider.overrideWithValue(client),
          googleSignInConfiguredProvider.overrideWithValue(false),
          googleAuthGatewayProvider.overrideWithValue(google),
        ],
      );
      addTearDown(container.dispose);

      final bool signedIn =
          await container.read(authControllerProvider.notifier).signInWithGoogle();
      expect(signedIn, isTrue);
      expect(container.read(authSessionProvider).displayName, 'Dev User');
      expect(container.read(authSessionProvider).membershipNumber, '#4267');
      expect(google.signOuts, 0);
    });
  });
}

class _FakeGoogle implements GoogleAuthGateway {
  String? idToken = 'google-id-token';
  int signOuts = 0;

  @override
  Future<String?> signIn() async => idToken;

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}
