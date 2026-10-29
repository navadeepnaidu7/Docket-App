import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shining_action_label.dart';

enum _TrashSwipeStage { sliding, settling, confirming, deleting }

/// A swipe that reveals its final confirmation in the same bottom control.
class SwipeToEmptyTrash extends StatefulWidget {
  const SwipeToEmptyTrash({
    super.key,
    required this.itemIds,
    required this.onDelete,
  });

  final List<String> itemIds;
  final Future<void> Function(List<String> reviewedIds) onDelete;

  int get itemCount => itemIds.length;

  @override
  State<SwipeToEmptyTrash> createState() => _SwipeToEmptyTrashState();
}

class _SwipeToEmptyTrashState extends State<SwipeToEmptyTrash>
    with SingleTickerProviderStateMixin {
  static const double _inset = 8;
  static const double _thumbSize = 52;
  static const double _threshold = 0.92;
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 350,
    damping: 38,
  );

  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
  );
  _TrashSwipeStage _stage = _TrashSwipeStage.sliding;
  List<String> _reviewedIds = const [];
  double _width = 360;
  double _height = 68;
  double _travel = 292;
  double _direction = 1;
  double _dragOrigin = 0;
  double _startProgress = 0;
  bool _accepted = false;
  bool _pressed = false;
  bool _armedHaptic = false;
  bool _focused = false;
  bool _restoreFocus = false;

  double get _progress => _motion.value.clamp(0.0, 1.0);
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  bool get _canSlide =>
      _stage == _TrashSwipeStage.sliding && widget.itemCount > 0;
  bool get _deleting => _stage == _TrashSwipeStage.deleting;

  @override
  void didUpdateWidget(SwipeToEmptyTrash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.itemIds, widget.itemIds) && !_deleting) {
      _motion.stop();
      _stage = _TrashSwipeStage.sliding;
      _reviewedIds = const [];
      _accepted = false;
      _pressed = false;
      _restoreFocus = false;
      _returnHome();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _onDown(DragDownDetails details) {
    if (!_canSlide || _travel <= 0) return;
    final double leading = _inset + _travel * _progress;
    final double left = _direction == 1
        ? leading
        : _width - leading - _thumbSize;
    final double top = (_height - _thumbSize) / 2;
    if (details.localPosition.dx < left - 4 ||
        details.localPosition.dx > left + _thumbSize + 4 ||
        details.localPosition.dy < top - 4 ||
        details.localPosition.dy > top + _thumbSize + 4) {
      return;
    }
    _motion.stop();
    _dragOrigin = details.globalPosition.dx;
    _startProgress = _progress;
    _accepted = true;
    _armedHaptic = false;
    setState(() => _pressed = true);
    HapticService.tap();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!_accepted || !_canSlide) return;
    if (_travel <= 0) {
      _onCancel();
      return;
    }
    final double distance = details.globalPosition.dx - _dragOrigin;
    _motion.value = (_startProgress + distance * _direction / _travel).clamp(
      0.0,
      1.0,
    );
    if (_progress >= _threshold && !_armedHaptic) {
      _armedHaptic = true;
      HapticService.select();
    }
  }

  void _onEnd(DragEndDetails details) {
    if (!_accepted || !_canSlide) return;
    if (_travel <= 0) {
      _onCancel();
      return;
    }
    _accepted = false;
    setState(() => _pressed = false);
    if (_progress >= _threshold) {
      _requestConfirmation();
    } else {
      _returnHome(
        velocity: (details.primaryVelocity ?? 0) * _direction / _travel,
      );
    }
  }

  void _onCancel() {
    if (!_accepted || !_canSlide) return;
    _accepted = false;
    setState(() => _pressed = false);
    _returnHome();
  }

  void _returnHome({double velocity = 0}) {
    if (_reduced) {
      _motion.value = 0;
    } else {
      _motion.animateWith(
        SpringSimulation(_spring, _progress, 0, velocity.clamp(-4.0, 4.0)),
      );
    }
  }

  Future<void> _requestConfirmation() async {
    if (!_canSlide) return;
    _reviewedIds = List<String>.unmodifiable(widget.itemIds);
    setState(() {
      _stage = _TrashSwipeStage.settling;
      _accepted = false;
      _pressed = false;
      _focused = false;
    });
    try {
      if (_reduced) {
        _motion.value = 1;
      } else {
        await _motion
            .animateTo(
              1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
            )
            .orCancel;
      }
      if (!mounted ||
          _stage != _TrashSwipeStage.settling ||
          !listEquals(_reviewedIds, widget.itemIds)) {
        return;
      }
      setState(() => _stage = _TrashSwipeStage.confirming);
      HapticService.confirm();
    } on TickerCanceled {
      // A changed list, Back, or disposal cancels the pending reveal.
    }
  }

  void _cancelConfirmation() {
    if (_deleting || _stage == _TrashSwipeStage.sliding) return;
    _motion.stop();
    setState(() {
      _stage = _TrashSwipeStage.sliding;
      _reviewedIds = const [];
      _restoreFocus = true;
    });
    HapticService.tap();
    _returnHome();
  }

  Future<void> _delete() async {
    if (_stage != _TrashSwipeStage.confirming) return;
    if (!listEquals(_reviewedIds, widget.itemIds)) {
      _cancelConfirmation();
      return;
    }
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final List<String> reviewed = _reviewedIds;
    setState(() => _stage = _TrashSwipeStage.deleting);
    try {
      await widget.onDelete(reviewed);
    } catch (_) {
      if (messenger != null && messenger.mounted) {
        HapticService.error();
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't finish emptying Trash. Please try again."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _stage = _TrashSwipeStage.sliding;
          _reviewedIds = const [];
          _restoreFocus = true;
        });
        _returnHome();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = AppTheme.ink(Brightness.dark);
    final Color handleInk = AppTheme.ink(Brightness.light);
    final Color top = dark
        ? AppTheme.surface(Brightness.dark)
        : AppTheme.elevated(Brightness.dark);
    final Color bottom = dark
        ? AppTheme.background(Brightness.dark)
        : AppTheme.surface(Brightness.dark);
    final double height = math.max(
      68,
      MediaQuery.textScalerOf(context).scale(16) * 2.3 + 24,
    );

    return PopScope<Object?>(
      canPop: _stage == _TrashSwipeStage.sliding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_deleting) _cancelConfirmation();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.hasBoundedWidth ? constraints.maxWidth : 360;
            _height = height;
            _travel = math.max(0, _width - _thumbSize - 2 * _inset);
            _direction = Directionality.of(context) == TextDirection.ltr
                ? 1
                : -1;
            return AnimatedSize(
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              alignment: Alignment.bottomCenter,
              curve: Curves.easeInOutCubic,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final double p = _progress;
                  return Container(
                    width: _width,
                    constraints: BoxConstraints(minHeight: height),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [top, bottom],
                      ),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.18 : 0.08,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: ink.withValues(
                          alpha: _focused ? 0.72 : 0.12 + 0.05 * p,
                        ),
                        width: _focused ? 2 : 1,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: _reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      reverseDuration: _reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (context, child) {
                          final bool leaving =
                              animation.status == AnimationStatus.reverse;
                          return ExcludeFocus(
                            excluding: leaving,
                            child: ExcludeSemantics(
                              excluding: leaving,
                              child: IgnorePointer(
                                ignoring: leaving,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      child: _deleting
                          ? _progressView(height, ink)
                          : _stage == _TrashSwipeStage.confirming
                          ? _confirmation(height, ink, handleInk, bottom)
                          : _slider(height, ink, handleInk, bottom),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _slider(double height, Color ink, Color handleInk, Color bottom) {
    return Semantics(
      key: const ValueKey('slide'),
      button: true,
      enabled: _canSlide,
      label: 'Empty Trash',
      hint: 'Slide to review a confirmation. Nothing is deleted by the swipe.',
      onTap: _canSlide ? _requestConfirmation : null,
      child: FocusableActionDetector(
        enabled: _canSlide,
        autofocus: _restoreFocus,
        includeFocusSemantics: false,
        onShowFocusHighlight: (value) {
          if (mounted) setState(() => _focused = value);
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _requestConfirmation();
              return null;
            },
          ),
        },
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragDown: _canSlide ? _onDown : null,
            onHorizontalDragUpdate: _canSlide ? _onUpdate : null,
            onHorizontalDragEnd: _canSlide ? _onEnd : null,
            onHorizontalDragCancel: _canSlide ? _onCancel : null,
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: _inset + _thumbSize + _travel * _progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        gradient: LinearGradient(
                          colors: [
                            ink.withValues(alpha: _progress * 0.015),
                            ink.withValues(alpha: _progress * 0.075),
                          ],
                          begin: _direction == 1
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          end: _direction == 1
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: _thumbSize + 2 * _inset,
                    end: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (1 - _progress * 2).clamp(0.0, 1.0),
                        child: RepaintBoundary(
                          child: ShiningActionLabel(
                            label: 'Slide to empty',
                            enabled:
                                _canSlide && !_accepted && _progress < 0.001,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            height: 1.15,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            color: ink,
                            baseOpacity: 0.64,
                            showArrow: false,
                            glow: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 16,
                    end: _thumbSize + 2 * _inset,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _accepted && _progress >= _threshold ? 1 : 0,
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 120),
                        child: Text(
                          'Release to review',
                          textAlign: TextAlign.center,
                          style: AppFonts.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: _inset + _travel * _progress,
                    top: (height - _thumbSize) / 2,
                    child: AnimatedScale(
                      scale: _pressed ? 1.035 : 1,
                      duration: _reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 110),
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        decoration: _silver(ink, bottom, circular: true),
                        child: Center(
                          child: CustomPaint(
                            size: const Size.square(22),
                            painter: _SlideChevron(
                              color: handleInk,
                              direction: _direction,
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
  }

  Widget _confirmation(
    double height,
    Color ink,
    Color handleInk,
    Color bottom,
  ) {
    final String count = widget.itemCount == 1
        ? '1 doc'
        : '${widget.itemCount} docs';
    final Widget copy = Semantics(
      liveRegion: true,
      child: Text(
        'Delete $count\npermanently?',
        style: AppFonts.ui(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.15,
          height: 1.25,
          color: ink.withValues(alpha: 0.94),
        ),
      ),
    );
    final Widget cancel = TextButton(
      autofocus: true,
      onPressed: _cancelConfirmation,
      style: TextButton.styleFrom(
        foregroundColor: ink.withValues(alpha: 0.82),
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        textStyle: AppFonts.ui(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: const Text('Cancel'),
    );
    final Widget empty = DecoratedBox(
      decoration: _silver(ink, bottom),
      child: TextButton(
        onPressed: _delete,
        style: TextButton.styleFrom(
          foregroundColor: Color.lerp(AppTheme.danger, handleInk, 0.28),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: AppFonts.ui(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: const Text('Delete'),
      ),
    );
    final bool stacked =
        _width < 330 || MediaQuery.textScalerOf(context).scale(14) > 20;
    return CallbackShortcuts(
      key: const ValueKey('confirm'),
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancelConfirmation,
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: 8),
                        Expanded(child: empty),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 8),
                    cancel,
                    const SizedBox(width: 4),
                    empty,
                  ],
                ),
        ),
      ),
    );
  }

  Widget _progressView(double height, Color ink) => Semantics(
    key: const ValueKey('deleting'),
    liveRegion: true,
    label: 'Emptying Trash',
    child: ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            ),
            const SizedBox(width: 12),
            Text(
              'Emptying Trash',
              style: AppFonts.ui(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: ink.withValues(alpha: 0.90),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  BoxDecoration _silver(Color ink, Color bottom, {bool circular = false}) =>
      BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular
            ? null
            : BorderRadius.circular(AppTheme.radiusPill),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.48, 1],
          colors: [
            ink,
            Color.lerp(ink, bottom, 0.04)!,
            Color.lerp(ink, bottom, 0.18)!,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _pressed ? 0.42 : 0.28),
            blurRadius: _pressed ? 16 : 8,
            offset: Offset(0, _pressed ? 5 : 2),
          ),
        ],
      );
}

class _SlideChevron extends CustomPainter {
  const _SlideChevron({required this.color, required this.direction});

  final Color color;
  final double direction;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(direction, 1);
    canvas.drawPath(
      Path()
        ..moveTo(-3, -6)
        ..lineTo(3, 0)
        ..lineTo(-3, 6),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlideChevron oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}
