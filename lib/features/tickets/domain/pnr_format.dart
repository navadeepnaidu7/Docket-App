/// IRCTC PNR: exactly 10 digits after stripping spaces and dashes.
abstract final class PnrFormat {
  PnrFormat._();

  static final RegExp _digits = RegExp(r'^\d{10}$');

  static String normalize(String raw) {
    return raw.replaceAll(RegExp(r'[\s-]'), '');
  }

  static bool isValid(String raw) => _digits.hasMatch(normalize(raw));

  /// Display valid PNRs in two equal groups without changing stored values.
  static String display(String raw) {
    final String value = normalize(raw);
    return _digits.hasMatch(value)
        ? '${value.substring(0, 5)} ${value.substring(5)}'
        : raw.trim();
  }
}
