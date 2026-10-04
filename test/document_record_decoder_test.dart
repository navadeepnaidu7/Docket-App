import 'dart:async';
import 'dart:convert';

import 'package:docket/core/storage/document_record_decoder.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy portraits survive migration and malformed records are reported',
    () {
      final portrait = '/9j/${'A' * 200}';
      final legacy = PassportProfile.empty().toMap()
        ..remove('v')
        ..['imagePath'] = portrait;
      final result = decodePassportRecords([
        jsonEncode(legacy),
        '{bad',
        'null',
        '[]',
        PassportProfile.empty().copyWith(id: 'valid').toJson(),
      ]);
      expect(result.records, hasLength(2));
      expect(result.records.first.photoBase64, portrait);
      expect(result.records.last.id, 'valid');
      expect(result.needsMigration, isTrue);
      expect(result.hasInvalidRecords, isTrue);
    },
  );

  test('large photo wallet yields to the event loop while decoding', () async {
    final sources = List.generate(
      300,
      (i) => PassportProfile.empty()
          .copyWith(id: 'p$i', photoBase64: 'A' * 32768)
          .toJson(),
    );
    var uiEventHandled = false;
    Timer.run(() => uiEventHandled = true);
    final watch = Stopwatch()..start();
    final result = await decodeStoredRecords(sources, decodePassportRecords);
    // The timer cannot run before a synchronous, blocking decode completes.
    expect(uiEventHandled, isTrue);
    expect(result.records, hasLength(300));
    expect(result.records.last.id, 'p299');
    expect(result.records.first.photoBase64, hasLength(32768));
    expect(result.needsMigration, isFalse);
    expect(result.hasInvalidRecords, isFalse);
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('invalid IDs are reported rather than mistaken for an empty wallet', () {
    final result = decodeIdRecords(['{bad', '42', 'null']);
    expect(result.records, isEmpty);
    expect(result.hasInvalidRecords, isTrue);
  });
}
