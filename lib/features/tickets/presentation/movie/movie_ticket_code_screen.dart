import 'package:flutter/material.dart';

import '../../domain/movie_pass_models.dart';
import '../pass_code_screen.dart';

/// Movie-specific content for the shared scan view.
class MovieTicketCodeScreen extends StatelessWidget {
  const MovieTicketCodeScreen({super.key, required this.pass});

  final MoviePass pass;

  @override
  Widget build(BuildContext context) => PassCodeScreen(
    code: pass.passCode,
    title: pass.movieTitle,
    subtitle: <String>[
      pass.showDate,
      pass.showTime,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' · '),
    reference: pass.bookingId,
  );
}
