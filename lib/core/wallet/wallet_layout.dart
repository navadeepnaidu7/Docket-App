import 'package:flutter/widgets.dart';

/// Layout constants shared by the wallet tabs.
///
/// The clearance below a scrolling card list used to be spelled out as
/// `MediaQuery.of(context).padding.bottom + 16 + 58 + 20` in each tab, so the
/// two copies could drift apart silently. The parts are named here instead.
class WalletLayout {
  const WalletLayout._();

  /// Height of the floating add button.
  static const double fabSize = 58;

  /// Gap between the FAB and the bottom safe-area edge.
  static const double fabBottomGap = 16;

  /// Breathing room between the FAB and the content above it.
  static const double fabContentGap = 20;

  /// Space a scrollable tab must leave at the bottom so its last item clears
  /// the floating add button and the system inset.
  static double fabClearance(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      fabBottomGap +
      fabSize +
      fabContentGap;
}
