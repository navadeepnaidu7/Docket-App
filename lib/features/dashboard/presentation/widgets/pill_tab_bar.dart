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
                  final double w = showLabels
                      ? (selected ? 32.0 : 28.0)
                      : (selected ? 42.0 : 38.0);
                  final double h = showLabels
                      ? (selected ? 23.0 : 20.0)
                      : (selected ? 30.0 : 27.0);
                  return CustomIdCardIcon(
                    color: color,
                    width: w,
                    height: h,
                  );
                },
                index: 0,
                controller: widget.controller,
                t: t,
              ),
              TabLabel(
                label: 'Passes',
                iconBuilder: (context, color, selected, showLabels) {
                  final double s = showLabels
                      ? (selected ? 26.0 : 24.0)
                      : (selected ? 34.0 : 32.0);
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
        ? const Color(0xFF242426)
        : const Color(0xFFEEF0FF);

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

class TabLabel extends ConsumerStatefulWidget {
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
  ConsumerState<TabLabel> createState() => _TabLabelState();
}

class _TabLabelState extends ConsumerState<TabLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;
  bool _wasSelected = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.16,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.16,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
    ]).animate(_bounce);
  }

  @override
  void didUpdateWidget(TabLabel old) {
    super.didUpdateWidget(old);
    final selected = widget.index == 0 ? widget.t < 0.5 : widget.t >= 0.5;
    if (selected && !_wasSelected) {
      _bounce.forward(from: 0);
    }
    _wasSelected = selected;
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool selected = widget.index == 0 ? widget.t < 0.5 : widget.t >= 0.5;
    final bool showLabels = ref.watch(showNavLabelsProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color activeIconColor = isDark ? const Color(0xFFC0B3FF) : const Color(0xFF4C3AFF);
    final Color inactiveIconColor = const Color(0xFF8E8E93);
    final Color activeTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color inactiveTextColor = const Color(0xFF8E8E93);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.controller.animateTo(widget.index);
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _scale,
                builder: (context, child) {
                  final double scale = selected ? _scale.value : 1.0;
                  final Color iconColor = selected ? activeIconColor : inactiveIconColor;
                  return Transform.scale(
                    scale: scale,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: widget.iconBuilder(context, iconColor, selected, showLabels),
                    ),
                  );
                },
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
                            widget.label,
                            style: TextStyle(
                              fontSize: selected ? 12.5 : 11.5,
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
