import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';

enum NavIconStyle {
  classic,
  vertical,
}

class NavIconStyleConfig {
  const NavIconStyleConfig({
    this.ids = NavIconStyle.classic,
    this.passes = NavIconStyle.vertical,
  });

  final NavIconStyle ids;
  final NavIconStyle passes;

  NavIconStyleConfig copyWith({
    NavIconStyle? ids,
    NavIconStyle? passes,
  }) {
    return NavIconStyleConfig(
      ids: ids ?? this.ids,
      passes: passes ?? this.passes,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NavIconStyleConfig &&
        other.ids == ids &&
        other.passes == passes;
  }

  @override
  int get hashCode => Object.hash(ids, passes);
}

typedef NavTabIconAssets = ({String filled, String unfilled});

NavTabIconAssets navIdsAssetsFor(NavIconStyle style) {
  switch (style) {
    case NavIconStyle.vertical:
      return (
        filled: AppAssets.navAltIdsFilled,
        unfilled: AppAssets.navAltIdsUnfilled,
      );
    case NavIconStyle.classic:
      return (
        filled: AppAssets.navIdsFilled,
        unfilled: AppAssets.navIdsUnfilled,
      );
  }
}

NavTabIconAssets navPassesAssetsFor(NavIconStyle style) {
  switch (style) {
    case NavIconStyle.vertical:
      return (
        filled: AppAssets.navAltPassesFilled,
        unfilled: AppAssets.navAltPassesUnfilled,
      );
    case NavIconStyle.classic:
      return (
        filled: AppAssets.navPassesFilled,
        unfilled: AppAssets.navPassesUnfilled,
      );
  }
}

final navIconStylesProvider =
    StateNotifierProvider<NavIconStylesNotifier, NavIconStyleConfig>(
  (ref) => NavIconStylesNotifier(),
);

class NavIconStylesNotifier extends StateNotifier<NavIconStyleConfig> {
  NavIconStylesNotifier() : super(const NavIconStyleConfig());
}