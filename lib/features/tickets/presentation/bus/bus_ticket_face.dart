import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/bus_pass_models.dart';

/// Brand palette for bus passes — teal/pine, shared with history strips.
abstract final class BusPassPalette {
  BusPassPalette._();

  static const Color pine = Color(0xFF115E59);
  static const Color teal = Color(0xFF2DD4BF);
}

/// First-cut bus face — operator, route, times. Not a Figma lockup.
class BusTicketFace extends StatelessWidget {
  const BusTicketFace({super.key, required this.pass});

  final BusPass pass;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color ink = AppTheme.ink(brightness);
    final Color muted = isDark ? const Color(0xFF8E8E93) : const Color(0xFF5B6B68);
    final Color surface = AppTheme.surface(brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : BusPassPalette.teal.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              pass.operator.trim().isEmpty ? 'Bus' : pass.operator,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: BusPassPalette.pine,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: _Stop(
                    label: 'From',
                    value: pass.boardingLocation,
                    time: pass.departTime,
                    ink: ink,
                    muted: muted,
                    alignEnd: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: BusPassPalette.teal,
                  ),
                ),
                Expanded(
                  child: _Stop(
                    label: 'To',
                    value: pass.dropLocation,
                    time: pass.arriveTime,
                    ink: ink,
                    muted: muted,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Divider(color: muted.withValues(alpha: 0.25), height: 28),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Meta(
                    label: 'Date',
                    value: pass.date.trim().isEmpty ? '—' : pass.date,
                    ink: ink,
                    muted: muted,
                  ),
                ),
                Expanded(
                  child: _Meta(
                    label: 'Seat',
                    value: pass.seatDetails.trim().isEmpty
                        ? '—'
                        : pass.seatDetails,
                    ink: ink,
                    muted: muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.label,
    required this.value,
    required this.time,
    required this.ink,
    required this.muted,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final String time;
  final Color ink;
  final Color muted;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final CrossAxisAlignment align =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.trim().isEmpty ? '—' : value.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.15,
            color: ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time.trim().isEmpty ? '' : time.trim(),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    required this.ink,
    required this.muted,
  });

  final String label;
  final String value;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ],
    );
  }
}
