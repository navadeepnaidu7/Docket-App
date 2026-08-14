import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/domain/pnr_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PnrFormat', () {
    test('accepts 10 digits', () {
      expect(PnrFormat.isValid('1234567890'), isTrue);
    });

    test('strips spaces and dashes', () {
      expect(PnrFormat.normalize('123-456 7890'), '1234567890');
      expect(PnrFormat.isValid('123-456-7890'), isTrue);
    });

    test('rejects the wrong length', () {
      expect(PnrFormat.isValid('123456789'), isFalse);
      expect(PnrFormat.isValid('12345678901'), isFalse);
      expect(PnrFormat.isValid(''), isFalse);
    });

    test('rejects letters', () {
      expect(PnrFormat.isValid('123456789A'), isFalse);
    });
  });

  group('PassUpload', () {
    test('maps common ticket files', () {
      expect(PassUpload.mimeForPath('/tmp/ticket.PDF'), 'application/pdf');
      expect(PassUpload.mimeForPath('shot.jpg'), 'image/jpeg');
      expect(PassUpload.mimeForPath('shot.JPEG'), 'image/jpeg');
      expect(PassUpload.mimeForPath('shot.png'), 'image/png');
      expect(PassUpload.mimeForPath('shot.webp'), 'image/webp');
    });

    test('refuses HEIC and unknown types', () {
      expect(PassUpload.mimeForPath('shot.heic'), isNull);
      expect(PassUpload.mimeForPath('notes.txt'), isNull);
      expect(PassUpload.mimeForPath('noext'), isNull);
    });
  });
}
