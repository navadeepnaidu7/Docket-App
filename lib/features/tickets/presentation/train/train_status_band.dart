import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/pass_activity_date.dart';
import '../../domain/ticket_models.dart';
import 'train_pass_theme.dart';

/// How loud a band message is.
enum TrainBandTone { neutral, positive, warning, critical }

/// One line the status band can show.
@immutable
class TrainBandMessage {
  const TrainBandMessage({
    required this.id,
    required this.text,
    required this.tone,
  });

  /// Stable across ticks so a countdown re-rendering with the same wording does
  /// not restart the cross-fade. Countdown ids deliberately exclude the number.
  final String id;
  final String text;
  final TrainBandTone tone;

  @override
  bool operator ==(Object other) =>
      other is TrainBandMessage &&
      other.id == id &&
      other.text == text &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(id, text, tone);

  @override
  String toString() => 'TrainBandMessage($id, "$text", ${tone.name})';
}

/// Everything the band can say about [pass] at [now], most important first.
///
/// Pure on purpose: the band reads the clock through an injected callback and
/// hands it here, so ordering and wording are unit-testable without pumping a
/// widget. An empty result is normal and means "nothing live to report" — the
/// band falls back to the ghosted wordmark alone.
List<TrainBandMessage> resolveTrainBandMessages(
  TrainPass pass,
  DateTime now,
) {
  // A cancelled train makes every other message misleading: there is no
  // platform to stand on and no countdown worth running.
  if (pass.runState == TrainRunState.cancelled) {
    return const <TrainBandMessage>[
      TrainBandMessage(
        id: 'cancelled',
        text: 'Cancelled',
        tone: TrainBandTone.critical,
      ),
    ];
  }

  final bool finished =
      pass.runState == TrainRunState.arrived ||
          pass.status == TicketStatus.expired;

  if (finished) {
    return const <TrainBandMessage>[
      TrainBandMessage(
        id: 'arrived',
        text: 'Journey complete',
        tone: TrainBandTone.neutral,
      ),
    ];
  }

  final List<TrainBandMessage> out = <TrainBandMessage>[];

  if (pass.isDelayed) {
    out.add(
      TrainBandMessage(
        id: 'delay',
        text: '${_formatDuration(pass.delayMinutes!)} delayed',
        tone: TrainBandTone.warning,
      ),
    );
  }

  final String? platform = _platformSentence(pass.platformLabel);
  if (platform != null) {
    out.add(
      TrainBandMessage(
        id: 'platform',
        text: platform,
        tone: TrainBandTone.neutral,
      ),
    );
  }

  final DateTime? departure = trainDepartureAt(pass);
  if (departure != null) {
    final String? countdown = _countdown(departure, now);
    if (countdown != null) {
      out.add(
        TrainBandMessage(
          id: 'countdown',
          text: countdown,
          tone: TrainBandTone.neutral,
        ),
      );
    }
  }

  // Only claim "On time" when the backend actually said so. Inferring it from
  // the absence of a delay would put a confident green line on every pass the
  // server has never reported on.
  if (pass.runState == TrainRunState.onTime && !pass.isDelayed) {
    out.add(
      const TrainBandMessage(
        id: 'onTime',
        text: 'On time',
        tone: TrainBandTone.positive,
      ),
    );
  }

  return out;
}

