import 'package:flutter/material.dart';

import '../../domain/ticket_models.dart';
import 'train_pass_theme.dart';
import 'train_status_band.dart';

/// How dense the shared train e-ticket face should render.
///
/// Both densities now draw the *same* face on the same
/// [TrainPassMetrics.canvas]; the enum survives because the detail screen needs
/// its QR to be tappable and the glance card does not.
enum TrainTicketDensity {
  /// Passes stack — the card in the wallet carousel.
  glance,

  /// Fullscreen detail — identical layout, scaled up, live QR.
  detail,
}

/// Train pass face — warm blush card, serif station codes, dynamic status band.
///
/// Laid out by absolute baseline against a fixed 366 x 630 canvas so it matches
/// the Figma export exactly; [WalletCardCanvas] scales that canvas to whatever
/// box the device gives it. Positions come from [TrainPassMetrics] — do not
/// re-measure them from a screenshot, they were taken off the export's path
/// coordinates.
class TrainTicketFace extends StatelessWidget {
  const TrainTicketFace({
    super.key,
    required this.ticket,
    required this.density,
    this.useBrandColors = false,
    this.widthFactor,
    this.onOpenCodes,
    this.clock = DateTime.now,
  });

  final MockTicket ticket;
  final TrainTicketDensity density;

  /// Force the live palette on a pass the wallet considers expired.
  final bool useBrandColors;

  /// Retained for callers that inset the face inside its box. The canvas now
  /// matches the card exactly, so the default is no inset.
  final double? widthFactor;

  final VoidCallback? onOpenCodes;

  /// Injected for tests so the status band's countdown is deterministic.
  final DateTime Function() clock;

  bool get _detail => density == TrainTicketDensity.detail;

  /// The dashed rule between the station codes. Its position is derived from
  /// the measured code widths, so a test needs to find it to assert clearance.
  @visibleForTesting
  static const Key connectorKey = Key('train_pass.connector');

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final bool isExpired =
        !useBrandColors && t.status == TicketStatus.expired;
    final TrainPassColors c = TrainPassColors.of(isExpired: isExpired);

