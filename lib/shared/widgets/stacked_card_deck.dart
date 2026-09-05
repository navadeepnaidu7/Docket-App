import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/haptics/haptic_service.dart';

/// Where one card sits relative to the front of the deck.
@immutable
class DeckSlot {
  const DeckSlot({
    required this.dx,
    required this.scale,
    required this.opacity,
  });

  final double dx;
  final double scale;
  final double opacity;
}

/// The deck's shape, as one pure function of distance from the active card.
///
/// Continuous in `distance` on purpose: a slot has to be defined mid-drag, not
/// only at whole indices.
@immutable
class DeckGeometry {
  const DeckGeometry({
    this.spread = 44,
    this.falloff = 0.80,
    this.scaleStep = 0.955,
    this.depthFadeStart = 2.3,
    this.depthFadeEnd = 3.4,
    this.exitTravel = 120,
    this.exitLift = 0.035,
  });

  /// Offset of the card directly behind the active one.
  final double spread;

  /// Each step deeper adds [falloff] times the step before it, so the stack
  /// compresses with depth and the total offset is bounded — cards can never
  /// walk off to infinity however long the wallet gets.
  final double falloff;

  /// Multiplied per unit of depth.
  final double scaleStep;

  /// A card fades in over this window rather than appearing at full strength.
  final double depthFadeStart;
  final double depthFadeEnd;

  /// How far a card slides left as it is dealt off the top.
  final double exitTravel;

  /// Slight scale-up on the way out, so it reads as lifting off the deck.
  final double exitLift;

  /// Furthest a card can ever sit from the centre. The geometric series
  /// converges here; nothing is drawn past it.
  double get maxSpread => spread / (1 - falloff);

  DeckSlot slotFor(double distance) {
    if (distance >= 0) {
      return DeckSlot(
        dx: spread * (1 - math.pow(falloff, distance)) / (1 - falloff),
        scale: math.pow(scaleStep, distance).toDouble(),
        opacity: distance <= depthFadeStart
            ? 1
            : (1 - (distance - depthFadeStart) /
                      (depthFadeEnd - depthFadeStart))
                  .clamp(0.0, 1.0),
      );
    }

    final double away = -distance;
    final double t = Curves.easeOutCubic.transform(away.clamp(0.0, 1.0));
    return DeckSlot(
      dx: -exitTravel * t,
      scale: 1 + exitLift * t,
      opacity: (1 - away).clamp(0.0, 1.0),
    );
  }
}

/// Fractional position in the deck — the deck's analogue of
/// [PageController.page], and what the dot indicator reads.
class DeckController extends ChangeNotifier {
  DeckController({double initialPosition = 0}) : _position = initialPosition;

  double _position;
  double get position => _position;

  /// Nearest whole card.
  int get index => _position.round();

  /// Set by the attached [StackedCardDeck] so [animateToIndex] can reach its
  /// ticker. Null while no deck is mounted.
  void Function(int index)? _animate;

  void animateToIndex(int index) => _animate?.call(index);

  void _setPosition(double value) {
    if (value == _position) return;
    _position = value;
    notifyListeners();
  }
}

/// A horizontal deck of heavily overlapping cards.
///
/// Depth comes from X offset, overlap, paint order and scale — the cards stay
/// flat and parallel on a shared baseline. Spec in `docs/features/pass-deck.md`.
///
/// Cards paint in **descending index** and that order never changes. Sorting by
/// distance from the active card instead would swap two equally-scaled,
/// heavily-overlapped cards in a single frame halfway through every swipe.
class StackedCardDeck extends StatefulWidget {
  const StackedCardDeck({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.controller,
    this.geometry = const DeckGeometry(),
    this.sideInset = 56,
  });

  final int itemCount;

  /// Built for the visible window only — a wallet of thirty passes never has
  /// thirty card faces alive.
  final Widget Function(BuildContext context, int index) itemBuilder;

  final DeckController controller;
  final DeckGeometry geometry;

  /// Reserved on each side of the active card. This is the gap the cards behind
  /// it show through, so it is what makes the deck a deck.
  final double sideInset;

  @override
  State<StackedCardDeck> createState() => _StackedCardDeckState();
}

