import 'package:docket/core/assets/app_assets.dart';
import 'package:docket/features/dashboard/application/nav_icon_style_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nav icon styles are fixed to IDs classic and Passes vertical', () {
    final NavIconStylesNotifier notifier = NavIconStylesNotifier();

    expect(notifier.state.ids, NavIconStyle.classic);
    expect(notifier.state.passes, NavIconStyle.vertical);
    notifier.dispose();
  });

  test('fixed styles resolve to the expected icon assets', () {
    final NavTabIconAssets idsAssets = navIdsAssetsFor(NavIconStyle.classic);
    final NavTabIconAssets passesAssets =
        navPassesAssetsFor(NavIconStyle.vertical);

    expect(idsAssets.filled, AppAssets.navIdsFilled);
    expect(idsAssets.unfilled, AppAssets.navIdsUnfilled);
    expect(passesAssets.filled, AppAssets.navAltPassesFilled);
    expect(passesAssets.unfilled, AppAssets.navAltPassesUnfilled);
  });
}
