import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../domain/movie_pass_models.dart';
import 'movie/movie_ticket_face.dart';
import 'movie_pass_detail_screen.dart';

/// Movie pass glance card — press shell around [MovieTicketFace].
class WalletMovieCard extends StatefulWidget {
  const WalletMovieCard({super.key, required this.pass});

  final MoviePass pass;

  @override
  State<WalletMovieCard> createState() => _WalletMovieCardState();
}

class _WalletMovieCardState extends State<WalletMovieCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _openDetail() {
    HapticService.confirm();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MoviePassDetailScreen(pass: widget.pass),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The face sizes itself from its content, so it used to grow past
        // short viewports. Pin it to a canvas and scale that to fit instead.
        final Size card = WalletCardMetrics.resolve(
          constraints,
          WalletCardMetrics.ticketAspect,
        );

        return GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) => _pressCtrl.reverse(),
          onTapCancel: () => _pressCtrl.reverse(),
          onTap: _openDetail,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: SizedBox(
              width: card.width,
              height: card.height,
              child: WalletCardCanvas(
                designSize: WalletCardMetrics.ticketCanvas,
                child: MovieTicketFace(
                  pass: widget.pass,
                  density: MovieTicketDensity.glance,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
