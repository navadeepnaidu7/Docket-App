import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../domain/bus_pass_models.dart';
import 'bus/bus_pass_detail_screen.dart';
import 'bus/bus_ticket_face.dart';

class WalletBusCard extends StatefulWidget {
  const WalletBusCard({
    super.key,
    required this.pass,
    this.onLongPress,
  });

  final BusPass pass;
  final VoidCallback? onLongPress;

  @override
  State<WalletBusCard> createState() => _WalletBusCardState();
}

class _WalletBusCardState extends State<WalletBusCard>
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
        builder: (_) => BusPassDetailScreen(pass: widget.pass),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size card = WalletCardMetrics.resolve(
          constraints,
          WalletCardMetrics.ticketAspect,
        );
        return GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) => _pressCtrl.reverse(),
          onTapCancel: () => _pressCtrl.reverse(),
          onTap: _openDetail,
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  _pressCtrl.reverse();
                  HapticService.longPress();
                  SoundService.longPress();
                  widget.onLongPress!();
                },
          child: ScaleTransition(
            scale: _scaleAnim,
            child: SizedBox(
              width: card.width,
              height: card.height,
              child: WalletCardCanvas(
                designSize: WalletCardMetrics.ticketCanvas,
                child: BusTicketFace(pass: widget.pass),
              ),
            ),
          ),
        );
      },
    );
  }
}
