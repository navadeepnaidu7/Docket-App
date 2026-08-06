import '../../../core/validation/document_validators.dart';

/// Formatting for the Basic Access Control key inputs.
///
/// BAC derives its session key from the document number, date of birth and
/// date of expiry, with both dates in `YYMMDD`. Getting this wrong does not
/// produce a useful error — the chip simply refuses to unlock and the platform
/// channel reports a generic BAC failure — so the conversion is isolated here
/// and tested rather than done inline at the call site.
abstract final class BacKeyFormat {
  BacKeyFormat._();

  /// Converts a stored date to the `YYMMDD` form BAC expects.
  ///
  /// Accepts anything [DocumentValidators.tryParseYmd] understands
  /// (`YYYY-MM-DD`, `YYYYMMDD`, `YYYY/MM/DD`, ISO-8601). Returns null when the
  /// input is not a usable date, so callers must handle that rather than
  /// passing a malformed string through to the chip.
  ///
  /// The two-digit year is intentionally lossy — that is what the spec wants.
  static String? toBacDate(String raw) {
    final DateTime? date = DocumentValidators.tryParseYmd(raw);
    if (date == null) return null;

    final String yy = (date.year % 100).toString().padLeft(2, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String dd = date.day.toString().padLeft(2, '0');
    return '$yy$mm$dd';
  }

  /// Inverse of [toBacDate]: MRZ/chip `YYMMDD` → stored `YYYY-MM-DD`.
  ///
  /// The century is not encoded in the MRZ. Years 00–50 map to 2000–2050 and
  /// 51–99 to 1951–1999, which matches how the passport card formats six-digit
  /// dates and is correct for every living holder and every currently valid
  /// expiry. Returns null when [raw] is not six digits.
  static String? fromBacDate(String raw) {
    final String s = raw.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return null;

    final int yy = int.parse(s.substring(0, 2));
    final int mm = int.parse(s.substring(2, 4));
    final int dd = int.parse(s.substring(4, 6));
    final int year = yy > 50 ? 1900 + yy : 2000 + yy;

    final DateTime parsed = DateTime(year, mm, dd);
    // Reject rolled-over nonsense like month 19.
    if (parsed.year != year || parsed.month != mm || parsed.day != dd) {
      return null;
    }

    final String yyyy = year.toString().padLeft(4, '0');
    final String month = mm.toString().padLeft(2, '0');
    final String day = dd.toString().padLeft(2, '0');
    return '$yyyy-$month-$day';
  }

  /// Normalises a document number for BAC: upper-case, no whitespace.
  ///
  /// Note this does *not* pad to 9 characters with `<`. Some issuers require
  /// that padding and some reject it, so padding is offered to the user as a
  /// retry hint rather than applied blindly.
  static String toBacDocumentNumber(String raw) =>
      DocumentValidators.normalisePassportNumber(raw);

  /// The `<`-padded variant, offered as a second attempt when a read fails.
  static String padDocumentNumber(String raw) {
    final String v = toBacDocumentNumber(raw);
    if (v.length >= 9) return v;
    return v.padRight(9, '<');
  }
}
