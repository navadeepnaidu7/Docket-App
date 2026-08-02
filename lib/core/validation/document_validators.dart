import 'package:flutter/foundation.dart';

/// Shared validation helpers ("exceptions") for document data entry.
/// Used by ID entry, passport entry, and post-scan preview confirm flows.
class DocumentValidators {
  DocumentValidators._();

  static final RegExp _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final RegExp _aadhaarDigits = RegExp(r'^\d{12}$');

  /// ICAO 9303 document numbers are up to 9 alphanumerics. Shorter is allowed
  /// because some older books are issued with 6-8.
  static final RegExp _passportNumberRegex = RegExp(r'^[A-Z0-9]{6,9}$');

  /// Safely parse "YYYY-MM-DD" or "YYYYMMDD" style. Returns null on failure.
  static DateTime? tryParseYmd(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.trim().replaceAll(RegExp(r'[-/]'), '');
    if (s.length == 8) {
      final y = int.tryParse(s.substring(0, 4));
      final m = int.tryParse(s.substring(4, 6));
      final d = int.tryParse(s.substring(6, 8));
      if (y != null && m != null && d != null) {
        final DateTime parsed = DateTime(y, m, d);
        // DateTime does not reject out-of-range parts, it rolls them over:
        // DateTime(1203, 19, 90) silently becomes 1204-09-28. Without this
        // round-trip check a day-first value like "12/03/1990" parses to a
        // date in the year 1204 instead of being reported as invalid.
        if (parsed.year == y && parsed.month == m && parsed.day == d) {
          return parsed;
        }
        return null;
      }
    }
    // Try direct ISO
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Returns an error message if the DOB is invalid, or null if acceptable.
  /// - Future or today → error
  /// - requireAdult (PAN) → must be at least 18 years old
  /// - Unrealistic (before 1900 or age > 120) → error
  /// Set [required] when the value is a hard prerequisite (for example the BAC
  /// triple, without which the NFC chip read cannot even be attempted).
  /// It defaults to false so existing optional-field callers are unaffected.
  static String? validateDateOfBirth(
    String raw, {
    bool requireAdult = false,
    bool required = false,
  }) {
    if (raw.trim().isEmpty) {
      return required ? 'Date of birth is required.' : null;
    }

    final date = tryParseYmd(raw);
    if (date == null) {
      return 'Please enter a valid date of birth.';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!date.isBefore(today)) {
      return 'Date of birth cannot be today or in the future.';
    }

    // Unrealistic old
    if (date.isBefore(DateTime(1900, 1, 1))) {
      return 'Date of birth is unrealistically old.';
    }

    // Age calculation (rough)
    int age = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      age--;
    }

    if (age > 120) {
      return 'Date of birth implies an unrealistic age.';
    }

    if (requireAdult && age < 18) {
      return 'PAN requires the holder to be at least 18 years old.';
    }

    return null;
  }

  /// Returns error if expiry is invalid.
  /// - Must be in the future (if provided)
  /// - If dob provided, expiry must be after DOB
  static String? validateExpiryDate(
    String raw, {
    String? dob,
    bool required = false,
  }) {
    if (raw.trim().isEmpty) {
      return required ? 'Expiry date is required.' : null;
    }

    final exp = tryParseYmd(raw);
    if (exp == null) {
      return 'Please enter a valid expiry date.';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!exp.isAfter(today)) {
      return 'Expiry date must be in the future.';
    }

    if (dob != null && dob.trim().isNotEmpty) {
      final birth = tryParseYmd(dob);
      if (birth != null && !exp.isAfter(birth)) {
        return 'Expiry date must be after date of birth.';
      }
    }

    // Cap at ~30 years in future (generous for passports)
    if (exp.year > today.year + 30) {
      return 'Expiry date is too far in the future.';
    }

    return null;
  }

