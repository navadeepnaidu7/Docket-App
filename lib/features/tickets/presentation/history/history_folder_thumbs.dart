import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/bus_pass_models.dart';
import '../../domain/movie_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import '../../domain/ticket_models.dart';
import 'history_visuals.dart';
import 'movie_poster_art.dart';

/// Fanned preview chips showing the newest passes a folder holds.
///
/// Sits between the folder's back panel and its front lip, so the lower part of
/// each chip is occluded and they read as contents tucked inside.
class HistoryFolderThumbs extends StatelessWidget {
  const HistoryFolderThumbs({super.key, required this.items});

  final List<WalletPassItem> items;

  /// Poster proportions, which trains borrow so the fan stays even.
  static const double _chipAspect = 2 / 3;
  static const double _tilt = 0.07;
  static const int _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final List<WalletPassItem> preview = items.take(_maxChips).toList();
    // Unreachable today (buildHistoryFolders never emits an empty folder), but
    // the folder should still render its label if that ever changes.
    if (preview.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double chipH = constraints.maxHeight;
        final double chipW = chipH * _chipAspect;
        final double spread = chipW * 0.52;
        // Tighten the fan when there is only one chip to lean against.
        final double tilt = preview.length >= 3 ? _tilt : _tilt * 0.5;

        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            // Back to front, so the newest pass lands on top and upright.
            for (int i = preview.length - 1; i >= 0; i--)
              _FannedChip(
                item: preview[i],
                width: chipW,
                height: chipH,
                // 0 centred and upright, 1 leans left, 2 leans right.
                offsetX: i == 0 ? 0 : (i == 1 ? -spread : spread),
                offsetY: i == 0 ? 0 : chipH * 0.05,
                angle: i == 0 ? 0 : (i == 1 ? -tilt : tilt),
                scale: i == 0 ? 1.0 : 0.94,
              ),
          ],
        );
      },
    );
  }
}

class _FannedChip extends StatelessWidget {
  const _FannedChip({
    required this.item,
    required this.width,
    required this.height,
    required this.offsetX,
    required this.offsetY,
    required this.angle,
    required this.scale,
  });

  final WalletPassItem item;
  final double width;
  final double height;
  final double offsetX;
  final double offsetY;
  final double angle;
  final double scale;

  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: switch (item) {
                MoviePassItem(:final pass) => _PosterChip(pass: pass),
                TrainPassItem(:final ticket) => _RouteChip(ticket: ticket),
                BusPassItem(:final pass) => _BusChip(pass: pass),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Movie chip: real poster when there is one, poster-hint gradient otherwise.
class _PosterChip extends StatelessWidget {
  const _PosterChip({required this.pass});

  final MoviePass pass;

  @override
  Widget build(BuildContext context) {
    return MoviePosterArt(
      pass: pass,
      // At chip size a title would be unreadable, so the brand mark stands in.
      fallback: Center(
        child: HistoryBrandMark(
          look: HistoryStripLook.forMovie(pass),
          size: 16,
        ),
      ),
    );
  }
}

/// Train chip: the journey itself, since rail passes carry no artwork.
class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.ticket});

  final TrainPass ticket;

  @override
  Widget build(BuildContext context) {
    final HistoryStripLook look = HistoryStripLook.forTrain(ticket);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: look.gradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _code(ticket.fromCode),
              Container(
                width: 10,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.white.withValues(alpha: 0.45),
              ),
              _code(ticket.toCode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _code(String value) => Text(
        value.trim().isEmpty ? '--' : value.trim(),
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.0,
          color: Colors.white,
        ),
      );
}

class _BusChip extends StatelessWidget {
  const _BusChip({required this.pass});

  final BusPass pass;

  @override
  Widget build(BuildContext context) {
    final HistoryStripLook look =
        HistoryStripLook.forCategory(PassHistoryCategory.bus);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: look.gradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _place(pass.boardingLocation),
              Container(
                width: 10,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.white.withValues(alpha: 0.45),
              ),
              _place(pass.dropLocation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _place(String value) => Text(
        value.trim().isEmpty ? '--' : value.trim(),
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1.0,
          color: Colors.white,
        ),
      );
}
