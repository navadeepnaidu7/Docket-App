import 'package:flutter/material.dart';

import '../../domain/ticket_models.dart';
import '../pass_code_screen.dart';

/// Train-specific content for the shared scan view.
class TrainTicketCodeScreen extends StatelessWidget {
  const TrainTicketCodeScreen({super.key, required this.ticket});

  final TrainPass ticket;

  @override
  Widget build(BuildContext context) => PassCodeScreen(
    code: ticket.passCode,
    title: <String>[
      ticket.fromName.trim().isEmpty ? ticket.fromCode : ticket.fromName,
      ticket.toName.trim().isEmpty ? ticket.toCode : ticket.toName,
    ].where((part) => part.trim().isNotEmpty).join('  →  '),
    subtitle: <String>[
      ticket.date,
      ticket.departTime,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' · '),
    reference: ticket.pnr,
    referenceLabel: 'PNR',
  );
}
