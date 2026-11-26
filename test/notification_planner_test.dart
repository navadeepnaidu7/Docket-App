import 'package:docket/features/notifications/domain/notification_preferences.dart';
import 'package:docket/features/notifications/domain/reminder_planner.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

WalletPassItem pass(
  String kind, {
  String id = 'a',
  String start = '2027-01-02T18:30:00Z',
  Map<String, dynamic> extra = const {},
}) => walletPassItemFromJson({
  'kind': kind,
  kind: {
    'id': id,
    'status': 'active',
    'departAt': start,
    'showAt': start,
    'movieTitle': 'Dune',
    'cinemaName': 'Cinema',
    'screen': 'Screen 2',
    'trainNumber': '12627',
    'fromCode': 'MAS',
    'fromName': 'Chennai',
    'toCode': 'SBC',
    'operator': 'Express',
    'boardingLocation': 'Central',
    'dropLocation': 'South',
    'flightNumber': '6E 2134',
    'origin': {'code': 'DEL'},
    'destination': {'code': 'BLR'},
    'pnr': 'SENSITIVE_PNR',
    'bookingId': 'SENSITIVE_BOOKING',
    'bookingRef': 'SENSITIVE_REF',
    'codePayload': 'SENSITIVE_CODE',
    'passengers': [
      {'name': 'SENSITIVE_NAME', 'coach': 'B2', 'seat': '34', 'berth': 'Lower'},
    ],
    ...extra,
  },
});