/// Best-effort departure instant: the ISO field when present, otherwise the
/// display date with the display time folded in.
///
/// [PassActivityDate.parse] on `date` alone lands on midnight, which would make
/// every same-day countdown read hours early.
DateTime? trainDepartureAt(TrainPass pass) {
  final DateTime? iso = PassActivityDate.parse(pass.departAt);
  if (iso != null) return iso;

  final DateTime? day = PassActivityDate.parse(pass.date);
  if (day == null) return null;

  final _Clock? time = _Clock.parse(pass.departTime);
  if (time == null) return day;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

String? _countdown(DateTime departure, DateTime now) {
  final Duration left = departure.difference(now);

  if (left.inSeconds <= -_boardingGrace.inSeconds) return null; // already gone
  if (left.inSeconds <= 0) return 'Boarding now';
  if (left.inMinutes < 1) return 'Departing now';
  if (left.inMinutes < 60) return 'Departs in ${left.inMinutes} min';
  if (left.inHours < 24) {
    final int hours = left.inHours;
    return 'in $hours ${hours == 1 ? 'hour' : 'hours'}';
  }

  // Calendar days, not 24-hour blocks: a journey tomorrow morning should read
  // "1 day to go" whether it is now dawn or late evening.
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime dayOfTravel =
      DateTime(departure.year, departure.month, departure.day);
  final int days = dayOfTravel.difference(today).inDays;
  if (days <= 1) return 'Tomorrow';
  return '$days days to go';
}

/// Grace period after the scheduled time during which the band still says
/// "Boarding now" rather than dropping the countdown.
const Duration _boardingGrace = Duration(minutes: 10);

String _formatDuration(int minutes) {
  if (minutes < 60) return '$minutes ${minutes == 1 ? 'min' : 'mins'}';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  final String h = '$hours ${hours == 1 ? 'hr' : 'hrs'}';
  if (rest == 0) return h;
  return '$h $rest ${rest == 1 ? 'min' : 'mins'}';
}

/// Normalises the free-text platform on a halt ("PF 3", "3", "Platform 3").
String? _platformSentence(String? raw) {
  if (raw == null) return null;
  final String value = raw.trim();
  if (value.isEmpty) return null;

  final String lower = value.toLowerCase();
  if (lower.startsWith('platform')) return value;
  if (lower.startsWith('pf')) {
    final String rest = value.substring(2).replaceFirst(RegExp(r'^[\s.:-]+'), '');
    return rest.isEmpty ? value : 'Platform $rest';
  }
  return 'Platform $value';
}

/// Minimal 12/24-hour parser for the display departure time.
@immutable
class _Clock {
  const _Clock(this.hour, this.minute);

  final int hour;
  final int minute;

  static final RegExp _pattern =
      RegExp(r'^(\d{1,2})[:.](\d{2})\s*([AaPp][Mm])?');

  static _Clock? parse(String raw) {
    final Match? m = _pattern.firstMatch(raw.trim());
    if (m == null) return null;

    int hour = int.parse(m.group(1)!);
    final int minute = int.parse(m.group(2)!);
    if (minute > 59) return null;

    final String? meridiem = m.group(3)?.toLowerCase();
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'am') {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }
    } else if (hour > 23) {
      return null;
    }

    return _Clock(hour, minute);
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// The card's bottom strip: a blurred wordmark that never changes, with live
/// journey messages cross-fading over it.
class TrainStatusBand extends StatefulWidget {
  const TrainStatusBand({
    super.key,
    required this.pass,
    required this.colors,
    this.clock = DateTime.now,
    this.dwell = const Duration(seconds: 4),
  });

  final TrainPass pass;
  final TrainPassColors colors;

  /// Injected so tests can pin the countdown instead of racing the wall clock.
  final DateTime Function() clock;

  /// How long each message holds before the next one fades in.
  final Duration dwell;

  static const Duration fade = Duration(milliseconds: 650);

  @override
  State<TrainStatusBand> createState() => _TrainStatusBandState();
}

class _TrainStatusBandState extends State<TrainStatusBand> {
  Timer? _cycle;
  List<TrainBandMessage> _messages = const <TrainBandMessage>[];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _messages = resolveTrainBandMessages(widget.pass, widget.clock());
    _restartCycle();
  }

  @override
  void didUpdateWidget(covariant TrainStatusBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pass != widget.pass || oldWidget.dwell != widget.dwell) {
      _refresh(resetIndex: true);
      _restartCycle();
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  /// A lone static message needs no timer; leaving one running would keep a
  /// wallet full of finished passes waking the raster thread for nothing.
  ///
  /// A lone *countdown* does need one, though. It is the one message whose text
  /// changes without the pass changing, so without a tick a card left on screen
  /// would sit on "Departs in 25 min" indefinitely.
  bool get _needsCycle =>
      _messages.length > 1 ||
      _messages.any((TrainBandMessage m) => m.id == 'countdown');

  void _restartCycle() {
    _cycle?.cancel();
    _cycle = null;
    if (!_needsCycle) return;
    _cycle = Timer.periodic(widget.dwell, (_) => _advance());
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      // Recompute first: a countdown left on screen must not go stale, and a
      // message list that shrank must not leave _index dangling.
      _refresh(resetIndex: false);
      if (_messages.isEmpty) {
        _index = 0;
      } else {
        _index = (_index + 1) % _messages.length;
      }
    });
    // The set can shrink as the journey moves on — a countdown drops out once
    // the train leaves. Stop ticking when there is nothing left to refresh.
    if (!_needsCycle) _restartCycle();
  }

  void _refresh({required bool resetIndex}) {
    _messages = resolveTrainBandMessages(widget.pass, widget.clock());
    if (resetIndex || _index >= _messages.length) _index = 0;
  }

  Color _toneColor(TrainBandTone tone) {
    final TrainPassColors c = widget.colors;
    return c.tone(switch (tone) {
      TrainBandTone.neutral => c.ink,
      TrainBandTone.positive => TrainPassPalette.chipInk,
      TrainBandTone.warning => TrainPassPalette.toneWarning,
      TrainBandTone.critical => TrainPassPalette.toneCritical,
    });
  }

  @override
  Widget build(BuildContext context) {
    final TrainBandMessage? message =
        _messages.isEmpty ? null : _messages[_index];

    return SizedBox(
      height: TrainPassMetrics.bandHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  widget.colors.surface.withValues(alpha: 0.0),
                  widget.colors.bandTint,
                ],
              ),
            ),
          ),
          _BandGhost(
            label: _ghostLabel(widget.pass),
            colors: widget.colors,
          ),
          Center(
            child: AnimatedSwitcher(
              duration: TrainStatusBand.fade,
              // Fade *through*, not across. AnimatedSwitcher stacks the
              // outgoing and incoming children for the whole duration, so a
              // plain cross-fade leaves two centred lines legibly overlapping
              // at the midpoint. Offsetting the intervals means the old line is
              // gone before the new one is readable.
              switchInCurve: const Interval(0.55, 1.0, curve: Curves.easeOut),
              switchOutCurve: const Interval(0.55, 1.0, curve: Curves.easeIn),
              transitionBuilder: (Widget child, Animation<double> anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: message == null
                  ? const SizedBox.shrink(key: ValueKey<String>('idle'))
                  : _BandMessage(
                      key: ValueKey<String>(message.id),
                      message: message,
                      color: _toneColor(message.tone),
                      showDot: widget.colors != TrainPassColors.expired &&
                          message.tone != TrainBandTone.neutral,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Idle layer: the operator's name set huge, blurred, and bled off the bottom
/// edge. Present even while a message shows, which is what stops the band from
/// looking empty between states.
String _ghostLabel(TrainPass pass) {
  final String operator = pass.operator.trim();
  if (operator.isEmpty) return 'RAILWAYS';
  return operator.toUpperCase();
}

class _BandGhost extends StatelessWidget {
  const _BandGhost({required this.label, required this.colors});

  final String label;
  final TrainPassColors colors;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      // Sits low enough that the card's own clip cuts the baseline off, which
      // is what the 6%-opacity layer in the export does.
      bottom: -24,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
          child: FractionallySizedBox(
            // The export's ghost spans a little over half the card. Letting a
            // long operator name run the full width turns the backdrop into a
            // second headline competing with the message on top of it.
            widthFactor: 0.62,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TrainPassType.bandGhost(
                  colors.ink.withValues(alpha: colors.ghostAlpha),
                ).copyWith(letterSpacing: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandMessage extends StatelessWidget {
  const _BandMessage({
    super.key,
    required this.message,
    required this.color,
    required this.showDot,
  });

  final TrainBandMessage message;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TrainPassMetrics.inset),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showDot) ...<Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Text(
              message.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TrainPassType.bandMessage(color),
            ),
          ),
        ],
      ),
    );
  }
}
