import 'package:flutter/material.dart';

/// A continuous handoff, including when selection reverses mid-transition.
/// The nav, content and backdrop share the TabController's eased timeline.
class HomeTabTransition extends StatelessWidget {
  const HomeTabTransition({
    super.key,
    required this.controller,
    required this.ids,
    required this.passes,
  });

  final TabController controller;
  final Widget ids;
  final Widget passes;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final t = controller.animation!.value.clamp(0.0, 1.0);
        Widget layer(Widget child, {required bool isPasses}) {
          final opacity = isPasses ? t : 1 - t;
          final selected = controller.index == (isPasses ? 1 : 0);
          return IgnorePointer(
            ignoring: !selected || opacity < 0.1,
            child: ExcludeSemantics(
              excluding: !selected,
              child: Opacity(
                // Complementary weights avoid the two nearly opaque wallets
                // that the previous, independently eased fades superimposed.
                opacity: opacity,
                child: Transform.translate(
                  offset: reduced
                      ? Offset.zero
                      : Offset(isPasses ? 12 * (1 - t) : -12 * t, 0),
                  child: TickerMode(
                    enabled: opacity > 0,
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            layer(ids, isPasses: false),
            layer(passes, isPasses: true),
          ],
        );
      },
    );
  }
}