void main() {
  tzdata.initializeTimeZones();
  final now = DateTime.utc(2027, 1, 1, 12);
  List<PlannedReminder> plan(
    List<WalletPassItem> passes, {
    NotificationPreferences prefs = const NotificationPreferences(),
    DateTime? clock,
    Map<String, DateTime>? seen,
    Set<String> excluded = const {},
  }) => planReminders(
    passes: passes,
    preferences: prefs,
    firstSeen:
        seen ??
        {for (final p in passes) p.id: now.subtract(const Duration(days: 1))},
    now: clock ?? now,
    deviceZone: tz.UTC,
    excludedIds: excluded,
  );

  test('default lead per kind and private content allowlist', () {
    for (final kind in PassKind.values) {
      final reminder = plan([pass(kind.name)]).single;
      expect(
        reminder.at.toUtc(),
        DateTime.utc(2027, 1, 2, 18, 30).subtract(
          Duration(minutes: NotificationPreferences.defaultLeads[kind]!),
        ),
      );
      expect(
        '${reminder.title} ${reminder.body}',
        isNot(contains('SENSITIVE')),
      );
      expect(reminder.ticketId, 'a');
    }
  });
  test('every configured lead choice, including off', () {
    for (final kind in PassKind.values) {
      for (final minutes in NotificationPreferences.choices[kind]!) {
        final result = plan(
          [pass(kind.name)],
          prefs: NotificationPreferences(
            leads: {...NotificationPreferences.defaultLeads, kind: minutes},
          ),
        );
        expect(result.length, minutes == 0 ? 0 : 1);
        if (minutes > 0) {
          expect(
            DateTime.utc(
              2027,
              1,
              2,
              18,
              30,
            ).difference(result.single.at).inMinutes,
            minutes,
          );
        }
      }
    }
  });
  test('quiet hours move a dawn flight to 21:00 the previous evening', () {
    final reminder = plan([
      pass('flight', start: '2027-01-02T05:40:00Z'),
    ]).single;
    expect(reminder.at, DateTime.utc(2027, 1, 1, 21));
    expect(reminder.title, contains('Tomorrow'));
  });
  test('a late show moves to 21:00 the same evening, not the day before', () {
    final reminder = plan(
      [pass('movie', start: '2027-01-01T23:00:00Z')],
      prefs: NotificationPreferences(
        leads: {...NotificationPreferences.defaultLeads, PassKind.movie: 30},
      ),
    ).single;
    expect(reminder.at, DateTime.utc(2027, 1, 1, 21));
    expect(reminder.title, isNot(contains('Tomorrow')));
  });
  test('after evening has passed, quiet end only if before departure', () {
    final late = DateTime.utc(2027, 1, 1, 23);
    expect(
      plan([pass('flight', start: '2027-01-02T05:40:00Z')], clock: late),
      isEmpty,
    );
    expect(
      plan([
        pass('flight', start: '2027-01-02T08:40:00Z'),
      ], clock: late).single.at,
      DateTime.utc(2027, 1, 2, 7),
    );
  });
  test('quiet hours off and equal endpoints leave lead unchanged', () {
    for (final prefs in [
      const NotificationPreferences(quietEnabled: false),
      const NotificationPreferences(quietStart: 420, quietEnd: 420),
    ]) {
      expect(
        plan([
          pass('flight', start: '2027-01-02T05:40:00Z'),
        ], prefs: prefs).single.at.toUtc(),
        DateTime.utc(2027, 1, 2, 2, 40),
      );
    }
  });
  test(
    'just-added threshold uses adjusted reminder time and includes 15 minutes',
    () {
      final item = pass('movie');
      final reminder = DateTime.utc(2027, 1, 2, 16, 30);
      expect(
        plan(
          [item],
          seen: {'a': reminder.subtract(const Duration(minutes: 15))},
        ),
        hasLength(1),
      );
      expect(
        plan(
          [item],
          seen: {
            'a': reminder.subtract(const Duration(minutes: 14, seconds: 59)),
          },
        ),
        isEmpty,
      );
      expect(plan([item], seen: {'a': reminder}), isEmpty);
      expect(
        plan([item], seen: {'a': reminder.add(const Duration(minutes: 1))}),
        isEmpty,
      );
      expect(
        plan(
          [item],
          seen: {},
          clock: reminder.subtract(const Duration(minutes: 10)),
        ),
        isEmpty,
      );
    },
  );
  test(
    'groups within 10 minutes, independent of input order, and preserves separate events',
    () {
      final a = pass('movie'),
          b = pass('movie', id: 'b', start: '2027-01-02T18:40:00Z');
      final ab = plan([a, b]).single, ba = plan([b, a]).single;
      expect(ab.id, ba.id);
      expect(ab.at, ba.at);
      expect(ab.title, startsWith('2 tickets'));
      expect(
        plan([a, pass('movie', id: 'b', start: '2027-01-02T18:41:00Z')]),
        hasLength(2),
      );
      expect(
        plan([
          a,
          pass('movie', id: 'b', extra: {'movieTitle': 'Other'}),
        ]),
        hasLength(2),
      );
      expect(
        plan([
          a,
          pass('movie', id: 'b', extra: {'cinemaName': 'Other'}),
        ]),
        hasLength(2),
      );
    },
  );
  test(
    'grouping does not chain distinct starts beyond the first 10 minutes',
    () {
      expect(
        plan([
          pass('movie'),
          pass('movie', id: 'b', start: '2027-01-02T18:40:00Z'),
          pass('movie', id: 'c', start: '2027-01-02T18:50:00Z'),
        ]),
        hasLength(2),
      );
    },
  );
  test('skips past, expired, excluded, cancelled and departed passes', () {
    expect(plan([pass('movie', start: '2026-12-31T12:00:00Z')]), isEmpty);
    expect(
      plan([
        pass('movie', extra: {'status': 'expired'}),
      ]),
      isEmpty,
    );
    expect(plan([pass('movie')], excluded: {'a'}), isEmpty);
    expect(
      plan([
        pass('train', extra: {'runState': 'cancelled'}),
      ]),
      isEmpty,
    );
    expect(
      plan([
        pass('train', extra: {'bookingStatus': 'Cancelled'}),
      ]),
      isEmpty,
    );
    expect(
      plan([
        pass(
          'flight',
          extra: {
            'live': {'state': 'cancelled'},
          },
        ),
      ]),
      isEmpty,
    );
    expect(
      plan([
        pass(
          'flight',
          extra: {
            'live': {'state': 'departed'},
          },
        ),
      ]),
      isEmpty,
    );
    expect(
      plan([
        pass('movie'),
      ], prefs: const NotificationPreferences(tripReminders: false)),
      isEmpty,
    );
  });
  test(
    'no missing/date-only/invalid time becomes a guessed midnight start',
    () {
      for (final time in [
        '',
        'nonsense',
        '2027-01-02',
        '2027-02-31T18:30:00Z',
      ]) {
        expect(plan([pass('movie', start: time)]), isEmpty);
      }
      expect(
        plan([
          pass(
            'movie',
            start: '',
            extra: {'showDate': '2 Jan 2027', 'showTime': '6:30 PM'},
          ),
        ]).single.title,
        contains('18:30'),
      );
      expect(
        plan([
          pass(
            'movie',
            start: '',
            extra: {'showDate': '2 Jan 2027', 'showTime': '25:99'},
          ),
        ]),
        isEmpty,
      );
    },
  );
  test('airport offset changes the instant without changing printed clock', () {
    final r = plan([pass('flight', start: '2027-01-02T18:30:00+05:30')]).single;
    expect(r.at.toUtc(), DateTime.utc(2027, 1, 2, 10));
    expect(r.title, contains('18:30'));
  });
  test(
    'train/movie/bus labels retain the pass clock when the phone is abroad',
    () {
      for (final kind in ['train', 'movie', 'bus']) {
        final r = plan([pass(kind, start: '2027-01-02T18:30:00+05:30')]).single;
        expect(r.title, contains('18:30'));
        final printed = plan([
          pass(
            kind,
            start: '2027-01-02T18:30:00+05:30',
            extra: {'departTime': '6:30 PM', 'showTime': '6:30 PM'},
          ),
        ]).single;
        expect(printed.title, contains('18:30'));
      }
    },
  );
  test('first upcoming flight leg only, advancing after it departs', () {
    final legs = [
      {
        'id': 'a',
        'from': 'DEL',
        'to': 'BOM',
        'departAt': '2027-01-02T18:30:00Z',
      },
      {
        'id': 'b',
        'from': 'BOM',
        'to': 'BLR',
        'departAt': '2027-01-03T18:30:00Z',
      },
    ];
    final a = pass(
      'flight',
      extra: {
        'trip': {'id': 'trip', 'index': 0, 'legs': legs},
      },
    );
    final b = pass(
      'flight',
      id: 'b',
      start: '2027-01-03T18:30:00Z',
      extra: {
        'trip': {'id': 'trip', 'index': 1, 'legs': legs},
      },
    );
    expect(plan([a, b]).single.ticketId, 'a');
    expect(
      plan([a, b], clock: DateTime.utc(2027, 1, 2, 20)).single.ticketId,
      'b',
    );
  });
  test('stable ids do not depend on time or settings', () {
    final before = plan([pass('movie')]).single;
    final after = plan(
      [pass('movie')],
      prefs: const NotificationPreferences(leads: {PassKind.movie: 60}),
    ).single;
    expect(before.id, after.id);
    expect(before.at, isNot(after.at));
    expect(notificationId('a'), 1678518572);
  });
  test(
    'quiet-hour calculation respects the device IANA zone, including DST',
    () {
      final item = pass('flight', start: '2027-03-14T08:40:00Z');
      final result = planReminders(
        passes: [item],
        preferences: const NotificationPreferences(),
        firstSeen: {'a': DateTime.utc(2027, 3, 12)},
        now: DateTime.utc(2027, 3, 13, 12),
        deviceZone: tz.getLocation('America/New_York'),
      );
      expect(
        result.single.at.toUtc(),
        DateTime.utc(2027, 3, 14, 2),
      ); // 21:00 EST previous day
    },
  );
}
