/// The spacing scale for entry flows.
///
/// Before this there was exactly one spacing constant in the codebase
/// (`AppTokens.sectionPadding`), so every gap was a magic `SizedBox` and the
/// same visual role was spelled 8, 10, 12, 14, 18 and 24 in different files.
/// Steps are 4pt up to 24 and 8pt beyond, which is enough resolution for this
/// UI without inviting arbitrary in-between values.
abstract final class Space {
  Space._();

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;

  /// Horizontal screen inset. Everything in a prompt aligns to this: the
  /// headline, the input, the error, the CTA, and the review rows — so nothing
  /// shifts sideways as the user moves between steps.
  static const double gutter = 20;

  /// Between grouped blocks within one screen.
  static const double sectionGap = 28;
}
