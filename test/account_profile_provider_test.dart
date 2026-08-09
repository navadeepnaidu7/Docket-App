import 'package:docket/features/dashboard/application/account_profile_provider.dart';
import 'package:docket/features/dashboard/application/account_profile_store.dart';
import 'package:docket/features/dashboard/domain/account_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the encrypted store, with switchable failures.
class _FakeStore implements AccountProfileStore {
  _FakeStore({this.value});

  String? value;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  /// Delay applied to writes, so overlapping edits can be interleaved on
  /// purpose in the serialization test.
  Duration writeDelay = Duration.zero;

  final List<String> writes = <String>[];
  int deletes = 0;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('keystore unavailable');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
    if (failWrite) throw StateError('write rejected');
    this.value = value;
    writes.add(value);
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('delete rejected');
    deletes++;
    value = null;
  }
}

/// Waits for the notifier's queued work to drain.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('hydration', () {
    test('loads a stored profile', () async {
      final _FakeStore store = _FakeStore(
        value: const AccountProfile(phone: '555', city: 'Hyderabad').toJson(),
      );
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      expect(notifier.state.phone, '555');
      expect(notifier.state.city, 'Hyderabad');
      notifier.dispose();
    });

    test('a rejected read leaves the profile empty instead of throwing',
        () async {
      final _FakeStore store = _FakeStore()..failRead = true;

      // The failure must not escape as an unhandled async error: the test
      // would fail if the constructor's load rethrew into the zone.
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      expect(notifier.state, AccountProfile.empty);
      notifier.dispose();
    });

    test('an edit still persists after a rejected read', () async {
      final _FakeStore store = _FakeStore()..failRead = true;
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      await notifier.setCity('Chennai');

      expect(notifier.state.city, 'Chennai');
      expect(store.writes, hasLength(1));
      notifier.dispose();
    });
  });

  group('write failures', () {
    test('a rejected write rolls the profile back and surfaces the error',
        () async {
      final _FakeStore store = _FakeStore();
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      await notifier.setPhone('111');
      store.failWrite = true;

      await expectLater(notifier.setPhone('222'), throwsStateError);
      expect(notifier.state.phone, '111');
      notifier.dispose();
    });

    test('the queue keeps working after a failed write', () async {
      final _FakeStore store = _FakeStore();
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      store.failWrite = true;
      await expectLater(notifier.setCity('Kochi'), throwsStateError);

      store.failWrite = false;
      await notifier.setCity('Kochi');

      expect(notifier.state.city, 'Kochi');
      notifier.dispose();
    });
  });

  group('clear', () {
    test('empties the profile and deletes the record', () async {
      final _FakeStore store = _FakeStore(
        value: const AccountProfile(phone: '555').toJson(),
      );
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      await notifier.clear();

      expect(notifier.state, AccountProfile.empty);
      expect(store.deletes, 1);
      notifier.dispose();
    });

    test('restores the profile when the delete is rejected', () async {
      final _FakeStore store = _FakeStore(
        value: const AccountProfile(phone: '555').toJson(),
      );
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();
      store.failDelete = true;

      await expectLater(notifier.clear(), throwsStateError);

      // The record is still on disk, so the profile must still show it.
      expect(notifier.state.phone, '555');
      notifier.dispose();
    });
  });

  group('serialization', () {
    test('overlapping edits both survive', () async {
      final _FakeStore store = _FakeStore()
        ..writeDelay = const Duration(milliseconds: 20);
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      // Started together, so the second edit computes its profile while the
      // first write is still in flight.
      final Future<void> phone = notifier.setPhone('999');
      final Future<void> city = notifier.setCity('Pune');
      await Future.wait(<Future<void>>[phone, city]);

      expect(notifier.state.phone, '999');
      expect(notifier.state.city, 'Pune');
      expect(store.writes, hasLength(2));
      notifier.dispose();
    });

    test('a clear racing an edit does not resurrect the edit', () async {
      final _FakeStore store = _FakeStore()
        ..writeDelay = const Duration(milliseconds: 20);
      final AccountProfileNotifier notifier =
          AccountProfileNotifier(store: store);
      await _settle();

      final Future<void> edit = notifier.setPhone('777');
      final Future<void> cleared = notifier.clear();
      await Future.wait(<Future<void>>[edit, cleared]);

      expect(notifier.state, AccountProfile.empty);
      expect(store.value, isNull);
      notifier.dispose();
    });
  });
}
