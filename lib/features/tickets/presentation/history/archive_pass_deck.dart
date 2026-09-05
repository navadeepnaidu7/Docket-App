import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/history_folder.dart';
import '../../domain/movie_pass_models.dart';
import '../../domain/pass_activity_date.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import '../bus/bus_pass_detail_screen.dart';
import '../bus/bus_ticket_face.dart';
import '../movie/movie_brand_style.dart';
import '../movie_pass_detail_screen.dart';
import '../ticket_detail_screen.dart';
import '../train/train_ticket_face.dart';
import 'movie_poster_art.dart';

/// A tactile archive browser: one continuously moving, overlapping card deck.
///
/// [_position] is measured in cards rather than pixels. Keeping the deck and
/// dial on the same fractional value is what makes them feel like one control.
class ArchivePassDeck extends StatefulWidget {
  const ArchivePassDeck({
    super.key,
    required this.category,
    required this.items,
    required this.onRemove,
  });

  final PassHistoryCategory category;
  final List<WalletPassItem> items;
  final ValueChanged<WalletPassItem> onRemove;

  static const Key dialKey = Key('archive_pass_deck.dial');
  static const Key dateKey = Key('archive_pass_deck.date');

  static Key cardKey(String id) => ValueKey<String>('archive-pass-$id');

  @override
  State<ArchivePassDeck> createState() => ArchivePassDeckState();
}

