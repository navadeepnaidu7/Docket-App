import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../domain/ticket_models.dart';
import 'ticket_detail_screen.dart';
import 'train/train_ticket_face.dart';

export '../domain/ticket_models.dart';

/// Train pass glance card — press shell around [TrainTicketFace].
class WalletTicketCard extends StatefulWidget {
  const WalletTicketCard({super.key, required this.ticket});

  final MockTicket ticket;

  @override
  State<WalletTicketCard> createState() => _WalletTicketCardState();
}

class _WalletTicketCardState extends State<WalletTicketCard>
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
        builder: (_) => TicketDetailScreen(ticket: widget.ticket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: _openDetail,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: TrainTicketFace(
          ticket: widget.ticket,
          density: TrainTicketDensity.glance,
        ),
      ),
    );
  }
}
