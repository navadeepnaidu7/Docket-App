import 'package:flutter/material.dart';

import '../../domain/bus_pass_models.dart';
import '../pass_code_screen.dart';

/// Bus-specific content for the shared scan view.
class BusTicketCodeScreen extends StatelessWidget {
  const BusTicketCodeScreen({super.key, required this.pass});

  final BusPass pass;

  @override
  Widget build(BuildContext context) => PassCodeScreen(
    code: pass.passCode,
    title: <String>[
      pass.resolvedFromCity,
      pass.resolvedToCity,
    ].where((part) => part.trim().isNotEmpty).join('  →  '),
    subtitle: <String>[
      pass.date,
      pass.departTime,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' · '),
    reference: pass.bookingId,
  );
}
