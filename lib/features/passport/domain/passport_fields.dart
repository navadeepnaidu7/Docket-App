/// Field ids. Also the keys the flow's value map is written under, so they
/// match the draft's field names.
abstract final class PassportField {
  PassportField._();

  static const String method = 'method';
  static const String name = 'name';
  static const String passportNumber = 'passportNumber';
  static const String dateOfBirth = 'dateOfBirth';
  static const String expiryDate = 'expiryDate';
  static const String nationality = 'nationality';
  static const String gender = 'gender';
  static const String nfcRead = 'nfcRead';
  static const String review = 'review';
}

/// Flow flags.
abstract final class PassportFlag {
  PassportFlag._();

  /// The user chose "E-Passport" before entering, so the chip route exists.
  static const String isEPassport = 'isEPassport';

  /// A chip read has completed, so the flow can offer to save.
  static const String chipRead = 'chipRead';

  /// The chip was attempted and given up on. The fields it would have
  /// supplied have to be asked for after all.
  static const String chipSkipped = 'chipSkipped';
}

/// Normalises the chip's gender encoding to the flow's.
///
/// JMRTD reports `MALE` / `FEMALE` / `UNKNOWN` while the MRZ carries `M` / `F`,
/// and both used to be written into the same field — so a record's sex was
/// stored in one of two incompatible encodings depending on how it was added.
String normaliseGender(String raw) {
  final String v = raw.trim().toUpperCase();
  if (v.startsWith('M')) return 'M';
  if (v.startsWith('F')) return 'F';
  if (v.isEmpty) return '';
  return 'X';
}
