import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import 'easter_egg_constants.dart';
import 'travel_weather_glance.dart';

/// A quiet sky behind the wallet, revealed continuously by the user's pull.
class EasterEggDrawer extends StatefulWidget {
  const EasterEggDrawer({
    super.key,
    required this.dragOffsetNotifier,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.passports,
    required this.idDocs,
    this.now,
  });
  final ValueNotifier<double> dragOffsetNotifier;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final DateTime? now;

  @override
  State<EasterEggDrawer> createState() => _EasterEggDrawerState();
}

class _EasterEggDrawerState extends State<EasterEggDrawer> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final name = widget.passports.isEmpty
        ? ''
        : widget.passports.first.name.trim().split(RegExp(r'\s+')).first;
    final count = widget.passports.length + widget.idDocs.length;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(now);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: widget.onDragUpdate,
      onVerticalDragEnd: widget.onDragEnd,
      onVerticalDragCancel: widget.onDragCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: widget.dragOffsetNotifier,
        builder: (context, offset, _) {
          final progress = (offset / kEasterEggPanelHeight).clamp(0.0, 1.0);
          final reveal = Curves.easeOutCubic.transform(
            ((progress - 0.12) / 0.7).clamp(0.0, 1.0),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: TravelWeatherGlance(hour: now.hour, progress: progress),
              ),
              Positioned(
                left: 28,
                right: 28,
                top: MediaQuery.paddingOf(context).top + 26,
                bottom: 176,
                child: ExcludeSemantics(
                  excluding: progress < 0.8,
                  child: Opacity(
                    opacity: reveal,
                    child: Transform.translate(
                      offset: Offset(0, reduced ? 0 : 10 * (1 - reveal)),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontFamily: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.fontFamily,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Color(0x330B2140), blurRadius: 12),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      date.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xDDE8F2FF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.7,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      name.isEmpty
                                          ? '$greeting.'
                                          : '$greeting, $name.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.9,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: count == 0
                                                ? 'A little space for '
                                                : 'You have ',
                                          ),
                                          TextSpan(
                                            text: count == 0
                                                ? 'what’s next.'
                                                : '$count ${count == 1 ? 'document' : 'documents'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (count > 0)
                                            const TextSpan(text: ' at hand.'),
                                        ],
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xD9E5EEFB),
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.lock_shield,
                                          color: Color(0xBFE0EDFF),
                                          size: 12,
                                        ),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Your day, a little lighter.',
                                            style: TextStyle(
                                              color: Color(0xBFE0EDFF),
                                              fontSize: 11,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
