import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';

import '../../application/nav_icon_style_provider.dart';
import '../../application/nav_labels_provider.dart';
import 'nav_bar_svg_icon.dart';

class PillTabBar extends ConsumerStatefulWidget {
  const PillTabBar({super.key, required this.controller});
  final TabController controller;

  @override
  ConsumerState<PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends ConsumerState<PillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.animation!.addListener(_onTabAnim);
  }

  @override
  void dispose() {
    widget.controller.animation!.removeListener(_onTabAnim);
    super.dispose();
  }

  void _onTabAnim() => setState(() {});

  ({double w, double h}) _idsIconSize(bool showLabels, bool isVertical) {
    return (
      w: showLabels ? (isVertical ? 38.0 : 42.0) : (isVertical ? 48.0 : 52.0),
      h: showLabels ? (isVertical ? 38.0 : 36.0) : (isVertical ? 48.0 : 44.0),
    );
  }

  ({double w, double h}) _passesIconSize(bool showLabels, bool isVertical) {
    return (
      w: showLabels ? (isVertical ? 36.0 : 38.0) : (isVertical ? 44.0 : 46.0),
      h: showLabels ? (isVertical ? 36.0 : 32.0) : (isVertical ? 44.0 : 38.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double t = (widget.controller.animation!.value).clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final NavIconStyleConfig iconStyles = ref.watch(navIconStylesProvider);
    final NavTabIconAssets idsAssets = navIdsAssetsFor(iconStyles.ids);
    final NavTabIconAssets passesAssets = navPassesAssetsFor(iconStyles.passes);
    final bool idsVertical = iconStyles.ids == NavIconStyle.vertical;
    final bool passesVertical = iconStyles.passes == NavIconStyle.vertical;

    return Container(
      // 7% narrower than the original 250. Kept even so the active-tab
      // highlight, which is a widthFactor of 0.5, still lands on whole pixels.
      width: 232,
      height: 82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5)
            : Border.all(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ActiveTabHighlight(t: t),
          // Labels
          Row(
            children: [
              TabLabel(
                label: 'IDs',
                iconBuilder: (context, progress, activeColor, inactiveColor, showLabels) {
                  final ({double w, double h}) size =
                      _idsIconSize(showLabels, idsVertical);
                  return NavBarSvgIcon(
                    filledAsset: idsAssets.filled,
                    unfilledAsset: idsAssets.unfilled,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    width: size.w,
                    height: size.h,
                    progress: progress,
                  );
                },
                index: 0,
                controller: widget.controller,
                t: t,
              ),
              TabLabel(
                label: 'Passes',
                iconBuilder: (context, progress, activeColor, inactiveColor, showLabels) {
                  final ({double w, double h}) size =
                      _passesIconSize(showLabels, passesVertical);
                  return NavBarSvgIcon(
                    filledAsset: passesAssets.filled,
                    unfilledAsset: passesAssets.unfilled,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    width: size.w,
                    height: size.h,
                    progress: progress,
                    offsetX: passesVertical ? 3.5 : 2.0,
                  );
                },
                index: 1,
                controller: widget.controller,
                t: t,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActiveTabHighlight extends StatelessWidget {
  const ActiveTabHighlight({super.key, required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color pillColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);

    return Align(
      alignment: Alignment(t * 2 - 1, 0),
      child: FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Container(
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class TabLabel extends ConsumerWidget {
  const TabLabel({
    super.key,
    required this.label,
    required this.iconBuilder,
    required this.index,
    required this.controller,
    required this.t,
  });

  final String label;
  final Widget Function(
    BuildContext context,
    double progress,
    Color activeColor,
    Color inactiveColor,
    bool showLabels,
  ) iconBuilder;
  final int index;
  final TabController controller;
  final double t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = index == 0
        ? ((1 - t) * 2).clamp(0.0, 1.0)
        : ((t - 0.5) * 2).clamp(0.0, 1.0);
    final bool showLabels = ref.watch(showNavLabelsProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color activeIconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color inactiveIconColor = const Color(0xFF8E8E93);
    final Color activeTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color inactiveTextColor = const Color(0xFF8E8E93);
    final Color labelColor = Color.lerp(inactiveTextColor, activeTextColor, progress)!;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticService.select();
          controller.animateTo(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic,
              child: iconBuilder(
                context,
                progress,
                activeIconColor,
                inactiveIconColor,
                showLabels,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: showLabels ? 1.0 : 0.0,
              curve: Curves.easeInOutCubic,
              child: showLabels
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: progress >= 0.5 ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: -0.1,
                            color: labelColor,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
