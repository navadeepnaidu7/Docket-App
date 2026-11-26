import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/motion/studio_page_route.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/detail_info_card.dart';
import '../../../../shared/widgets/detail_typography.dart';
import '../../application/pass_list_provider.dart';
import '../../domain/flight_format.dart';
import '../../domain/flight_trip.dart';
import '../../domain/pass_catalog.dart';
import 'flight_pass_detail_screen.dart';

/// Every flight booked with this pass, journey by journey, with the time on
/// the ground between connections. Another leg opens its own pass.
///
/// Reads the trip only through [flightTripJourneys], the same reading the face
/// tag uses, so the two always agree on what is a connection and what is the
/// way home.
class FlightTripCard extends ConsumerWidget {
  const FlightTripCard({super.key, required this.trip});

  final FlightTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);
    final List<WalletPassItem> passes =
        ref.watch(passListProvider).valueOrNull ?? const <WalletPassItem>[];
    FlightPassItem? passFor(String id) {
      for (final WalletPassItem item in passes) {
        if (item is FlightPassItem && item.pass.id == id) return item;
      }
      return null;
    }

    final List<FlightTripJourney> journeys = flightTripJourneys(trip);
    final List<Widget> rows = <Widget>[];
    for (final FlightTripJourney j in journeys) {
      if (j.title.isNotEmpty) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: rows.isEmpty ? 4 : 14, bottom: 2),
            child: Row(
              children: <Widget>[
                Text(j.title, style: DetailType.label(muted)),
                const Spacer(),
                Text(
                  FlightFormat.day(j.legs.first.departAt),
                  style: DetailType.caption(muted),
                ),
              ],
            ),
          ),
        );
      }
      for (int i = 0; i < j.legs.length; i++) {
        final FlightTripLeg leg = j.legs[i];
        if (i > 0) {
          final Duration? wait = layover(j.legs[i - 1], leg);
          if (wait != null && wait.inMinutes > 0) {
            rows.add(
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
                child: Text(
                  '${FlightFormat.compact(wait)} connection in ${leg.from}',
                  style: DetailType.caption(muted),
                ),
              ),
            );
          }
        }
        final bool current = leg.id == trip.current.id;
        final FlightPassItem? target = current ? null : passFor(leg.id);
        rows.add(
          _LegRow(
            key: ValueKey<String>('flight_trip.leg.${leg.id}'),
            leg: leg,
            current: current,
            ink: ink,
            muted: muted,
            onTap: target == null
                ? null
                : () {
                    HapticService.tap();
                    // Replace rather than stack: walking a four-leg trip
                    // should not leave four screens to back out of.
                    Navigator.of(context).pushReplacement(
                      studioPageRoute<void>(
                        builder: (_) =>
                            FlightPassDetailScreen(pass: target.pass),
                      ),
                    );
                  },
          ),
        );
      }
    }

    return DetailInfoCard(title: 'Your trip', children: rows);
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({
    super.key,
    required this.leg,
    required this.current,
    required this.ink,
    required this.muted,
    this.onTap,
  });

  final FlightTripLeg leg;
  final bool current;
  final Color ink;
  final Color muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String depart = FlightFormat.time(leg.departAt);
    final String arrive = FlightFormat.time(leg.arriveAt);
    final String times = depart.isEmpty
        ? ''
        : arrive.isEmpty
        ? depart
        : '$depart – $arrive';
    final int plusDays = FlightFormat.arrivalDayOffset(
      leg.departAt,
      leg.arriveAt,
    );

    return Semantics(
      button: onTap != null,
      selected: current,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${leg.from} → ${leg.to}',
                      style: DetailType.itemTitle(ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      times.isEmpty
                          ? leg.flightNumber
                          : '${leg.flightNumber} · $times'
                                '${plusDays > 0 ? ' +$plusDays' : ''}',
                      style: DetailType.caption(
                        muted,
                      ).copyWith(fontFeatures: AppFonts.tabular),
                    ),
                  ],
                ),
              ),
              if (current)
                Text('This pass', style: DetailType.caption(ink))
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
