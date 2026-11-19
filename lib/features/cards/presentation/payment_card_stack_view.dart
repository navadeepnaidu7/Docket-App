import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import '../../../core/haptics/haptic_service.dart';
import '../domain/card_number.dart';
import '../domain/payment_card.dart';
import 'wallet_payment_card.dart';

/// The faces carry the select/open actions; only payment cards share this page.
class PaymentCardStackView extends StatefulWidget {
  const PaymentCardStackView({
    super.key,
    required this.cards,
    required this.onOpen,
    this.onRemove,
    this.revealCardId,
    this.isActive = true,
  });
  final List<PaymentCard> cards;
  final ValueChanged<PaymentCard> onOpen;
  final ValueChanged<PaymentCard>? onRemove;
  final ValueNotifier<String?>? revealCardId;
  final bool isActive;
  @override
  State<PaymentCardStackView> createState() => _PaymentCardStackViewState();
}

class _PaymentCardStackViewState extends State<PaymentCardStackView> {
  final _scroll = ScrollController();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    widget.revealCardId?.addListener(_revealRequested);
    _revealRequested();
  }

  @override
  void didUpdateWidget(PaymentCardStackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.cards.any((card) => card.id == _selectedId)) _selectedId = null;
    if (oldWidget.revealCardId != widget.revealCardId) {
      oldWidget.revealCardId?.removeListener(_revealRequested);
      widget.revealCardId?.addListener(_revealRequested);
      _revealRequested();
    }
  }

  void _revealRequested() {
    final id = widget.revealCardId?.value;
    if (id == null || !widget.cards.any((card) => card.id == id)) return;
    _select(id);
    widget.revealCardId?.value = null;
  }

  void _select(String? id) => setState(() => _selectedId = id);
  void _returnToStack() {
    HapticService.select();
    _select(null);
  }

  void _switchCard(int direction) {
    final current = widget.cards.indexWhere((card) => card.id == _selectedId);
    final next = current + direction;
    if (current < 0 || next < 0 || next >= widget.cards.length) return;
    HapticService.select();
    _select(widget.cards[next].id);
  }

  @override
  void dispose() {
    widget.revealCardId?.removeListener(_revealRequested);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedId;
    final remaining = widget.cards
        .where((card) => card.id != selected)
        .toList();
    final ranks = {
      for (int i = 0; i < remaining.length; i++) remaining[i].id: i,
    };
    return PopScope<void>(
      canPop: !widget.isActive || selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isActive && selected != null) _returnToStack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 440.0);
          final cardHeight = width * 277 / 440;
          // Keep bank marks readable even at 15 cards; browse rather than squash.
          final strip = math.max(56.0, width * 88 / 440);
          final deckTop = selected == null ? 0.0 : cardHeight + 48;
          final contentHeight = selected == null
              ? cardHeight + math.max(0, widget.cards.length - 1) * strip
              : remaining.isEmpty
              ? cardHeight + 48
              : deckTop + cardHeight + (remaining.length - 1) * strip;
          final paintOrder = [
            ...remaining,
            if (selected != null)
              widget.cards.firstWhere((card) => card.id == selected),
          ];
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                key: const Key('payment-card-stack-scroll'),
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  height: math.max(contentHeight + 24, constraints.maxHeight),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final card in paintOrder)
                        _StackFace(
                          key: ValueKey('stack-face-${card.id}'),
                          card: card,
                          width: width,
                          cardHeight: cardHeight,
                          scroll: _scroll,
                          top: card.id == selected
                              ? 0
                              : deckTop + ranks[card.id]! * strip,
                          clipTop: card.id == selected ? 0 : deckTop,
                          visibleHeight:
                              card.id == selected ||
                                  card == remaining.lastOrNull
                              ? cardHeight
                              : strip + 20,
                          selected: card.id == selected,
                          active: widget.isActive && card.id == selected,
                          onSwitch: _switchCard,
                          onReturn: _returnToStack,
                          onTap: () {
                            if (card.id == _selectedId) {
                              widget.onOpen(card);
                            } else {
                              HapticService.select();
                              _select(card.id);
                            }
                          },
                          onLongPress: widget.onRemove == null
                              ? null
                              : () => widget.onRemove!(card),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Independent springs retain live position and velocity. Scroll compensation
/// pins the selected face without rebuilding its artwork on each scroll frame.
class _StackFace extends StatefulWidget {
  const _StackFace({
    super.key,
    required this.card,
    required this.width,
    required this.cardHeight,
    required this.top,
    required this.clipTop,
    required this.visibleHeight,
    required this.selected,
    required this.active,
    required this.scroll,
    required this.onTap,
    required this.onSwitch,
    required this.onReturn,
    this.onLongPress,
  });
  final PaymentCard card;
  final double width;
  final double cardHeight;
  final double top;
  final double clipTop;
  final double visibleHeight;
  final bool selected;
  final bool active;
  final ScrollController scroll;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<int> onSwitch;
  final VoidCallback onReturn;
  @override
  State<_StackFace> createState() => _StackFaceState();
}

class _StackFaceState extends State<_StackFace> with TickerProviderStateMixin {
  late final _top = AnimationController.unbounded(
    vsync: this,
    value: widget.top,
  );
  late final _height = AnimationController.unbounded(
    vsync: this,
    value: widget.visibleHeight,
  );
  late final _clipTop = AnimationController.unbounded(
    vsync: this,
    value: widget.clipTop,
  );
  late final _press = AnimationController.unbounded(vsync: this);
  late final _dragX = AnimationController.unbounded(vsync: this);
  late final _dragY = AnimationController.unbounded(vsync: this);
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: .96,
  );
  double get _scrollOffset =>
      widget.scroll.hasClients ? widget.scroll.offset : 0;

  void _move(
    AnimationController controller,
    double target, {
    double? velocity,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = target;
    } else {
      controller.animateWith(
        SpringSimulation(
          _spring,
          controller.value,
          target,
          velocity ?? controller.velocity,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(_StackFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      // Convert coordinates without moving the currently visible face.
      final velocity = _top.velocity;
      _top.value += oldWidget.selected ? _scrollOffset : -_scrollOffset;
      _move(_top, widget.top, velocity: velocity);
    } else if (oldWidget.top != widget.top) {
      _move(_top, widget.top);
    }
    if (oldWidget.visibleHeight != widget.visibleHeight) {
      _move(_height, widget.visibleHeight);
    }
    if (oldWidget.clipTop != widget.clipTop) _move(_clipTop, widget.clipTop);
  }

  void _horizontalStart(DragStartDetails _) {
    _holdLift();
    _dragX.stop();
  }

  void _horizontalUpdate(DragUpdateDetails details) =>
      _dragX.value += details.delta.dx;
  void _horizontalEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragX.value.abs() > widget.width * .2 || velocity.abs() > 550) {
      widget.onSwitch(
        (velocity.abs() > 550 ? velocity : _dragX.value) < 0 ? 1 : -1,
      );
    }
    _move(_dragX, 0, velocity: velocity);
    _resumeLift();
  }

  void _verticalStart(DragStartDetails _) {
    _holdLift();
    _dragY.stop();
  }

  void _verticalUpdate(DragUpdateDetails details) {
    final dy = details.delta.dy;
    _dragY.value =
        (_dragY.value + (dy < 0 && _dragY.value <= 0 ? dy * .15 : dy)).clamp(
          -20,
          widget.cardHeight * .8,
        );
  }

  void _verticalEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragY.value > 56 || velocity > 650) widget.onReturn();
    _move(_dragY, 0, velocity: velocity);
    _resumeLift();
  }

  void _holdLift() {
    _top.stop();
    _height.stop();
    _clipTop.stop();
    _move(_press, 0);
  }

  void _resumeLift() {
    _move(_top, widget.top);
    _move(_height, widget.visibleHeight);
    _move(_clipTop, widget.clipTop);
  }

  void _cancelDrag(AnimationController controller) {
    _move(controller, 0);
    _resumeLift();
  }

  @override
  void dispose() {
    for (final controller in [
      _top,
      _height,
      _clipTop,
      _press,
      _dragX,
      _dragY,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _top,
        _height,
        _clipTop,
        _press,
        _dragX,
        _dragY,
        widget.scroll,
      ]),
      builder: (context, child) {
        final scroll = _scrollOffset;
        final top = _top.value + (widget.selected ? scroll : 0);
        final clipTop = math.max(0.0, _clipTop.value + scroll - top);
        final height = _height.value.clamp(0.0, widget.cardHeight);
        final handleOpacity =
            ((height / widget.cardHeight - .6) / .4).clamp(0.0, 1.0) *
            ((48 - _top.value.abs()) / 48).clamp(0.0, 1.0);
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          height: height + (widget.selected ? 48 : 0),
          child: ClipRect(
            clipper: _DeckClip(clipTop),
            clipBehavior: widget.selected ? Clip.none : Clip.hardEdge,
            child: Transform.translate(
              offset: Offset(_dragX.value, _dragY.value),
              child: Transform.rotate(
                angle: MediaQuery.disableAnimationsOf(context)
                    ? 0
                    : _dragX.value / widget.width * .025,
                child: Transform.scale(
                  scale: 1 - _press.value.clamp(0, 1) * .014,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: height,
                        child: Semantics(
                          button: true,
                          selected: widget.selected,
                          label:
                              '${card.displayBank}, ${card.network?.label ?? 'card'}, '
                              '${card.kind == CardKind.unset ? '' : '${card.kind.name}, '}'
                              'ending in ${card.lastFour}',
                          hint: widget.selected
                              ? 'Open card details'
                              : 'Bring card forward',
                          onTap: widget.onTap,
                          onLongPress: widget.onLongPress,
                          customSemanticsActions: widget.selected
                              ? {
                                  const CustomSemanticsAction(
                                    label: 'Next card',
                                  ): () =>
                                      widget.onSwitch(1),
                                  const CustomSemanticsAction(
                                    label: 'Previous card',
                                  ): () =>
                                      widget.onSwitch(-1),
                                  const CustomSemanticsAction(
                                    label: 'Return to card stack',
                                  ): widget.onReturn,
                                }
                              : null,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            excludeFromSemantics: true,
                            onTapDown: (_) => _move(_press, 1),
                            onTapUp: (_) => _move(_press, 0),
                            onTapCancel: () => _move(_press, 0),
                            onTap: widget.onTap,
                            onLongPress: widget.onLongPress,
                            onHorizontalDragStart: widget.selected
                                ? _horizontalStart
                                : null,
                            onHorizontalDragUpdate: widget.selected
                                ? _horizontalUpdate
                                : null,
                            onHorizontalDragEnd: widget.selected
                                ? _horizontalEnd
                                : null,
                            onHorizontalDragCancel: widget.selected
                                ? () => _cancelDrag(_dragX)
                                : null,
                            onVerticalDragStart: widget.selected
                                ? _verticalStart
                                : null,
                            onVerticalDragUpdate: widget.selected
                                ? _verticalUpdate
                                : null,
                            onVerticalDragEnd: widget.selected
                                ? _verticalEnd
                                : null,
                            onVerticalDragCancel: widget.selected
                                ? () => _cancelDrag(_dragY)
                                : null,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minHeight: widget.cardHeight,
                                maxHeight: widget.cardHeight,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.selected)
                        Positioned(
                          top: height + 2,
                          left: (widget.width - 64) / 2,
                          child: Opacity(
                            opacity: handleOpacity,
                            child: IgnorePointer(
                              ignoring: handleOpacity < .5,
                              child: ExcludeSemantics(
                                excluding: handleOpacity < .5,
                                child: SizedBox(
                                  width: 64,
                                  height: 44,
                                  child: IconButton(
                                    key: const Key('return-to-card-stack'),
                                    tooltip: 'Return to card stack',
                                    onPressed: widget.onReturn,
                                    icon: Container(
                                      width: 28,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: .22),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: WalletPaymentCard(
            card: card,
            interactive: false,
            animate: widget.active,
            motionIsPinned: true,
          ),
        ),
      ),
    );
  }
}

class _DeckClip extends CustomClipper<Rect> {
  const _DeckClip(this.top);
  final double top;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, top.clamp(0, size.height), size.width, size.height);
  @override
  bool shouldReclip(_DeckClip oldClipper) => oldClipper.top != top;
}
