import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/nav_labels_provider.dart';
import 'custom_id_card_icon.dart';

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

  @override
  Widget build(BuildContext context) {
    final double t = (widget.controller.animation!.value).clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 250,
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
                iconBuilder: (context, color, selected, showLabels) {
                  final double w = showLabels ? 32.0 : 44.0;
                  final double h = showLabels ? 23.0 : 31.0;
                  return CustomIdCardIcon(
                    color: color,
                    width: w,
                    height: h,
                    selected: selected,
                  );
                },
                index: 0,
                controller: widget.controller,
                t: t,
              ),
              TabLabel(
                label: 'Passes',
                iconBuilder: (context, color, selected, showLabels) {
                  final double s = showLabels ? 28.0 : 37.0;
                  return Icon(
                    selected ? Icons.airplane_ticket_rounded : Icons.airplane_ticket_outlined,
                    color: color,
                    size: s,
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
  final Widget Function(BuildContext context, Color color, bool selected, bool showLabels) iconBuilder;
  final int index;
  final TabController controller;
  final double t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool selected = index == 0 ? t < 0.5 : t >= 0.5;
    final bool showLabels = ref.watch(showNavLabelsProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color activeIconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color inactiveIconColor = const Color(0xFF8E8E93);
    final Color activeTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color inactiveTextColor = const Color(0xFF8E8E93);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          controller.animateTo(index);
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                child: iconBuilder(context, selected ? activeIconColor : inactiveIconColor, selected, showLabels),
              ),
              // Conditional Label with animated opacity transition
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showLabels ? 1.0 : 0.0,
                curve: Curves.easeInOutCubic,
                child: showLabels
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              letterSpacing: -0.1,
                              color: selected ? activeTextColor : inactiveTextColor,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