    final Widget card = Container(
      width: TrainPassMetrics.width,
      height: TrainPassMetrics.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TrainPassMetrics.cornerR),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: c.shadowAlpha),
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TrainPassMetrics.cornerR),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: c.surface)),

            // ── Status band (painted first so nothing above it is occluded) ──
            Positioned(
              left: 0,
              right: 0,
              top: TrainPassMetrics.bandTop,
              height: TrainPassMetrics.bandHeight,
              child: TrainStatusBand(
                pass: t,
                colors: c,
                clock: clock,
              ),
            ),

            // ── Station header ──
            //
            // Order matters. The dashed rule is painted across the whole
            // content width first, then each code is painted over it on an
            // opaque swatch of the card surface. The swatch is the code's own
            // width plus a fixed margin, so the visible run of dashes is
            // exactly the gap the codes leave — no measuring, and it re-lays
            // out by itself when google_fonts swaps the fallback face for
            // Instrument Serif. (Measuring with a TextPainter in build looked
            // fine and was wrong: it ran once, before the serif resolved, and
            // the rule kept the fallback face's proportions forever.) Codes
            // wide enough to meet in the middle mask the rule off entirely
            // rather than having it drawn through them.
            Positioned(
              left: TrainPassMetrics.inset,
              right: TrainPassMetrics.inset,
              top: TrainPassMetrics.connectorY - 1,
              height: 2,
              child: CustomPaint(
                key: TrainTicketFace.connectorKey,
                painter: _DashedRulePainter(
                  color: c.rule,
                  strokeWidth: 2,
                  dash: 4,
                  gap: 4,
                ),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.codeBaseline,
              left: TrainPassMetrics.inset,
              child: _CodeMask(
                surface: c.surface,
                padding: const EdgeInsets.only(
                  right: TrainPassMetrics.codeConnectorGap,
                ),
                child: Text(
                  _code(t.fromCode),
                  maxLines: 1,
                  softWrap: false,
                  style: TrainPassType.stationCode(c.ink),
                ),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.codeBaseline,
              right: TrainPassMetrics.inset,
              child: _CodeMask(
                surface: c.surface,
                padding: const EdgeInsets.only(
                  left: TrainPassMetrics.codeConnectorGap,
                ),
                child: Text(
                  _code(t.toCode),
                  maxLines: 1,
                  softWrap: false,
                  style: TrainPassType.stationCode(c.ink),
                ),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.stationNameBaseline,
              left: TrainPassMetrics.inset,
              width: 150,
              child: Text(
                t.fromName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TrainPassType.stationName(c.muted),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.stationNameBaseline,
              right: TrainPassMetrics.inset,
              width: 150,
              child: Text(
                t.toName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TrainPassType.stationName(c.muted),
              ),
            ),

            Positioned(
              left: TrainPassMetrics.inset,
              right: TrainPassMetrics.inset,
              top: TrainPassMetrics.headerRuleY - 0.5,
              height: 1,
              child: ColoredBox(color: c.rule),
            ),

            // ── Train identity ──
            _Baselined(
              baseline: TrainPassMetrics.trainNameBaseline,
              left: TrainPassMetrics.inset,
              right: TrainPassMetrics.width - TrainPassMetrics.chipLeft + 10,
              child: Text(
                t.trainName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TrainPassType.trainName(c.ink),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.trainNumberBaseline,
              left: TrainPassMetrics.inset,
              width: 200,
              child: Text(
                'Train #${t.trainNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TrainPassType.trainNumber(c.muted),
              ),
            ),
            Positioned(
              left: TrainPassMetrics.chipLeft,
              top: TrainPassMetrics.chipTop,
              width: TrainPassMetrics.chipWidth,
              height: TrainPassMetrics.chipHeight,
              child: _BookingChip(
                label: _bookingCode(t.bookingStatus),
                colors: c,
              ),
            ),

            // ── Data grid ──
            ..._grid(t, c),

            Positioned(
              left: TrainPassMetrics.inset,
              right: TrainPassMetrics.inset,
              top: TrainPassMetrics.tearRuleY - 0.75,
              height: 1.5,
              child: CustomPaint(
                painter: _DashedRulePainter(
                  color: c.rule,
                  strokeWidth: 1.5,
                  dash: 6,
                  gap: 4,
                ),
              ),
            ),

            // ── Passenger + PNR ──
            _Baselined(
              baseline: TrainPassMetrics.passengerLabelBaseline,
              left: TrainPassMetrics.inset,
              width: 200,
              child: Text(
                'Passenger',
                maxLines: 1,
                style: TrainPassType.label(c.muted),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.passengerValueBaseline,
              left: TrainPassMetrics.inset,
              right: TrainPassMetrics.width - TrainPassMetrics.passengerRight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      t.passengerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TrainPassType.value(c.ink),
                    ),
                  ),
                  if (t.passengerCount > 1) ...<Widget>[
                    const SizedBox(width: 7.6),
                    Text(
                      '+${t.passengerCount - 1} others',
                      maxLines: 1,
                      style: TrainPassType.secondary(c.muted),
                    ),
                  ],
                ],
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.pnrLabelBaseline,
              left: TrainPassMetrics.inset,
              width: 200,
              child: Text(
                'PNR No',
                maxLines: 1,
                style: TrainPassType.label(c.muted),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.pnrValueBaseline,
              left: TrainPassMetrics.inset,
              right: TrainPassMetrics.width - TrainPassMetrics.passengerRight,
              child: Text(
                _formatPnr(t.pnr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TrainPassType.value(c.ink),
              ),
            ),

            // ── QR ──
            Positioned(
              left: TrainPassMetrics.qrLeft,
              top: TrainPassMetrics.qrTop,
              width: TrainPassMetrics.qrSize,
              height: TrainPassMetrics.qrSize,
              child: _QrBlock(
                colors: c,
                onTap: _detail ? onOpenCodes : null,
              ),
            ),

            // Border last so the clip never eats it.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(TrainPassMetrics.cornerR),
                    border: Border.all(color: c.border),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final double factor = widthFactor ?? 1.0;
    if (factor >= 0.999) return card;
    return Align(
      child: FractionallySizedBox(widthFactor: factor, child: card),
    );
  }

  List<Widget> _grid(MockTicket t, TrainPassColors c) {
    final List<(String, String, String, String)> rows =
        <(String, String, String, String)>[
      ('Date', _shortDate(t.date), 'Duration', t.duration),
      (
        'Departure (${_code(t.fromCode)})',
        t.departTime,
        'Arrival (${_code(t.toCode)})',
        t.arriveTime,
      ),
      ('Coach /Seat', _coachSeat(t), 'Class Type', t.ticketClass),
    ];

    const double colOneWidth = TrainPassMetrics.gridColumnTwoX -
        TrainPassMetrics.inset -
        10; // 158
    const double colTwoWidth =
        TrainPassMetrics.contentRight - TrainPassMetrics.gridColumnTwoX; // 150

    final List<Widget> out = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      final (String l1, String v1, String l2, String v2) = rows[i];
      out.addAll(<Widget>[
        _Baselined(
          baseline: TrainPassMetrics.gridLabelBaseline(i),
          left: TrainPassMetrics.inset,
          width: colOneWidth,
          child: Text(
            l1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TrainPassType.label(c.muted),
          ),
        ),
        _Baselined(
          baseline: TrainPassMetrics.gridValueBaseline(i),
          left: TrainPassMetrics.inset,
          width: colOneWidth,
          child: Text(
            _orDash(v1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TrainPassType.value(c.ink),
          ),
        ),
        _Baselined(
          baseline: TrainPassMetrics.gridLabelBaseline(i),
          left: TrainPassMetrics.gridColumnTwoX,
          width: colTwoWidth,
          child: Text(
            l2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TrainPassType.label(c.muted),
          ),
        ),
        _Baselined(
          baseline: TrainPassMetrics.gridValueBaseline(i),
          left: TrainPassMetrics.gridColumnTwoX,
          width: colTwoWidth,
          child: Text(
            _orDash(v2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TrainPassType.value(c.ink),
          ),
        ),
      ]);
    }
    return out;
  }
}

// ── Formatting ────────────────────────────────────────────────────────────────

const String _absent = '—';

String _orDash(String value) => value.trim().isEmpty ? _absent : value.trim();

String _code(String raw) {
  final String v = raw.trim().toUpperCase();
  return v.isEmpty ? _absent : v;
}

/// "Fri, 15 Aug 2026" -> "15 Aug 2026". The weekday is redundant on a card that
/// already carries the countdown in its band.
String _shortDate(String full) {
  final int i = full.indexOf(', ');
  return i >= 0 ? full.substring(i + 2) : full;
}

/// "C5 / 32A (Window)" for a lone traveller; a group gets a count instead,
/// because one seat number standing for six people is worse than no number.
String _coachSeat(MockTicket t) {
  if (t.passengerCount == 1) {
    final TicketPassenger p = t.primaryPassenger;
    final String head = <String>[p.coach, p.seat]
        .where((String s) => s.trim().isNotEmpty && s.trim() != _absent)
        .join(' / ');
    if (head.isEmpty) return _absent;
    final String berth = p.berth.trim();
    if (berth.isEmpty || berth == _absent) return head;
    return '$head ($berth)';
  }
  final String coaches = t.coachesListLabel.trim();
  final String seats = '${t.passengerCount} seats';
  return coaches.isEmpty ? seats : '$coaches / $seats';
}

/// Indian Railways PNRs are 10 digits and are printed 3-7.
String _formatPnr(String raw) {
  final String v = raw.trim();
  if (v.length == 10 && !v.contains('-')) {
    return '${v.substring(0, 3)}-${v.substring(3)}';
  }
  return v.isEmpty ? _absent : v;
}

/// Reservation status shortened to the code printed on a real ticket.
String _bookingCode(String status) {
  final String s = status.trim().toUpperCase();
  if (s.isEmpty) return _absent;
  if (s.startsWith('CONFIRM') || s == 'CNF') return 'CNF';
  if (s.startsWith('RAC')) return 'RAC';
  if (s.startsWith('WAIT') || s.startsWith('WL')) return 'WL';
  if (s.startsWith('CANCEL') || s.startsWith('CAN')) return 'CAN';
  if (s.length <= 4) return s;
  return s.substring(0, 3);
}

// ── Layout helpers ────────────────────────────────────────────────────────────

/// Positions [child] so its text baseline lands exactly on [baseline].
///
/// Placing by `top` instead would need each font's ascent, which differs
/// between Geist and the fallback face google_fonts uses before the real font
/// arrives — the card would shift on first launch and settle later.
class _Baselined extends StatelessWidget {
  const _Baselined({
    required this.baseline,
    required this.child,
    this.left,
    this.right,
    this.width,
  });

  final double baseline;
  final Widget child;
  final double? left;
  final double? right;

  /// Width of the text column. Passed to the child as a *tight* constraint —
  /// see below for why that matters.
  final double? width;

  @override
  Widget build(BuildContext context) {
    // RenderBaseline lays its child out under constraints.loosen() and then
    // pins it at Offset(0, top). A Text child therefore shrink-wraps and sits
    // flush left no matter what, so `textAlign: TextAlign.right` silently did
    // nothing and a right-anchored column rendered from its *left* edge —
    // which is how the destination station name ended up floating mid-card
    // instead of aligning under its code. The SizedBox restores a tight width
    // so the child fills the column and can align inside it.
    final Widget sized =
        width == null ? child : SizedBox(width: width, child: child);

    return Positioned(
      left: left,
      right: right,
      width: width,
      top: 0,
      child: Baseline(
        baseline: baseline,
        baselineType: TextBaseline.alphabetic,
        child: sized,
      ),
    );
  }
}

/// A station code on an opaque swatch of the card surface, which is what cuts
/// the gap either side of the dashed connector running underneath it.
///
/// [padding] is the clear space held between the lettering and the first dash.
class _CodeMask extends StatelessWidget {
  const _CodeMask({
    required this.surface,
    required this.padding,
    required this.child,
  });

  final Color surface;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: surface,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter({
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final double y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _BookingChip extends StatelessWidget {
  const _BookingChip({required this.label, required this.colors});

  final String label;
  final TrainPassColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.chipFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          style: TrainPassType.chip(colors.chipInk),
        ),
      ),
    );
  }
}

/// Decorative code block, not a scannable one.
///
/// The pattern is the fixed 7x7 grid from the design export; it encodes
/// nothing. The real boarding code lives behind [onTap] on the detail screen,
/// which is why the glance card leaves this inert rather than inviting a scan
/// that would fail at a gate.
class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.colors, this.onTap});

  final TrainPassColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget block = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(TrainPassMetrics.qrRadius),
            border: Border.all(color: colors.qrBorder),
          ),
        ),
        CustomPaint(painter: _QrPainter(color: colors.ink)),
      ],
    );

    if (onTap == null) return block;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: block,
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.color});

  final Color color;

  /// Verbatim from the export's 7x7 rect grid.
  static const List<List<int>> _pattern = <List<int>>[
    <int>[1, 1, 1, 0, 1, 1, 1],
    <int>[1, 0, 1, 1, 0, 0, 1],
    <int>[1, 1, 1, 0, 1, 1, 1],
    <int>[0, 0, 0, 1, 0, 1, 0],
    <int>[1, 1, 0, 0, 1, 0, 1],
    <int>[1, 0, 1, 1, 0, 1, 1],
    <int>[1, 1, 1, 0, 1, 0, 1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    for (int r = 0; r < TrainPassMetrics.qrModules; r++) {
      for (int col = 0; col < TrainPassMetrics.qrModules; col++) {
        if (_pattern[r][col] == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            TrainPassMetrics.qrInset + col * TrainPassMetrics.qrPitch,
            TrainPassMetrics.qrInset + r * TrainPassMetrics.qrPitch,
            TrainPassMetrics.qrCell,
            TrainPassMetrics.qrCell,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.color != color;
}
