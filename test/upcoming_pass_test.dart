import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_display.dart';
import 'package:flutter_test/flutter_test.dart';

TrainPassItem train(Map<String, dynamic> values) => TrainPassItem.fromJson({
  'id': 'train',
  'date': '12 Sep 2026',
  'status': 'active',
  ...values,
});

void main() {
  test('selects nearest future time rather than catalog order', () {
    final late = train({'id': 'late', 'departTime': '20:00'});
    final soon = train({'id': 'soon', 'departTime': '11:00'});
    final old = train({'id': 'old', 'departTime': '09:00'});
    expect(
      nextUpcomingPass([late, old, soon], DateTime(2026, 9, 12, 10)),
      same(soon),
    );
  });
  test(
    'unknown, expired, cancelled and completed passes cannot be up next',
    () {
      final items = [
        train({}),
        train({'departTime': '25:99'}),
        train({'departTime': '11:00', 'status': 'expired'}),
        train({'departTime': '11:00', 'runState': 'cancelled'}),
        train({'departTime': '11:00', 'runState': 'arrived'}),
      ];
      expect(nextUpcomingPass(items, DateTime(2026, 9, 12, 10)), isNull);
    },
  );
  test('parses 12-hour times and prefers an ISO instant', () {
    expect(
      passStartTime(train({'departTime': '12:15 AM'})),
      DateTime(2026, 9, 12, 0, 15),
    );
    expect(
      passStartTime(train({'departTime': '12:15 PM'})),
      DateTime(2026, 9, 12, 12, 15),
    );
    expect(
      passStartTime(
        train({'departAt': '2026-09-13T14:30:00Z', 'departTime': '11:00'}),
      ),
      DateTime.utc(2026, 9, 13, 14, 30).toLocal(),
    );
    expect(passStartTime(train({'departTime': '00:15 PM'})), isNull);
  });
  test('movie and bus can precede a train', () {
    final movie = MoviePassItem.fromJson({
      'id': 'movie',
      'showDate': '12 Sep 2026',
      'showTime': '10:30 AM',
    });
    final bus = BusPassItem.fromJson({
      'id': 'bus',
      'date': '12 Sep 2026',
      'departTime': '10:15',
    });
    expect(
      nextUpcomingPass([
        train({'departTime': '11:00'}),
        movie,
        bus,
      ], DateTime(2026, 9, 12, 10)),
      same(bus),
    );
  });
}