class ArchivePassDeckState extends State<ArchivePassDeck>
    with TickerProviderStateMixin {
  late final AnimationController _position;
  late final AnimationController _dialEngagement;

  /// The pass under the needle. Held as its own notifier so the dial's slider
  /// semantics rebuild once per pass rather than once per frame of a scrub.
  final ValueNotifier<int> _focused = ValueNotifier<int>(0);

  double _cardStep = 1;
  double _dialWidth = 1;
  double _dragStartX = 0;
  double _dragStartPosition = 0;
  bool _dragging = false;
  bool _dialScrubbing = false;
  int? _lastDetent;
  bool _atBoundary = false;
  Duration _lastDetentAt = Duration.zero;
  final Stopwatch _hapticClock = Stopwatch()..start();

  @visibleForTesting
  double get debugPosition => _position.value;

  @visibleForTesting
  int get debugFocused => _focused.value;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(vsync: this)
      ..addListener(_syncFocused);
    _dialEngagement = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didUpdateWidget(covariant ArchivePassDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameItemOrder(oldWidget.items, widget.items)) return;

    final int oldIndex = _nearestIndex(oldWidget.items.length);
    final String? selectedId = oldWidget.items.isEmpty
        ? null
        : oldWidget.items[oldIndex].id;
    final int retained = selectedId == null
        ? -1
        : widget.items.indexWhere(
            (WalletPassItem item) => item.id == selectedId,
          );
    final int fallback = _position.value.round().clamp(
      0,
      math.max(0, widget.items.length - 1),
    );
    _position.value = (retained >= 0 ? retained : fallback).toDouble();
    _syncFocused();
  }

  bool _sameItemOrder(
    List<WalletPassItem> previous,
    List<WalletPassItem> next,
  ) {
    if (previous.length != next.length) return false;
    for (int index = 0; index < previous.length; index++) {
      if (previous[index].id != next[index].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _position.removeListener(_syncFocused);
    _position.dispose();
    _dialEngagement.dispose();
    _focused.dispose();
    super.dispose();
  }

  void _syncFocused() {
    final int nearest = _nearestIndex(widget.items.length);
    if (_focused.value != nearest) _focused.value = nearest;
  }

  /// Detents are only worth feeling if they can be felt apart. A fast scrub
  /// crosses ticks quicker than the actuator can resolve them, and firing
  /// every one turns a ruler into a buzz.
  static const Duration _minDetentGap = Duration(milliseconds: 28);

  void _detent() {
    final Duration now = _hapticClock.elapsed;
    if (now - _lastDetentAt < _minDetentGap) return;
    _lastDetentAt = now;
    HapticService.select();
  }

  int _detentsPerPass({required bool dial}) =>
      dial ? ArchiveDialPainter.subdivisionsFor(_dialStep) : 1;

  /// The click for arriving at [destination], skipped when the drag already
  /// clicked past that notch on the way there. A detented control is felt as
  /// it passes the notch, not again when it stops moving, and a swipe that
  /// pulses twice a fifth of a second apart reads as a stutter.
  void _landingDetent(double destination) {
    final int detent = (destination * _detentsPerPass(dial: _dialScrubbing))
        .round();
    if (detent == _lastDetent) return;
    _lastDetent = detent;
    _detent();
  }

  int _nearestIndex(int count) {
    if (count == 0) return 0;
    return _position.value.round().clamp(0, count - 1);
  }

  void _beginDrag(DragStartDetails details, {required bool dial}) {
    _position.stop(canceled: false);
    _dragging = true;
    _dialScrubbing = dial;
    _dragStartX = details.globalPosition.dx;
    _dragStartPosition = _position.value;
    _lastDetent = (_position.value * _detentsPerPass(dial: dial)).round();
    _atBoundary = false;
    if (dial) _dialEngagement.forward();
  }

  void _updateDrag(DragUpdateDetails details, {required double step}) {
    if (widget.items.length < 2) return;
    final double dragDistance = details.globalPosition.dx - _dragStartX;
    final double raw = _dragStartPosition - dragDistance / math.max(step, 1);
    final double last = (widget.items.length - 1).toDouble();

    // A small, progressive boundary give keeps the deck attached to the hand
    // without letting an empty card-sized gap enter the viewport.
    if (raw < 0) {
      _position.value = -_rubberband(-raw);
    } else if (raw > last) {
      _position.value = last + _rubberband(raw - last);
    } else {
      _position.value = raw;
    }

    // The deck clicks once per pass; the dial clicks once per drawn tick, so
    // what the ruler shows going by is what the fingertip feels going by.
    final int detent = (_position.value * _detentsPerPass(dial: _dialScrubbing))
        .round();
    if (detent != _lastDetent) {
      _lastDetent = detent;
      _detent();
    }

    final bool pinned = raw < 0 || raw > last;
    if (pinned != _atBoundary) {
      _atBoundary = pinned;
      if (pinned) HapticService.impact();
    }
  }

  double _rubberband(double overshoot) =>
      (overshoot * 0.28) / (1 + overshoot * 0.8);

  void _handleCardDragStart(DragStartDetails details) {
    _beginDrag(details, dial: false);
  }

  void _handleCardDragUpdate(DragUpdateDetails details) {
    _updateDrag(details, step: _cardStep);
  }

  /// Release speed, in passes per second, above which a drag that stopped
  /// short of halfway still commits to the next pass.
  static const double _flickThreshold = 1.1;

  void _handleCardDragEnd(DragEndDetails details) {
    _dragging = false;
    _atBoundary = false;
    if (widget.items.isEmpty) return;

    final double last = (widget.items.length - 1).toDouble();
    final double indexVelocity =
        (-(details.primaryVelocity ?? 0) / math.max(_cardStep, 1)).clamp(
          -8.0,
          8.0,
        );
    final double resting = _position.value.clamp(0, last);

    // The deck moves one pass per gesture. Distance decides where you land; a
    // flick only decides whether a drag that stopped short still counts.
    // Release velocity is deliberately not projected forward — throwing the
    // deck four passes down the archive loses your place faster than it saves
    // time, and the dial below is the tool for actually travelling.
    int target = resting.round();
    if (indexVelocity.abs() >= _flickThreshold) {
      target = indexVelocity > 0 ? resting.ceil() : resting.floor();
    }

    // Carry only what one pass of travel can absorb, so a hard flick lands
    // firmly rather than overshooting the card and springing back.
    _settleTo(target, velocity: indexVelocity.clamp(-3.0, 3.0));
  }

  void _handleCardDragCancel() {
    _dragging = false;
    _dialScrubbing = false;
    _atBoundary = false;
    _settleTo(_nearestIndex(widget.items.length));
  }

  /// Pixels of finger travel per pass — the one gearing the drag, the drawn
  /// ruler and the tap-to-jump all share.
  ///
  /// The archive still spreads across one comfortable sweep, so the gearing
  /// varies with how deep the folder is; the ruler is drawn to match rather
  /// than at a fixed spacing of its own. A scale that slides at a rate the
  /// finger is not driving stops reading as a dial and starts reading as a
  /// slider. Below the floor — past roughly fifty passes — the sweep gives out
  /// before the archive does and it takes a second pull, which is the honest
  /// price of keeping the grip.
  double get _dialStep {
    if (widget.items.length < 2) return math.max(_dialWidth, 1);
    final double sweep = math.max(_dialWidth - 48, 1);
    return math.max(
      ArchiveDialPainter.minPassSpacing,
      sweep / (widget.items.length - 1),
    );
  }

  void _handleDialDragStart(DragStartDetails details) {
    _beginDrag(details, dial: true);
  }

  void _handleDialDragUpdate(DragUpdateDetails details) {
    _updateDrag(details, step: _dialStep);
  }

  void _handleDialDragEnd(DragEndDetails details) {
    _dragging = false;
    _dialScrubbing = false;
    _atBoundary = false;
    _lastDetent = null;
    _dialEngagement.reverse();
    _settleTo(_nearestIndex(widget.items.length));
  }

  void _handleDialDragCancel() {
    _dragging = false;
    _dialScrubbing = false;
    _atBoundary = false;
    _lastDetent = null;
    _dialEngagement.reverse();
    _settleTo(_nearestIndex(widget.items.length));
  }

  void _handleDialTapUp(TapUpDetails details) {
    _dialEngagement.reverse();
    if (widget.items.length < 2) return;
    final double offset = details.localPosition.dx - _dialWidth / 2;
    final int delta = (offset / _dialStep).round();
    if (delta == 0) {
      HapticService.select();
      return;
    }
    final int target = (_nearestIndex(widget.items.length) + delta).clamp(
      0,
      widget.items.length - 1,
    );
    _settleTo(target);
  }

  Future<void> _settleTo(int target, {double velocity = 0}) async {
    if (!mounted || widget.items.isEmpty) return;
    final double destination = target
        .clamp(0, widget.items.length - 1)
        .toDouble();
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _position.value = destination;
      _landingDetent(destination);
      return;
    }

    // Critically damped and deliberately a touch slower than the old snap.
    // Release velocity still carries through, but cannot kick the deck past
    // several cards and force the renderer to catch up in one frame.
    const SpringDescription spring = SpringDescription(
      mass: 1,
      stiffness: 260,
      damping: 32.25,
    );
    try {
      await _position
          .animateWith(
            SpringSimulation(spring, _position.value, destination, velocity),
          )
          .orCancel;
      if (mounted && !_dragging) {
        // Spring simulations finish inside a tolerance. Pinning the final
        // value removes the sub-pixel drift that otherwise keeps two date
        // labels and two near-centre ticks alive after the deck looks settled.
        _position.value = destination;
        _landingDetent(destination);
      }
    } on TickerCanceled {
      // A new touch intentionally interrupts the spring from its live value.
    }
  }

  void _handleCardTap(int index) {
    if (_dragging) return;
    if (index != _nearestIndex(widget.items.length)) {
      _settleTo(index);
      return;
    }
    _open(widget.items[index]);
  }

  void _open(WalletPassItem item) {
    HapticService.confirm();
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    switch (item) {
      case TrainPassItem(:final ticket):
        root.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => TicketDetailScreen(ticket: ticket),
          ),
        );
      case MoviePassItem(:final pass):
        root.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => MoviePassDetailScreen(pass: pass),
          ),
        );
      case BusPassItem(:final pass):
        root.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => BusPassDetailScreen(pass: pass),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableHeight = constraints.maxHeight;
        final double dialHeight = math.min(66, availableHeight * 0.095);
        final double dateHeight = math.min(72, availableHeight * 0.105);
        final double deckHeight = math.max(
          180,
          availableHeight - dialHeight - dateHeight - 18,
        );
        final double cardAspect = widget.category == PassHistoryCategory.movie
            ? _MovieArchiveCard.aspectRatio
            : WalletCardMetrics.ticketAspect;
        final double cardWidth = math.min(
          (deckHeight - 20) * cardAspect,
          constraints.maxWidth * 0.86,
        );
        final double resolvedHeight = cardWidth / cardAspect;
        _cardStep = cardWidth * 0.86;
        _dialWidth = constraints.maxWidth;

        return Column(
          children: <Widget>[
            SizedBox(
              height: deckHeight,
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onHorizontalDragStart: _handleCardDragStart,
                onHorizontalDragUpdate: _handleCardDragUpdate,
                onHorizontalDragEnd: _handleCardDragEnd,
                onHorizontalDragCancel: _handleCardDragCancel,
                child: _CardViewport(
                  categoryLabel: widget.category.label,
                  items: widget.items,
                  position: _position,
                  cardWidth: cardWidth,
                  cardHeight: resolvedHeight,
                  cardStep: _cardStep,
                  onTap: _handleCardTap,
                  onLongPress: (int index) {
                    HapticService.longPress();
                    widget.onRemove(widget.items[index]);
                  },
                ),
              ),
            ),
            SizedBox(
              key: ArchivePassDeck.dialKey,
              height: dialHeight,
              width: double.infinity,
              // Dragging the deck and scrubbing the dial are both gestures a
              // screen reader cannot perform, so the dial doubles as the
              // adjustable control that moves through the archive.
              child: ValueListenableBuilder<int>(
                valueListenable: _focused,
                builder: (BuildContext context, int focused, Widget? child) {
                  final int count = widget.items.length;
                  final int last = math.max(0, count - 1);
                  String at(int index) => '${index + 1} of $count';
                  return Semantics(
                    slider: true,
                    label: '${widget.category.label} archive position',
                    value: at(focused),
                    increasedValue: at(math.min(focused + 1, last)),
                    decreasedValue: at(math.max(focused - 1, 0)),
                    onIncrease: focused < last
                        ? () => _settleTo(focused + 1)
                        : null,
                    onDecrease: focused > 0
                        ? () => _settleTo(focused - 1)
                        : null,
                    child: child,
                  );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onTapDown: (_) => _dialEngagement.forward(),
                  onTapCancel: () => _dialEngagement.reverse(),
                  onTapUp: _handleDialTapUp,
                  onHorizontalDragStart: _handleDialDragStart,
                  onHorizontalDragUpdate: _handleDialDragUpdate,
                  onHorizontalDragEnd: _handleDialDragEnd,
                  onHorizontalDragCancel: _handleDialDragCancel,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ArchiveDialPainter(
                        itemCount: widget.items.length,
                        passSpacing: _dialStep,
                        progress: _position,
                        engagement: _dialEngagement,
                        brightness: Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: dateHeight,
              child: AnimatedBuilder(
                animation: _position,
                builder: (BuildContext context, Widget? child) => _DateReadout(
                  key: ArchivePassDeck.dateKey,
                  items: widget.items,
                  position: _position.value,
                ),
              ),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}

class _CardViewport extends StatelessWidget {
  const _CardViewport({
    required this.categoryLabel,
    required this.items,
    required this.position,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardStep,
    required this.onTap,
    required this.onLongPress,
  });

  final String categoryLabel;
  final List<WalletPassItem> items;
  final Animation<double> position;
  final double cardWidth;
  final double cardHeight;
  final double cardStep;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // These faces are captured once by the AnimatedBuilder. During a drag the
    // expensive poster/ticket subtree is reused byte-for-byte; only the cheap
    // transform, opacity and dimming layers below are updated.
    final List<Widget> faces = <Widget>[
      for (final WalletPassItem item in items)
        RepaintBoundary(
          child: SizedBox(
            key: ArchivePassDeck.cardKey(item.id),
            width: cardWidth,
            height: cardHeight,
            child: _ArchiveCardFace(item: item),
          ),
        ),
    ];

    return Semantics(
      container: true,
      label:
          '$categoryLabel archive, ${items.length} ${items.length == 1 ? 'pass' : 'passes'}',
      child: ClipRect(
        child: AnimatedBuilder(
          animation: position,
          builder: (BuildContext context, Widget? child) {
            final double value = position.value;
            final int focused = value.round().clamp(0, items.length - 1);
            final List<int> visible =
                <int>[
                  for (int i = 0; i < items.length; i++)
                    if ((i - value).abs() <= 3.4) i,
                ]..sort((int a, int b) {
                  final int byDistance = (b - value).abs().compareTo(
                    (a - value).abs(),
                  );
                  return byDistance != 0 ? byDistance : a.compareTo(b);
                });

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final int index in visible)
                  _PositionedArchiveCard(
                    key: ValueKey<String>('archive-layer-${items[index].id}'),
                    item: items[index],
                    signedDistance: index - value,
                    cardStep: cardStep,
                    interactive: index == focused,
                    onTap: () => onTap(index),
                    onLongPress: () => onLongPress(index),
                    child: faces[index],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PositionedArchiveCard extends StatelessWidget {
  const _PositionedArchiveCard({
    super.key,
    required this.item,
    required this.signedDistance,
    required this.cardStep,
    required this.interactive,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  final WalletPassItem item;
  final double signedDistance;
  final double cardStep;
  final bool interactive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double distance = signedDistance.abs();
    final double near = _smoothstep(distance.clamp(0, 1));
    final double far = (distance - 1).clamp(0, 1.35) / 1.35;
    final double scale = 1 - 0.10 * near - 0.07 * far;
    final double opacity = (1 - 0.44 * near - 0.38 * far).clamp(0.14, 1);
    final double dim = (0.30 * near + 0.16 * far).clamp(0, 0.46);

    return Transform.translate(
      offset: Offset(signedDistance * cardStep, 0),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Semantics(
            button: interactive,
            hidden: !interactive,
            label: interactive
                ? '${HistoryPassPresentation.title(item)}, '
                      '${HistoryPassPresentation.activityDateLabel(item) ?? 'date unavailable'}'
                : null,
            // Every card the viewport shows takes a tap: a neighbour sitting
            // half in view that quietly ignores one reads as a dead app.
            // Removal stays on the focused card alone, because a long press on
            // a half-covered neighbour is far more likely a mis-grab than an
            // intent to delete.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: interactive ? onLongPress : null,
              child: Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: dim),
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

  static double _smoothstep(double value) => value * value * (3 - 2 * value);
}

class _ArchiveCardFace extends StatelessWidget {
  const _ArchiveCardFace({required this.item});

  final WalletPassItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      TrainPassItem(:final ticket) => WalletCardCanvas(
        designSize: WalletCardMetrics.trainCanvas,
        child: TrainTicketFace(
          ticket: ticket,
          density: TrainTicketDensity.glance,
        ),
      ),
      MoviePassItem(:final pass) => _MovieArchiveCard(pass: pass),
      BusPassItem(:final pass) => WalletCardCanvas(
        designSize: WalletCardMetrics.ticketCanvas,
        child: BusTicketFace(pass: pass),
      ),
    };
  }
}

/// Archive movies use the poster-first composition from the supplied reference:
/// generous brand-colour framing, one uninterrupted poster, then the title.
class _MovieArchiveCard extends StatelessWidget {
  const _MovieArchiveCard({required this.pass});

  final MoviePass pass;

  static const double aspectRatio = 0.70;

  @override
  Widget build(BuildContext context) {
    final MovieBrandStyle style = MovieBrandStyle.forPass(
      pass,
      useBrandColors: true,
    );
    const double radius = 28;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.bodyGradient,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.glow.withValues(alpha: 0.26),
            blurRadius: 24,
            offset: const Offset(0, 13),
            spreadRadius: -7,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 9),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: MoviePosterArt(
                    pass: pass,
                    fallback: _MoviePosterFallback(style: style),
                  ),
                ),
              ),
              SizedBox(
                height: 76,
                child: Center(
                  child: Text(
                    pass.movieTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.45,
                      height: 1.08,
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoviePosterFallback extends StatelessWidget {
  const _MoviePosterFallback({required this.style});

  final MovieBrandStyle style;

  @override
  Widget build(BuildContext context) {
    final String? logo = style.logoAsset;
    return ColoredBox(
      color: const Color(0xFFF7F7F4),
      child: Center(
        child: logo == null
            ? Text(
                'MOVIE',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFF303034),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(42),
                child: SvgPicture.asset(
                  logo,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(
                    style.bodyGradient.first,
                    BlendMode.srcIn,
                  ),
                ),
              ),
      ),
    );
  }
}

class ArchiveDialPainter extends CustomPainter {
  ArchiveDialPainter({
    required this.itemCount,
    required this.passSpacing,
    required Animation<double> progress,
    required Animation<double> engagement,
    required this.brightness,
  }) : _progress = progress,
       _engagement = engagement,
       super(repaint: Listenable.merge(<Listenable>[progress, engagement]));

  final int itemCount;

  /// Pixels per pass, handed down from the deck so the scale is drawn at
  /// exactly the gearing the finger drives. The ruler stays under the
  /// fingertip instead of sliding at a rate of its own.
  final double passSpacing;

  final Animation<double> _progress;
  final Animation<double> _engagement;
  final Brightness brightness;

  double get position => _progress.value;

  static const int _edgeExtensions = 9;
  static const double minPassSpacing = 7;

  /// Ticks are laid at roughly [_idealTickSpacing] apart whatever the gearing,
  /// so the ruler stays evenly dense: a shallow folder gets more marks between
  /// passes rather than a wider gap, and a deep one falls back to a plain
  /// per-pass ruler rather than smearing into a band.
  static const double _idealTickSpacing = 18;

  static int subdivisionsFor(double passSpacing) =>
      (passSpacing / _idealTickSpacing).round().clamp(1, 12);

  int get _subdivisionsPerPass => subdivisionsFor(passSpacing);

  double get tickSpacing => passSpacing / _subdivisionsPerPass;

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount == 0) return;
    final double centerX = size.width / 2;
    final double halfWidth = math.max(centerX, 1);
    final double dialPosition = position * _subdivisionsPerPass;
    final int radius = (halfWidth / tickSpacing).ceil() + 2;
    final int firstPassTick = 0;
    final int lastPassTick = (itemCount - 1) * _subdivisionsPerPass;
    final int start = math.max(-_edgeExtensions, dialPosition.floor() - radius);
    final int end = math.min(
      lastPassTick + _edgeExtensions,
      dialPosition.ceil() + radius,
    );
    final Color neutral = brightness == Brightness.dark
        ? const Color(0xFFE6E6EB)
        : const Color(0xFF26262A);

    for (int tick = start; tick <= end; tick++) {
      final double delta = tick - dialPosition;
      final double x = centerX + delta * tickSpacing;
      if (x < -4 || x > size.width + 4) continue;

      final bool passTick =
          tick >= firstPassTick &&
          tick <= lastPassTick &&
          tick % _subdivisionsPerPass == 0;
      final double edgeProgress = ((x - centerX).abs() / halfWidth).clamp(0, 1);
      final double edgeFade = math.pow(1 - edgeProgress, 1.7).toDouble();
      final double centerFalloff = math.pow(1 - edgeProgress, 1.35).toDouble();
      final double tickHeight = 6 + 11 * centerFalloff + (passTick ? 5 : 0);
      final double alpha = (0.04 + 0.30 * edgeFade + (passTick ? 0.12 : 0))
          .clamp(0, 0.56);
      final Paint paint = Paint()
        ..color = neutral.withValues(alpha: alpha)
        ..strokeWidth = passTick ? 1.65 : 1.05
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, size.height / 2 - tickHeight / 2),
        Offset(x, size.height / 2 + tickHeight / 2),
        paint,
      );
    }

    // The scale moves under this fixed needle, like a physical dial. At rest a
    // pass tick aligns with it; in motion it becomes a continuous scrub point.
    final Color accent = brightness == Brightness.dark
        ? const Color(0xFFC45C60)
        : const Color(0xFFA84D52);
    final double engaged = Curves.easeOutCubic.transform(_engagement.value);
    final double halfNeedle = 17 + 4 * engaged;
    if (engaged > 0) {
      final Paint halo = Paint()
        ..color = accent.withValues(alpha: 0.08 * engaged)
        ..strokeWidth = 7 * engaged
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(centerX, size.height / 2 - halfNeedle),
        Offset(centerX, size.height / 2 + halfNeedle),
        halo,
      );
    }
    final Paint needle = Paint()
      ..color = accent.withValues(alpha: 0.82 + 0.12 * engaged)
      ..strokeWidth = 2.5 + engaged
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, size.height / 2 - halfNeedle),
      Offset(centerX, size.height / 2 + halfNeedle),
      needle,
    );
  }

  @override
  bool shouldRepaint(covariant ArchiveDialPainter oldDelegate) =>
      oldDelegate.itemCount != itemCount ||
      oldDelegate.passSpacing != passSpacing ||
      oldDelegate.brightness != brightness;
}

class _DateReadout extends StatelessWidget {
  const _DateReadout({super.key, required this.items, required this.position});

  final List<WalletPassItem> items;
  final double position;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final int lower = position.floor().clamp(0, items.length - 1);
    final int upper = position.ceil().clamp(0, items.length - 1);
    final double mix = (position - position.floor()).clamp(0, 1);
    final _MonthYear lowerDate = _MonthYear.of(items[lower]);
    final _MonthYear upperDate = _MonthYear.of(items[upper]);
    final int semanticIndex = position.round().clamp(0, items.length - 1);
    final _MonthYear semanticDate = _MonthYear.of(items[semanticIndex]);

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '${semanticDate.spoken}, pass ${semanticIndex + 1} of ${items.length}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 62,
          width: 150,
          child: Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              if (lower == upper || lowerDate == upperDate)
                _MonthYearLabel(value: lowerDate)
              else ...<Widget>[
                Opacity(
                  opacity: 1 - mix,
                  child: Transform.translate(
                    offset: Offset(0, -3 * mix),
                    child: _MonthYearLabel(value: lowerDate),
                  ),
                ),
                Opacity(
                  opacity: mix,
                  child: Transform.translate(
                    offset: Offset(0, 3 * (1 - mix)),
                    child: _MonthYearLabel(value: upperDate),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthYearLabel extends StatelessWidget {
  const _MonthYearLabel({required this.value});

  final _MonthYear value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value.month,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.7,
            height: 1,
            color: scheme.onSurface.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value.year,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.35,
            height: 1,
            color: AppTokens.secondaryLabel(scheme),
          ),
        ),
      ],
    );
  }
}

@immutable
class _MonthYear {
  const _MonthYear(this.month, this.year, this.spoken);

  final String month;
  final String year;
  final String spoken;

  static const List<String> _months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  factory _MonthYear.of(WalletPassItem item) {
    final DateTime? date = PassActivityDate.of(item);
    if (date == null) {
      return const _MonthYear('DATE', 'UNKNOWN', 'Date unknown');
    }
    return _MonthYear(
      _months[date.month - 1],
      '${date.year}',
      PassActivityDate.monthLabel(date),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _MonthYear && month == other.month && year == other.year;

  @override
  int get hashCode => Object.hash(month, year);
}
