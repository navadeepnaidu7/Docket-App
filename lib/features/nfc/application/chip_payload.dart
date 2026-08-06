import '../../../core/validation/document_validators.dart';
import '../../passport/presentation/flow/passport_prompt_flow.dart';
import 'bac_key_format.dart';

/// Maps the Android NFC channel payload into prompt-flow field values.
///
/// The native side returns a flat map of DG1/DG2/DG11/DG12 keys. The prompt
/// flow and [PassportProfile] use a different set of names and date formats
/// (`YYYY-MM-DD`, single-letter sex). Keeping the translation here means the
/// screen only folds the result in, and the mapping is unit-testable without a
/// platform channel.
///
/// Empty values are omitted so a partial chip read cannot wipe a typed field
/// with a blank.
abstract final class ChipPayload {
  ChipPayload._();

  /// Converts a platform [chip] map into flow values ready for
  /// [PromptFlowController.applyScan].
  static Map<String, String> toFlowValues(Map<String, dynamic> chip) {
    String str(String key) {
      final Object? v = chip[key];
      if (v == null) return '';
      // DG11 place-of-birth can arrive as a List when the codec preserves it;
      // the Kotlin side usually joins first, but defend both shapes.
      if (v is Iterable && v is! String) {
        return v
            .map((Object? e) => (e ?? '').toString().trim())
            .where((String s) => s.isNotEmpty)
            .join(', ');
      }
      return v.toString().trim();
    }

    final String given = str('firstName').replaceAll(RegExp(r'\s+'), ' ');
    final String surname = str('lastName').replaceAll(RegExp(r'\s+'), ' ');
    // Prefer the DG11 full name when present — it is not truncated to the MRZ
    // field width and usually matches the printed data page.
    final String dg11Name = _mrzNameToDisplay(str('dg11_fullName'));
    final String composed = <String>[
      given,
      surname,
    ].where((String p) => p.isNotEmpty).join(' ');
    final String name = dg11Name.isNotEmpty ? dg11Name : composed;

    final String documentNumber = DocumentValidators.normalisePassportNumber(
      str('documentNumber').replaceAll('<', ''),
    );

    final String? dob = BacKeyFormat.fromBacDate(str('dateOfBirth'));
    final String? expiry = BacKeyFormat.fromBacDate(str('dateOfExpiry'));

    // DG12 dates are often YYYYMMDD (8 digits) rather than the MRZ's YYMMDD.
    final String issueRaw = str('dg12_dateOfIssue');
    final String? issueDate =
        BacKeyFormat.fromBacDate(issueRaw) ??
        _fromYyyymmdd(issueRaw) ??
        (DocumentValidators.tryParseYmd(issueRaw) != null
            ? _isoFromDate(DocumentValidators.tryParseYmd(issueRaw)!)
            : null);

    final String nationality = str('nationality').toUpperCase();
    final String gender = normaliseGender(str('gender'));
    final String photo = str('photoBase64');
    final String placeOfBirth = str('dg11_placeOfBirth');
    final String issuingAuthority = str('dg12_issuingAuthority');
    final String issuingState = str('issuingState');

    final Map<String, String> out = <String, String>{
      if (name.isNotEmpty) PassportField.name: name,
      if (documentNumber.isNotEmpty)
        PassportField.passportNumber: documentNumber,
      if (nationality.isNotEmpty) PassportField.nationality: nationality,
      if (gender.isNotEmpty) PassportField.gender: gender,
      if (dob != null) PassportField.dateOfBirth: dob,
      if (expiry != null) PassportField.expiryDate: expiry,
      if (photo.isNotEmpty) 'photoBase64': photo,
      if (placeOfBirth.isNotEmpty) 'placeOfBirth': placeOfBirth,
      if (issueDate != null) 'issueDate': issueDate,
      if (issuingAuthority.isNotEmpty) 'issuingAuthority': issuingAuthority,
      if (issuingState.isNotEmpty) 'issuingState': issuingState,
    };

    return out;
  }

  /// ICAO MRZ names use `<` as a separator (`SURNAME<<GIVEN<NAMES`).
  static String _mrzNameToDisplay(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll('<<', ' ')
        .replaceAll('<', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _fromYyyymmdd(String raw) {
    final String s = raw.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(s)) return null;
    final int y = int.parse(s.substring(0, 4));
    final int m = int.parse(s.substring(4, 6));
    final int d = int.parse(s.substring(6, 8));
    final DateTime parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    return _isoFromDate(parsed);
  }

  static String _isoFromDate(DateTime d) {
    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
