import 'dart:convert';

import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/tickets/application/calendar_import_controller.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/data/api_session_store.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:docket/features/tickets/domain/calendar_import.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_repository.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/calendar/calendar_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeCalendarApi implements CalendarImportApi {
  final List<CalendarConnectionStatus> statuses = <CalendarConnectionStatus>[];
  CalendarConnectionStatus current = const CalendarConnectionStatus(
    available: true,
    state: CalendarLinkState.disconnected,
  );
  Object? connectError;
  Object? syncError;
  int disconnects = 0;

  @override
  Future<CalendarConnectionStatus> fetchCalendarStatus() async =>
      statuses.isNotEmpty ? (current = statuses.removeAt(0)) : current;

  @override
  Future<Uri> startCalendarConnect() async {
    if (connectError != null) throw connectError!;
    return Uri.parse('https://accounts.google.com/o/oauth2/v2/auth?state=x');
  }

  @override
  Future<CalendarConnectionStatus> requestCalendarSync() async {
    if (syncError != null) throw syncError!;
    return current;
  }

  @override
  Future<void> disconnectCalendar() async {
    disconnects++;
    current = const CalendarConnectionStatus(
      available: true,
      state: CalendarLinkState.disconnected,
    );
  }
}

class _CountingRepo implements PassRepository {
  int fetches = 0;

  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) async {
    fetches++;
    return const <WalletPassItem>[];
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async => null;

  @override
  Future<void> deletePass(String id) async {}
}