  /// PAN number format validation (when non-empty).
  static String? validatePanNumber(String raw) {
    final v = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (v.isEmpty) return null;
    if (!_panRegex.hasMatch(v)) {
      return 'PAN must be 10 characters: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F).';
    }
    return null;
  }

  /// Basic Aadhaar check (12 digits, optional spaces).
  static String? validateAadhaarNumber(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'\s'), '');
    if (digitsOnly.isEmpty) return null;
    if (digitsOnly.length != 12 || !_aadhaarDigits.hasMatch(digitsOnly)) {
      return 'Aadhaar must be 12 digits.';
    }
    return null;
  }

  /// Convenience: run relevant checks for an ID document type.
  /// Returns first error found, or null if OK.
  static String? validateIdForSave({
    required String dateOfBirth,
    required String documentNumber,
    required IdDocumentTypeForValidation type,
  }) {
    // DOB (require adult only for PAN)
    final dobErr = validateDateOfBirth(
      dateOfBirth,
      requireAdult: type == IdDocumentTypeForValidation.pan,
    );
    if (dobErr != null) return dobErr;

    // Number format
    if (type == IdDocumentTypeForValidation.pan) {
      final panErr = validatePanNumber(documentNumber);
      if (panErr != null) return panErr;
    } else if (type == IdDocumentTypeForValidation.aadhaar) {
      final aadErr = validateAadhaarNumber(documentNumber);
      if (aadErr != null) return aadErr;
    }

    return null;
  }

  /// For passport context (DOB + expiry both matter).
  static String? validatePassportDates({
    required String dateOfBirth,
    required String expiryDate,
    bool required = false,
  }) {
    final dobErr = validateDateOfBirth(dateOfBirth, required: required);
    if (dobErr != null) return dobErr;

    final expErr = validateExpiryDate(
      expiryDate,
      dob: dateOfBirth,
      required: required,
    );
    if (expErr != null) return expErr;

    return null;
  }

  /// Passport document number format.
  ///
  /// Normalises before checking (trim, upper-case, strip spaces) so a value
  /// typed as "z3 456 789" validates. Callers should persist the normalised
  /// form via [normalisePassportNumber].
  static String? validatePassportNumber(String raw, {bool required = false}) {
    final String v = normalisePassportNumber(raw);
    if (v.isEmpty) {
      return required ? 'Passport number is required.' : null;
    }
    if (!_passportNumberRegex.hasMatch(v)) {
      return 'Passport number is 6-9 letters and digits, no spaces.';
    }
    return null;
  }

  static String normalisePassportNumber(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');

  /// The three values Basic Access Control needs before the chip will unlock.
  ///
  /// Returns a per-field map so the caller can attach each message to the field
  /// that caused it, rather than collapsing them into one banner. An empty map
  /// means the read may be attempted.
  ///
  /// This is the gate that was missing: [validateDateOfBirth] and
  /// [validateExpiryDate] treat empty as valid, so an unguarded caller could
  /// start a chip read with no BAC data at all and get an opaque INVALID_ARGS
  /// back from the platform channel.
  static Map<String, String> validateBacTriple({
    required String passportNumber,
    required String dateOfBirth,
    required String expiryDate,
  }) {
    final Map<String, String> errors = <String, String>{};

    final String? numberErr =
        validatePassportNumber(passportNumber, required: true);
    if (numberErr != null) errors['passportNumber'] = numberErr;

    final String? dobErr = validateDateOfBirth(dateOfBirth, required: true);
    if (dobErr != null) errors['dateOfBirth'] = dobErr;

    final String? expiryErr = validateExpiryDate(
      expiryDate,
      dob: dateOfBirth,
      required: true,
    );
    if (expiryErr != null) errors['expiryDate'] = expiryErr;

    return errors;
  }
}

/// Lightweight enum to avoid importing full IdDocumentType in core.
enum IdDocumentTypeForValidation { pan, aadhaar, passport }

@visibleForTesting
DateTime? debugTryParseYmd(String raw) => DocumentValidators.tryParseYmd(raw);