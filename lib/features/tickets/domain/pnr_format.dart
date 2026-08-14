/// IRCTC PNR: exactly 10 digits after stripping spaces and dashes.
abstract final class PnrFormat {
  PnrFormat._();

  static final RegExp _digits = RegExp(r'^\d{10}$');

  static String normalize(String raw) {
    return raw.replaceAll(RegExp(r'[\s-]'), '');
  }

  static bool isValid(String raw) => _digits.hasMatch(normalize(raw));
}
