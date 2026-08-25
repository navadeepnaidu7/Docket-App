import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/bus_pass_models.dart';
import '../../domain/movie_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_share_summary.dart';
import '../../domain/ticket_models.dart';
import '../bus/bus_pass_theme.dart';
import '../bus/bus_ticket_face.dart';
import '../movie/movie_ticket_face.dart';
import '../train/train_pass_theme.dart';
import '../train/train_ticket_face.dart';

/// The thing that gets rasterised when a pass is shared or saved.
///
/// Never mounted in a route — [PassShareService] parks one off-screen for two
/// frames and captures it. That is why every dimension here is absolute rather
/// than derived from the viewport: the output has to be identical on a small
/// phone and a tablet, and a share target should not be able to tell which
/// device produced the file.
///
/// The composition is the wallet *glance* face plus a code block, not the
/// detail screen. The detail screen's `PassInfoCard` rows are readable text and
/// belong in the share message, where they can be selected, searched and quoted
/// — burning them into pixels would make them none of those things.
class PassShareCard extends StatelessWidget {
  const PassShareCard({super.key, required this.item});

  final WalletPassItem item;

  /// Gutter around the card, and the gap between stacked blocks.
  static const double _pad = 24;
  static const double _gap = 20;

  /// Side of the QR module grid.
  ///
  /// Sized to sit under the card rather than compete with it. At the export's
  /// capture scale this is still ~290px of modules, which scans fine off
  /// another phone's screen — the constraint is aesthetic, not optical.
  static const double _qrSize = 116;

  /// Plate the pass sits on. Fixed rather than theme-derived: an exported image
  /// has no theme, and a pass shared at night should not arrive looking like a
  /// different product than one shared at noon.
  static const Color _plate = Color(0xFF101014);
  static const Color _plateInk = Color(0xFFF3F3F5);

  /// Total logical width of the exported image, gutters included.
  static double get exportWidth => _faceWidth + _pad * 2;

  /// Every face is drawn at this width whatever its own canvas is, so a train
  /// and a movie shared into the same chat arrive the same size. The widest
  /// canvas wins; the narrower one scales up to meet it.
  static double get _faceWidth => WalletCardMetrics.ticketCanvasWidth >
          WalletCardMetrics.trainCanvasWidth
      ? WalletCardMetrics.ticketCanvasWidth
      : WalletCardMetrics.trainCanvasWidth;

  @visibleForTesting
  static const Key qrKey = Key('pass_share.qr');

  @visibleForTesting
  static const Key faceKey = Key('pass_share.face');

  @override
  Widget build(BuildContext context) {
    final String? payload = passShareCodePayload(item);

    return MediaQuery.withNoTextScaling(
      child: Directionality(
        textDirection: TextDirection.ltr,
        // An explicit base style, and not merely a tidy one.
        //
        // This subtree is an Overlay entry, so it has no Material above it, and
        // the fallback DefaultTextStyle that WidgetsApp installs for that case
        // is the debug style: red text under a yellow double underline. Every
        // PassType role sets colour, size and weight but not `decoration`, so
        // the underline was inheriting straight through into the exported PNG.
        //
        // Stated in full rather than borrowed from the theme, because the
        // export must not change with the viewer's light/dark setting.
        child: DefaultTextStyle(
          style: const TextStyle(
            color: _plateInk,
            decoration: TextDecoration.none,
            decorationColor: Color(0x00000000),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          child: Container(
            width: exportWidth,
            color: _plate,
            padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                KeyedSubtree(key: faceKey, child: _face()),
                // Omitted entirely when the pass carries no payload. A pass
                // with no scannable code exports without one rather than with
                // a decorative square that would fail at a gate.
                if (payload != null) ...<Widget>[
                  const SizedBox(height: _gap),
                  _codeBlock(payload),
                ],
                const SizedBox(height: _gap),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The glance face, pinned to its design canvas and scaled to [_faceWidth].
  ///
  /// Every kind goes through [WalletCardCanvas] on its own design size — the
  /// same wrapper the wallet cards use. That matters for more than tidiness:
  /// the movie face sizes from its content, and handing it an unbounded height
  /// lets a long title push it past its canvas. On screen that is a scroll; in
  /// an export it would be an overflow banner burned into the PNG.
  ///
  /// [useBrandColors] is forced on so an expired pass still exports as itself
  /// rather than in the drained palette — a shared image is a record of the
  /// booking, and the wallet's "this one is spent" tint is wallet chrome.
  /// `onOpenCodes` stays null throughout: nothing in a PNG is tappable.
  Widget _face() {
    final (Size canvas, Widget face) = switch (item) {
      TrainPassItem(:final TrainPass ticket) => (
          TrainPassMetrics.canvas,
          TrainTicketFace(
            ticket: ticket,
            density: TrainTicketDensity.glance,
            useBrandColors: true,
          ),
        ),
      BusPassItem(:final BusPass pass) => (
          BusPassMetrics.canvas,
          BusTicketFace(pass: pass, useBrandColors: true),
        ),
      // Glance density is also what selects the transparent title logo over the
      // full one-sheet poster (`_HeroBand`, docs/features/movie-logo-glance.md).
      // The logo is legible at this size and keeps the exported PNG a fraction
      // of what a 2:3 poster would cost.
      MoviePassItem(:final MoviePass pass) => (
          WalletCardMetrics.ticketCanvas,
          MovieTicketFace(
            pass: pass,
            density: MovieTicketDensity.glance,
            useBrandColors: true,
          ),
        ),
    };

    return SizedBox(
      width: _faceWidth,
      height: _faceWidth * canvas.height / canvas.width,
      child: WalletCardCanvas(designSize: canvas, child: face),
    );
  }

  /// A white tile just big enough for the code, with the reference under it.
  ///
  /// The white plate hugs the QR rather than spanning the card. A small code
  /// centred in a full-width slab reads as a mistake, and the quiet zone a
  /// scanner needs is only a few modules — the rest was empty paper.
  Widget _codeBlock(String payload) {
    final String? caption = passShareCodeCaption(item);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: QrImageView(
            key: qrKey,
            data: payload,
            version: QrVersions.auto,
            size: _qrSize,
            gapless: true,
            backgroundColor: Colors.white,
            // Explicit black on white. A QR tinted to match the brand loses
            // contrast on a phone screen photographed by another phone, which
            // is exactly how a forwarded ticket gets scanned.
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF000000),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF000000),
            ),
          ),
        ),
        if (caption != null) ...<Widget>[
          const SizedBox(height: 12),
          // On the plate, not on the tile: it is for a person to read out when
          // the scanner fails, and it does not belong inside the code's quiet
          // zone.
          //
          // Smaller than `PassType.code`, and scaled down rather than wrapped.
          // That role's 17/2.2 is sized for a detail screen and put a long
          // booking reference onto two ragged lines here; a reference read
          // aloud has to stay one run.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              caption,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.inter(
                color: _plateInk.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The wordmark that closes the image.
  ///
  /// The same treatment as the watermark at the foot of Settings — one big
  /// translucent "Docket", set tight — rather than a caption. It reads as a
  /// mark on the artwork instead of a line of text competing with the pass's
  /// own type, and it is the last thing in the frame rather than a banner
  /// across the top of someone else's ticket.
  ///
  /// No version string here: Settings shows one because that screen is about
  /// the app, and a build number on a forwarded ticket is noise.
  Widget _footer() {
    return Center(
      child: Text(
        'Docket',
        maxLines: 1,
        style: GoogleFonts.inter(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: -2.0,
          height: 1.0,
          color: _plateInk.withValues(alpha: 0.13),
        ),
      ),
    );
  }
}