CalendarConnectionStatus _connected({
  DateTime? lastSync,
  String state = 'connected',
}) => CalendarConnectionStatus.fromJson(<String, dynamic>{
  'available': true,
  'status': state,
  'accountEmail': 'asha@example.com',
  if (lastSync != null) 'lastSyncAt': lastSync.toIso8601String(),
  if (lastSync != null) 'lastSuccessfulSyncAt': lastSync.toIso8601String(),
  'importedCount': 2,
  'needsDetailsCount': 1,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarConnectionStatus', () {
    test('parses every server state', () {
      expect(_connected().state, CalendarLinkState.connected);
      expect(_connected(state: 'syncing').state, CalendarLinkState.syncing);
      expect(
        _connected(state: 'reconnect_required').state,
        CalendarLinkState.reconnectRequired,
      );
      final CalendarConnectionStatus off =
          CalendarConnectionStatus.fromJson(<String, dynamic>{
            'available': false,
            'unavailableReason': 'shared_demo_account',
            'status': 'connected',
          });
      expect(off.state, CalendarLinkState.unavailable);
      expect(
        calendarReasonCopy(off.unavailableReason),
        contains('shared demo account'),
      );
      expect(_connected().needsDetailsCount, 1);
    });
  });

  group('imported pass parsing', () {
    test('a calendar train has no invented traveller or seat confirmation', () {
      final TrainPassItem item =
          walletPassItemFromJson(<String, dynamic>{
                'kind': 'train',
                'train': <String, dynamic>{
                  'id': 'train-calendar',
                  'passengers': <Object>[],
                  'importInfo': <String, dynamic>{
                    'source': 'googleCalendar',
                    'needsDetails': true,
                  },
                },
              })
              as TrainPassItem;
      expect(item.ticket.passengers, isEmpty);
      expect(item.ticket.passengerCount, 0);
      expect(item.ticket.passengerName, isEmpty);
      expect(item.ticket.passengerSummary, isEmpty);
      expect(item.ticket.seatSummary, isEmpty);
      expect(item.ticket.bookingStatus, isEmpty);
      expect(item.ticket.chartStatus, isEmpty);
      expect(item.ticket.liveStatusLabel, isEmpty);
      final TrainPassItem again =
          walletPassItemFromJson(item.toJson()) as TrainPassItem;
      expect(again.ticket.passengers, isEmpty);
    });
    test('a calendar movie with no seat does not gain one', () {
      final WalletPassItem item = walletPassItemFromJson(<String, dynamic>{
        'kind': 'movie',
        'movie': <String, dynamic>{
          'id': 'm1',
          'brand': 'universal',
          'movieTitle': 'Dune',
          'cinemaName': 'Galaxy',
          'seats': <Object>[],
          'bookingId': '',
          'status': 'active',
          'importInfo': <String, dynamic>{
            'source': 'googleCalendar',
            'needsDetails': false,
            'missingFields': <String>['seats', 'ticketCode'],
          },
        },
      });
      final MoviePassItem movie = item as MoviePassItem;
      expect(movie.pass.seats.single.label, isNot('A1'));
      expect(movie.pass.certification, '');
      expect(movie.passCode, isNull);
      expect(movie.importInfo!.missingLabels, <String>['seat', 'ticket code']);
      expect(movie.importInfo!.canAttachTicket, isTrue);
      // Round trip keeps the import block.
      final WalletPassItem again = walletPassItemFromJson(movie.toJson());
      expect(again.importInfo?.missingFields, <String>['seats', 'ticketCode']);
    });

    test(
      'ordinary uploads keep their existing defaults and no import info',
      () {
        final WalletPassItem item = walletPassItemFromJson(<String, dynamic>{
          'kind': 'movie',
          'movie': <String, dynamic>{
            'id': 'm2',
            'movieTitle': 'X',
            'seats': <Object>[],
            'status': 'active',
          },
        });
        expect(item.importInfo, isNull);
        expect((item as MoviePassItem).pass.seats.single.label, 'A1');
      },
    );
  });

  group('CalendarImportController', () {
    late _FakeCalendarApi api;
    late _CountingRepo repo;
    late List<Uri> launched;

    ProviderContainer make({bool mock = false, bool launchOk = true}) {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          devFlagsProvider.overrideWith(
            (Ref ref) => DevFlagsNotifier.fixed(
              DevFlags(useMockPasses: mock, apiBaseUrl: 'https://api.test'),
            ),
          ),
          calendarImportApiProvider.overrideWith(
            (Ref ref) => mock ? null : api,
          ),
          calendarUrlLauncherProvider.overrideWithValue((Uri uri) async {
            launched.add(uri);
            return launchOk;
          }),
          passRepositoryProvider.overrideWithValue(repo),
          calendarImportProvider.overrideWith(
            (Ref ref) => CalendarImportController(
              ref,
              pollInterval: Duration.zero,
              pollAttempts: 4,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      // Keep the autoDispose controller alive for the test.
      c.listen(calendarImportProvider, (_, _) {}, fireImmediately: true);
      return c;
    }

    setUp(() {
      api = _FakeCalendarApi();
      repo = _CountingRepo();
      launched = <Uri>[];
    });

    test('mock mode never pretends a calendar is connected', () async {
      final ProviderContainer c = make(mock: true);
      await pumpEventQueue();
      final CalendarImportState s = c.read(calendarImportProvider);
      expect(s.status!.available, isFalse);
      expect(s.status!.unavailableReason, 'mock_mode');
      await c.read(calendarImportProvider.notifier).connect();
      expect(launched, isEmpty);
    });

    test(
      'connect opens the browser, resume confirms with the server, then refreshes passes',
      () async {
        final ProviderContainer c = make();
        await pumpEventQueue();
        expect(
          c.read(calendarImportProvider).status!.state,
          CalendarLinkState.disconnected,
        );

        await c.read(calendarImportProvider.notifier).connect();
        expect(launched.single.host, 'accounts.google.com');
        expect(
          c.read(calendarImportProvider).phase,
          CalendarImportPhase.authorizing,
        );

        // User returns without finishing: still disconnected, still waiting.
        await c.read(calendarImportProvider.notifier).onAppResumed();
        expect(
          c.read(calendarImportProvider).phase,
          CalendarImportPhase.authorizing,
        );

        // Consent completed: connected, first sync queued, then finished.
        final int before = repo.fetches;
        api.statuses.addAll(<CalendarConnectionStatus>[
          _connected(),
          _connected(state: 'syncing'),
          _connected(lastSync: DateTime.utc(2026, 11, 13, 10)),
        ]);
        await c.read(calendarImportProvider.notifier).onAppResumed();
        expect(
          c.read(calendarImportProvider).phase,
          CalendarImportPhase.syncing,
        );
        await pumpEventQueue();
        final CalendarImportState s = c.read(calendarImportProvider);
        expect(s.phase, CalendarImportPhase.idle);
        expect(s.status!.lastSuccessfulSyncAt, isNotNull);
        expect(repo.fetches, greaterThan(before));
      },
    );

    test('server refusals surface as actionable errors', () async {
      api.connectError = const CalendarImportException(
        'shared_demo_account',
        'You are using the shared demo account.',
      );
      final ProviderContainer c = make();
      await pumpEventQueue();
      await c.read(calendarImportProvider.notifier).connect();
      final CalendarImportState s = c.read(calendarImportProvider);
      expect(s.phase, CalendarImportPhase.idle);
      expect(s.error, contains('shared demo account'));
      expect(launched, isEmpty);
    });

    test(
      'a browser that will not open is not reported as authorizing',
      () async {
        final ProviderContainer c = make(launchOk: false);
        await pumpEventQueue();
        await c.read(calendarImportProvider.notifier).connect();
        expect(c.read(calendarImportProvider).phase, CalendarImportPhase.idle);
        expect(c.read(calendarImportProvider).error, isNotNull);
      },
    );

    test('throttled sync and disconnect', () async {
      api.current = _connected(lastSync: DateTime.utc(2026, 11, 13, 9));
      final ProviderContainer c = make();
      await pumpEventQueue();
      api.syncError = const CalendarImportException(
        'sync_throttled',
        'Try again shortly.',
        retryAfterSeconds: 90,
      );
      await c.read(calendarImportProvider.notifier).syncNow();
      expect(c.read(calendarImportProvider).error, 'Try again shortly.');
      expect(c.read(calendarImportProvider).phase, CalendarImportPhase.idle);

      await c.read(calendarImportProvider.notifier).disconnect();
      expect(api.disconnects, 1);
      expect(
        c.read(calendarImportProvider).status!.state,
        CalendarLinkState.disconnected,
      );
    });
  });

  group('CalendarImportScreen renders every state', () {
    final Map<String, CalendarImportState> states =
        <String, CalendarImportState>{
          'Not available': const CalendarImportState(
            status: CalendarConnectionStatus.mockMode,
            phase: CalendarImportPhase.idle,
          ),
          'Not connected': const CalendarImportState(
            status: CalendarConnectionStatus(
              available: true,
              state: CalendarLinkState.disconnected,
            ),
            phase: CalendarImportPhase.idle,
          ),
          'Waiting for Google': const CalendarImportState(
            status: CalendarConnectionStatus(
              available: true,
              state: CalendarLinkState.disconnected,
            ),
            phase: CalendarImportPhase.authorizing,
          ),
          'Connected': CalendarImportState(
            status: _connected(lastSync: DateTime.now().toUtc()),
            phase: CalendarImportPhase.idle,
            error: 'A sync was requested moments ago. Try again shortly.',
          ),
          'Reconnect needed': const CalendarImportState(
            status: CalendarConnectionStatus(
              available: true,
              state: CalendarLinkState.reconnectRequired,
              lastErrorCode: 'grant_revoked',
            ),
            phase: CalendarImportPhase.idle,
          ),
        };
    for (final MapEntry<String, CalendarImportState> e in states.entries) {
      for (final bool dark in <bool>[false, true]) {
        testWidgets('${e.key}${dark ? ' (dark)' : ''}', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = const Size(360 * 3, 720 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await _pumpScreen(tester, e.value, dark: dark);
          expect(find.text(e.key), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('DocketApiClient calendar calls', () {
    Future<DocketApiClient> client(MockClientHandler handler) async {
      final ApiSessionStore store = ApiSessionStore.memory();
      await store.write(const ApiTokens(accessToken: 'a', refreshToken: 'r'));
      return DocketApiClient(
        baseUrl: 'https://api.test',
        session: store,
        httpClient: MockClient(handler),
      );
    }

    test('status, connect and error codes', () async {
      final DocketApiClient c = await client((http.Request r) async {
        expect(r.headers['Authorization'], 'Bearer a');
        switch ('${r.method} ${r.url.path}') {
          case 'GET /v1/integrations/google-calendar':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'available': true,
                'status': 'connected',
              }),
              200,
            );
          case 'POST /v1/integrations/google-calendar/connect':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'authorizationUrl': 'https://evil.example/auth',
              }),
              200,
            );
          case 'POST /v1/integrations/google-calendar/sync':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'error': 'x',
                'code': 'sync_throttled',
                'retryAfterSeconds': 30,
              }),
              429,
            );
          case 'DELETE /v1/integrations/google-calendar':
            return http.Response('', 204);
        }
        return http.Response('', 500);
      });
      expect(
        (await c.fetchCalendarStatus()).state,
        CalendarLinkState.connected,
      );
      // Only Google's consent page is ever handed to the browser.
      await expectLater(
        c.startCalendarConnect(),
        throwsA(isA<CalendarImportException>()),
      );
      await expectLater(
        c.requestCalendarSync(),
        throwsA(
          isA<CalendarImportException>()
              .having(
                (CalendarImportException e) => e.code,
                'code',
                'sync_throttled',
              )
              .having(
                (CalendarImportException e) => e.retryAfterSeconds,
                'retry',
                30,
              ),
        ),
      );
      await c.disconnectCalendar();
    });
  });
}

class _StaticController extends CalendarImportController {
  _StaticController(super.ref, CalendarImportState initial)
    : super(pollInterval: Duration.zero, pollAttempts: 0) {
    state = initial;
  }

  @override
  Future<void> refresh() async {}
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CalendarImportState s, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        devFlagsProvider.overrideWith(
          (Ref ref) => DevFlagsNotifier.fixed(
            const DevFlags(
              useMockPasses: false,
              apiBaseUrl: 'https://api.test',
            ),
          ),
        ),
        passRepositoryProvider.overrideWithValue(_CountingRepo()),
        calendarImportProvider.overrideWith(
          (Ref ref) => _StaticController(ref, s),
        ),
      ],
      child: MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: const CalendarImportScreen(),
      ),
    ),
  );
  await tester.pump();
}
