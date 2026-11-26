import 'package:flutter/material.dart';

import '../../domain/flight_format.dart';
import '../../domain/flight_pass_models.dart';
import '../pass_code_screen.dart';

/// Flight-specific content for the shared scan view.
class FlightTicketCodeScreen extends StatelessWidget {
  const FlightTicketCodeScreen({super.key, required this.pass});

  final FlightPass pass;

  @override
  Widget build(BuildContext context) => PassCodeScreen(
    code: pass.passCode,
    title: <String>[
      pass.origin.code,
      pass.destination.code,
    ].where((part) => part.trim().isNotEmpty).join('  →  '),
    subtitle: <String>[
      pass.flightNumber,
      FlightFormat.day(pass.departAt),
      FlightFormat.time(pass.departAt),
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' · '),
    reference: pass.bookingRef,
    referenceLabel: 'PNR',
  );
}
