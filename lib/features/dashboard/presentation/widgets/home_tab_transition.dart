import 'package:flutter/material.dart';

/// Fade-through weight for one tab at timeline position [t] (0 is IDs, 1 is
/// Passes).
///
/// Each tab is visible only on its own half of the timeline: IDs fades out as
/// [t] goes from 0 to 0.5, Passes fades in from 0.5 to 1, and back the same way
/// in reverse. So at most one wallet is ever partly transparent. The earlier
/// cross-fade kept both translucent at once, and a translucent wallet is
/// composited offscreen: on a 120Hz phone the switch's frames rasterised in
/// 22-32ms against an 8.3ms budget, which was the stutter. Under the eased
/// timeline the outgoing tab clears in the first few frames and the incoming
/// one takes the rest. A pure function of [t], so a reversal mid-switch stays
/// continuous.
@visibleForTesting
double fadeThroughOpacity(double t, {required bool isPasses}) =>
    ((isPasses ? t - 0.5 : 0.5 - t) * 2).clamp(0.0, 1.0);

/// A continuous handoff, including when selection reverses mid-transition.
/// The nav, content and backdrop share the TabController's eased timeline.
///
/// While the timeline moves, each tab is drawn from a snapshot: rendered to an
/// image once, then faded and slid as that image. A wallet is shadows, clipped
/// ticket shapes and gradients, and fading it live re-renders all of that
/// offscreen on every frame, which on a 120Hz phone cost 10-30ms a frame
/// against an 8.3ms budget. The tabs' own animations pause for the 200ms the
/// snapshot is up, so nothing moves under it.
class HomeTabTransition extends StatefulWidget {
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
  State<HomeTabTransition> createState() => _HomeTabTransitionState();
}

class _HomeTabTransitionState extends State<HomeTabTransition> {
  final SnapshotController _idsSnapshot = SnapshotController();
  final SnapshotController _passesSnapshot = SnapshotController();

  @override
  void dispose() {
    _idsSnapshot.dispose();
    _passesSnapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TabController controller = widget.controller;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final t = controller.animation!.value.clamp(0.0, 1.0);
        final bool moving = t > 0 && t < 1;
        Widget layer(Widget child, {required bool isPasses}) {
          final opacity = fadeThroughOpacity(t, isPasses: isPasses);
          final selected = controller.index == (isPasses ? 1 : 0);
          final SnapshotController snapshot = isPasses
              ? _passesSnapshot
              : _idsSnapshot;
          snapshot.allowSnapshotting = moving;
          return IgnorePointer(
            ignoring: !selected || opacity < 0.1,
            child: ExcludeSemantics(
              excluding: !selected,
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: reduced
                      ? Offset.zero
                      : Offset(isPasses ? 12 * (1 - t) : -12 * t, 0),
                  child: TickerMode(
                    enabled: opacity > 0 && !moving,
                    child: SnapshotWidget(
                      controller: snapshot,
                      // A tab may hold a platform view (a map); it is drawn
                      // live rather than refusing to snapshot.
                      mode: SnapshotMode.permissive,
                      child: RepaintBoundary(child: child),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            layer(widget.ids, isPasses: false),
            layer(widget.passes, isPasses: true),
          ],
        );
      },
    );
  }
}
