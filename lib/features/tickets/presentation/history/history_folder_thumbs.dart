import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/movie_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/ticket_models.dart';
import 'history_visuals.dart';

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
    // Fixtures may pin a bundled asset; everything else comes from the backend's
    // TMDB image proxy. Either may be absent — "no poster" is a normal state.
    final String? asset = pass.resolvedPosterAsset;
    final String? url = pass.resolvedPosterUrl;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Painted first and never removed, so it shows through while a poster
        // loads and remains the art when there is none.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: pass.posterHint.gradient,
            ),
          ),
        ),
        if (asset != null)
          Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        else if (url != null)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                // Chips are ~50dp wide; decoding a 780px poster at full size
                // across a two-column grid is a real memory cost.
                memCacheWidth: (constraints.maxWidth *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                // A spinner at this size reads as broken — the gradient below
                // is the placeholder.
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              );
            },
          )
        else
          Center(
            child: HistoryBrandMark(
              look: HistoryStripLook.forMovie(pass),
              size: 16,
            ),
          ),
      ],
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
