import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../../tickets/domain/pass_catalog.dart';
import '../../../tickets/domain/ticket_models.dart';
import 'blur_place_reveal.dart';
import 'easter_egg_constants.dart';
import 'travel_weather_glance.dart';

class EasterEggDrawer extends StatefulWidget {
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
  State<EasterEggDrawer> createState() => _EasterEggDrawerState();
}

class _EasterEggDrawerState extends State<EasterEggDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _contentReveal;

  bool _contentVisible = false;

  @override
  void initState() {
    super.initState();
    _contentReveal = AnimationController(
      vsync: this,
      duration: kEasterEggContentRevealDuration,
    );
    widget.controller.addStatusListener(_onSheetStatusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeStatusListener(_onSheetStatusChanged);
    _contentReveal.dispose();
    super.dispose();
  }

  void _resetContent() {
    _contentVisible = false;
    _contentReveal.stop();
    _contentReveal.value = 0;
  }

  void _startContentReveal() {
    if (!mounted || _contentVisible) return;
    _contentVisible = true;
    _contentReveal.stop();
    _contentReveal.forward(from: 0);
  }

  void _onSheetStatusChanged(AnimationStatus status) {
    if (!mounted) return;
    final AnimationController sheet = widget.controller;

    switch (status) {
      case AnimationStatus.forward:
        // Sheet opening — keep content hidden until fully settled.
        if (sheet.value < 0.99) {
          _resetContent();
        }
      case AnimationStatus.completed:
        if (sheet.value >= 0.99) {
          _startContentReveal();
        }
      case AnimationStatus.reverse:
        // Sheet closing — hide immediately; don't run a slow reverse in parallel.
        _resetContent();
      case AnimationStatus.dismissed:
        _resetContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double panelHeight = kEasterEggPanelHeight;
    final String currentName =
        widget.passports.isNotEmpty ? widget.passports.first.name : '';
    final String firstName =
        currentName.isEmpty ? 'Traveller' : currentName.split(' ').first;
    final int activeTrips = mockWalletPasses
        .where((WalletPassItem p) => p.status == TicketStatus.active)
        .length;
    final int itemCount = widget.passports.length + widget.idDocs.length;

    return GestureDetector(
      onVerticalDragUpdate: widget.onDragUpdate,
      onVerticalDragEnd: widget.onDragEnd,
      child: Container(
        width: double.infinity,
        height: panelHeight + 150.0,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A36), Color(0xFF030811)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          height: panelHeight,
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlurPlaceReveal(
                animation: _contentReveal,
                intervalStart: 0.0,
                intervalEnd: 0.38,
                placementOffset: 20,
                alignment: Alignment.centerLeft,
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
              const SizedBox(height: 8),
              BlurPlaceReveal(
                animation: _contentReveal,
                intervalStart: 0.16,
                intervalEnd: 0.52,
                placementOffset: 24,
                alignment: Alignment.topLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'You have '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.wallet_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ),
                      ),
                      TextSpan(
                        text: '$itemCount items',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const TextSpan(text: ' in your wallet,\n'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ),
                      ),
                      TextSpan(
                        text: '$activeTrips active trips',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const TextSpan(text: ', and '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.offline_pin_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ),
                      ),
                      const TextSpan(
                        text: 'all data offline.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8DA2C4),
                    fontSize: 14,
                    height: 1.38,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: BlurPlaceReveal(
                    animation: _contentReveal,
                    intervalStart: 0.34,
                    intervalEnd: 1.0,
                    placementOffset: 32,
                    alignment: Alignment.bottomCenter,
                    maxBlur: 18,
                    child: const TravelWeatherGlance(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}