class _StackedCardDeckState extends State<StackedCardDeck>
    with SingleTickerProviderStateMixin {
  /// Holds the fractional position for both the drag and the settle, so the
  /// two can never disagree about where the deck is.
  late final AnimationController _motion;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 220,
    ratio: 0.86,
  );

  /// Pixels of drag that advance the deck by one card. Derived from the card
  /// width in [build] so the gesture feels the same on any screen.
  double _dragUnit = 220;

  int _detent = 0;

  double get _maxPosition => math.max(0, widget.itemCount - 1).toDouble();

  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(
      vsync: this,
      value: widget.controller.position.clamp(0.0, _maxPosition),
    )..addListener(_syncController);
    _detent = _motion.value.round();
    widget.controller._animate = _animateToIndex;
  }

  @override
  void didUpdateWidget(covariant StackedCardDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._animate = null;
      widget.controller._animate = _animateToIndex;
    }
    // The wallet can shrink under the deck — a pass is removed, a filter is
    // applied — and leave the position pointing past the end.
    if (_motion.value > _maxPosition) {
      _motion.stop();
      _motion.value = _maxPosition;
    }
  }

  @override
  void dispose() {
    if (widget.controller._animate == _animateToIndex) {
      widget.controller._animate = null;
    }
    _motion.dispose();
    super.dispose();
  }

  void _syncController() {
    widget.controller._setPosition(_motion.value);
    final int nearest = _motion.value.round();
    if (nearest != _detent) {
      _detent = nearest;
      HapticService.select();
    }
  }

  void _animateToIndex(int index) {
    _springTo(index.clamp(0, _maxPosition.toInt()).toDouble(), 0);
  }

  void _springTo(double target, double velocity) {
    _motion
      ..stop()
      ..animateWith(
        SpringSimulation(_spring, _motion.value, target, velocity),
      );
  }

  void _onDragStart(DragStartDetails _) => _motion.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    double delta = -(details.primaryDelta ?? 0) / _dragUnit;
    final double at = _motion.value;
    // Rubber band rather than a wall once the drag runs past either end.
    if (at < 0 || at > _maxPosition) delta *= 0.32;
    _motion.value = at + delta;
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = -(details.primaryVelocity ?? 0) / _dragUnit;
    final double at = _motion.value;

    double target = at.roundToDouble();
    if (velocity.abs() > 1.6) {
      target = velocity > 0 ? at.floorToDouble() + 1 : at.ceilToDouble() - 1;
    }
    _springTo(target.clamp(0.0, _maxPosition), velocity);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = math.max(
          80,
          constraints.maxWidth - widget.sideInset * 2,
        );
        _dragUnit = cardWidth * 0.62;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (BuildContext context, Widget? _) =>
                _buildDeck(context, cardWidth),
          ),
        );
      },
    );
  }

  Widget _buildDeck(BuildContext context, double cardWidth) {
    final DeckGeometry geometry = widget.geometry;
    final double position = _motion.value;

    final int first = math.max(0, (position - 1).floor());
    final int last = math.min(
      widget.itemCount - 1,
      (position + geometry.depthFadeEnd).ceil(),
    );

    final List<Widget> layers = <Widget>[];
    // Descending index: the deepest card is painted first and index 0 ends up
    // on top. This order is fixed — see the class doc.
    for (int index = last; index >= first; index--) {
      final DeckSlot slot = geometry.slotFor(index - position);
      if (slot.opacity <= 0.01) continue;

      // An Opacity(0) widget still hit-tests, and a card faded to nothing
      // sitting over the active one would swallow its taps.
      final bool isFront = index == _detent;
      final bool interactive = slot.opacity >= 0.5;

      Widget card = Center(
        child: SizedBox(
          width: cardWidth,
          child: widget.itemBuilder(context, index),
        ),
      );

      if (!isFront) {
        card = IgnorePointer(child: card);
        if (interactive) {
          card = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _animateToIndex(index),
            child: card,
          );
        }
      }

      layers.add(
        Positioned.fill(
          key: ValueKey<int>(index),
          child: IgnorePointer(
            ignoring: !interactive,
            child: Opacity(
              opacity: slot.opacity,
              child: Transform.translate(
                offset: Offset(slot.dx, 0),
                child: Transform.scale(
                  scale: slot.scale,
                  child: RepaintBoundary(child: card),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Cards deeper in the stack are allowed to run past the viewport edge; the
    // deck should read as continuing beyond it.
    return Stack(clipBehavior: Clip.none, children: layers);
  }
}
