import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../../tickets/presentation/wallet_ticket_card.dart';

class EasterEggDrawer extends StatelessWidget {
  const EasterEggDrawer({
    super.key,
    required this.controller,
    required this.dragOffsetNotifier,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.passports,
    required this.idDocs,
    required this.tickets,
    required this.onAddPassport,
    required this.onAddId,
  });

  final AnimationController controller;
  final ValueNotifier<double> dragOffsetNotifier;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final List<MockTicket> tickets;
  final VoidCallback onAddPassport;
  final void Function(IdDocumentType) onAddId;

  @override
  Widget build(BuildContext context) {
    final double panelHeight = 246.0;
    final String currentName = passports.isNotEmpty ? passports.first.name : '';
    final firstName = currentName.isEmpty ? 'Traveller' : currentName.split(' ').first;

    final int hour = DateTime.now().hour;
    final bool isNight = hour < 6 || hour > 18;
    final IconData weatherIcon = isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded;
    final Color weatherIconColor = isNight ? const Color(0xFF8E9AA6) : const Color(0xFFFFD700);
    final String weatherCondition = isNight ? 'Clear Night • 18°C' : 'Bright Sunny Day • 24°C';
    final String weatherPhrase = isNight
        ? "It's a calm, clear night. A great time to review your travel plans."
        : "It's a bright, sunny day. Perfect day to step out and travel!";

    return GestureDetector(
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Container(
        width: double.infinity,
        height: panelHeight + 150.0,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A36), Color(0xFF030811)], // Deep space midnight navy gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Container(
            height: panelHeight,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
            child: ValueListenableBuilder<double>(
              valueListenable: dragOffsetNotifier,
              builder: (context, offsetY, _) {
                // Calculate progress t from 0.0 to 1.0 based on snap threshold (246px)
                final double t = (offsetY / panelHeight).clamp(0.0, 1.0);

                // 1. Greeting progress: reveals from t=0.1 to t=0.6
                final double tGreeting = ((t - 0.1) / 0.5).clamp(0.0, 1.0);
                final double opacityGreeting = tGreeting;
                final double yGreeting = (1.0 - tGreeting) * 12.0;

                // 2. Stats progress: reveals from t=0.25 to t=0.75
                final double tStats = ((t - 0.25) / 0.5).clamp(0.0, 1.0);
                final double opacityStats = tStats;
                final double yStats = (1.0 - tStats) * 12.0;

                // 3. Weather progress: reveals from t=0.4 to t=0.9
                final double tWeather = ((t - 0.4) / 0.5).clamp(0.0, 1.0);
                final double opacityWeather = tWeather;
                final double yWeather = (1.0 - tWeather) * 16.0;
                final double scaleWeather = 0.95 + (0.05 * tWeather);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Greeting
                    Opacity(
                      opacity: opacityGreeting,
                      child: Transform.translate(
                        offset: Offset(0, yGreeting),
                        child: Text(
                          'Hey, $firstName',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Natural language conversational stats
                    Opacity(
                      opacity: opacityStats,
                      child: Transform.translate(
                        offset: Offset(0, yStats),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'You have '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(Icons.wallet_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                ),
                              ),
                              TextSpan(
                                text: '${passports.length + idDocs.length} items',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const TextSpan(text: ' in your wallet,\n'),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(Icons.flight_takeoff_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                ),
                              ),
                              TextSpan(
                                text: '${tickets.where((t) => t.status == TicketStatus.active).length} active trips',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const TextSpan(text: ', and '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(Icons.offline_pin_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                ),
                              ),
                              const TextSpan(
                                text: 'all data offline.',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8DA2C4),
                            fontSize: 15,
                            height: 1.45,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Weather Section (replaces the card miniatures)
                    Opacity(
                      opacity: opacityWeather,
                      child: Transform.translate(
                        offset: Offset(0, yWeather),
                        child: Transform.scale(
                          scale: scaleWeather,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Glow Sun/Moon Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: weatherIconColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    weatherIcon,
                                    color: weatherIconColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        weatherCondition,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        weatherPhrase,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF8DA2C4),
                                          fontSize: 13,
                                          height: 1.3,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
