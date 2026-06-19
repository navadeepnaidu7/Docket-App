import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dashboard_screen.dart';

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

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
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
    final Color menuBg = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.82);

    final Color textColor = isDark
        ? const Color(0xFFF0F4FF)
        : const Color(0xFF1C1C1E);

    // List of modes
    const modes = [
      DashboardViewMode.manage,
      DashboardViewMode.home,
      DashboardViewMode.trash,
    ];

    // Find current index
    final int selectedIndex = modes.indexOf(widget.currentMode);

    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      offset: const Offset(-16.0, -14.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              alignment: Alignment.topLeft,
              child: child,
            ),
          );
        },
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            color: menuBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                children: [
                  // Sliding highlight pill background
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    top: 8.0 + selectedIndex * 56.0 + 2.0,
                    left: 8.0,
                    right: 8.0,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  // List items
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                          case DashboardViewMode.trash:
                            title = 'Trash';
                            break;
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onSelectMode(mode);
                          },
                          child: Container(
                            height: 56,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: GoogleFonts.inter(
                                color: isActive
                                    ? textColor
                                    : textColor.withValues(alpha: 0.35),
                                fontSize: 28,
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                letterSpacing: -1.0,
                              ),
                              child: Text(title),
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
    );
  }
}
