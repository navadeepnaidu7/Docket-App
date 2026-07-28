import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../../tickets/data/mock_pass_fixtures.dart';
import '../../../tickets/domain/movie_pass_models.dart';
import '../../../tickets/domain/ticket_models.dart';
import 'easter_egg_constants.dart';
import 'travel_weather_glance.dart';

/// The quiet, private layer revealed by pulling the dashboard down.
///
/// This stays mounted for the entire gesture and reads the live offset. That
/// is important: content should be present while the surface is moving, not
/// appear after a second animation has finished.
class EasterEggDrawer extends StatelessWidget {
  const EasterEggDrawer({
    super.key,
    required this.controller,
    required this.dragOffsetNotifier,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.passports,
    required this.idDocs,
    required this.onAddPassport,
    required this.onAddId,
  });

  final AnimationController controller;
  final ValueNotifier<double> dragOffsetNotifier;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final VoidCallback onAddPassport;
  final void Function(IdDocumentType) onAddId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: ValueListenableBuilder<double>(
        valueListenable: dragOffsetNotifier,
        builder: (context, offset, _) {
          final double progress = (offset / kEasterEggPanelHeight).clamp(
            0.0,
            1.0,
          );
          final double contentT = Curves.easeOutCubic.transform(
            ((progress - 0.04) / 0.72).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: 0.55 + (contentT * 0.45),
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - contentT)),
              child: _DrawerContent(passports: passports, idDocs: idDocs),
            ),
          );
        },
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.passports, required this.idDocs});

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;

  @override
  Widget build(BuildContext context) {
    final String name = passports.isNotEmpty ? passports.first.name : '';
    final String firstName = name.isEmpty ? 'Traveller' : name.split(' ').first;
    final int activeTrips =
        mockTrainPasses.where((t) => t.status == TicketStatus.active).length +
        mockMoviePasses.where((m) => m.status == TicketStatus.active).length;
    final int itemCount = passports.length + idDocs.length;
    final TextStyle body = GoogleFonts.inter(
      color: const Color(0xFFA8B8D3),
      fontSize: 13,
      height: 1.4,
      letterSpacing: -0.05,
    );

    return Container(
      width: double.infinity,
      height: kEasterEggPanelHeight + 150,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102A52), Color(0xFF071326), Color(0xFF030811)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'D O C K E T  ·  PRIVATE SPACE',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA8CF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'A little room to breathe, $firstName.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 9),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Your wallet has '),
                TextSpan(
                  text: '$itemCount items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: '$activeTrips active trips',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' · all data offline.'),
              ],
            ),
            style: body,
          ),
          const Spacer(),
          const TravelWeatherGlance(),
        ],
      ),
    );
  }
}
