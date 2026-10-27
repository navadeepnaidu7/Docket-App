import 'package:flutter/material.dart';

import 'roll_page_stack.dart';

/// Applies [RollPageStack] transforms during [PageView] scroll without
/// rebuilding the heavy card [child] on every frame.
class RollingCardPage extends StatelessWidget {
  const RollingCardPage({
    super.key,
    required this.controller,
    required this.index,
    required this.padding,
    required this.child,
  });

  final PageController controller;
  final int index;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final double delta = (page - index).clamp(-1.0, 1.0);
        return RollPageStack(delta: delta, padding: padding, child: child!);
      },
      child: RepaintBoundary(child: child),
    );
  }
}
