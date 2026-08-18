import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../dashboard_screen.dart';
import 'dashboard_header.dart' show dashboardNavTitleStyle;

class ViewPickerExpanded extends StatefulWidget {
  const ViewPickerExpanded({
    super.key,
    required this.link,
    required this.visible,
    required this.currentMode,
    required this.openedMode,
    required this.onSelectMode,
    required this.onClose,
  });

  final LayerLink link;
  final bool visible;
  final DashboardViewMode currentMode;
  final DashboardViewMode openedMode;
  final ValueChanged<DashboardViewMode> onSelectMode;
  final VoidCallback onClose;

  @override
  State<ViewPickerExpanded> createState() => _ViewPickerExpandedState();
}

class _ViewPickerExpandedState extends State<ViewPickerExpanded>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _shouldRender = false;

  static const double _menuWidth = 184;
  static const double _rowHeight = 56;
  static const double _menuPadding = 6;
  static const double _cornerRadius = 22;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.visible) {
      _shouldRender = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ViewPickerExpanded oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        setState(() {
          _shouldRender = true;
        });
        _controller.forward();
      } else {
        _controller.reverse().then((_) {
          if (mounted && !widget.visible) {
            setState(() {
              _shouldRender = false;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldRender) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color frostedFill = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.78)
        : const Color(0xFFFBF8F2).withValues(alpha: 0.90);

    final Color selectionFill = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.045);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    final Color ink = isDark
        ? const Color(0xFFE8EEFF)
        : const Color(0xFF0D1B2A);

    // Journey sits beside Home because it is another view of the user's own
    // things. Trash stays terminal at the bottom.
    const modes = <DashboardViewMode>[
      DashboardViewMode.manage,
      DashboardViewMode.home,
      DashboardViewMode.journey,
      DashboardViewMode.trash,
    ];

    final int selectedIndex = modes.indexOf(widget.currentMode);
    final double menuHeight = _menuPadding * 2 + modes.length * _rowHeight;

    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      offset: const Offset(-14.0, -12.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Avoid absorbing taps while fading out (Opacity 0 still hit-tests).
          final bool absorbHits =
              !widget.visible || _fadeAnimation.value < 0.02;
          return IgnorePointer(
            ignoring: absorbHits,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                alignment: Alignment.topLeft,
                child: child,
              ),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cornerRadius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_cornerRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: frostedFill,
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: SizedBox(
                  width: _menuWidth,
                  height: menuHeight,
                  child: Stack(
                    children: <Widget>[
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        top: _menuPadding + selectedIndex * _rowHeight,
                        left: _menuPadding,
                        right: _menuPadding,
                        height: _rowHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selectionFill,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: _menuPadding),
                        child: Column(
                          children: modes.map((mode) {
                            final bool isActive = widget.currentMode == mode;
                            final String title;
                            switch (mode) {
                              case DashboardViewMode.home:
                                title = 'Home';
                                break;
                              case DashboardViewMode.manage:
                                title = 'Manage';
                                break;
                              case DashboardViewMode.journey:
                                title = 'Journey';
                                break;
                              case DashboardViewMode.trash:
                                title = 'Trash';
                                break;
                            }

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticService.select();
                                widget.onSelectMode(mode);
                              },
                              child: SizedBox(
                                height: _rowHeight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      style: dashboardNavTitleStyle(
                                        ink,
                                        selected: isActive,
                                      ),
                                      child: Text(title),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}