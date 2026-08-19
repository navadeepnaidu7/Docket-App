import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/apple_sheet.dart';
import '../../../tickets/domain/pass_activity_date.dart';
import '../../domain/journey_event.dart';
import '../../domain/place.dart';

/// Raises one memory's card, the way tapping an Apple Maps pin does.
Future<void> showJourneyMemorySheet(
  BuildContext context,
  JourneyEvent event,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => JourneyMemorySheet(event: event),
  );
}

/// What a pin says when you open it.
class JourneyMemorySheet extends StatelessWidget {
  const JourneyMemorySheet({super.key, required this.event});

  final JourneyEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AppleSheet(
      title: event.title,
      subtitle: event.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Chip(label: _kindLabel(event.kind)),
              if (event.when != null) ...<Widget>[
                const SizedBox(width: 8),
                _Chip(label: PassActivityDate.dayLabel(event.when!)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ..._stopRows(theme, scheme),
        ],
      ),
    );
  }

  List<Widget> _stopRows(ThemeData theme, ColorScheme scheme) {
    final List<JourneyStop> stops = event.placedStops.toList();
    if (stops.isEmpty) {
      return <Widget>[
        Text(
          'No place could be resolved for this memory.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppTokens.secondaryLabel(scheme)),
        ),
      ];
    }

    return <Widget>[
      for (int i = 0; i < stops.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == stops.length - 1 ? 0 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isEndpoint(stops[i].role)
                      ? scheme.onSurface
                      : AppTokens.tertiaryLabel(scheme),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      stops[i].place!.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _placeDetail(stops[i].place!),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTokens.secondaryLabel(scheme)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  static bool _isEndpoint(JourneyStopRole role) =>
      role != JourneyStopRole.via;

  static String _placeDetail(Place place) {
    final List<String> parts = <String>[
      if (place.regionCode != null) place.regionCode!,
      if (place.countryCode != null) place.countryCode!,
    ];
    return parts.isEmpty ? place.kind.name : parts.join(' · ');
  }

  static String _kindLabel(JourneyEventKind kind) => switch (kind) {
        JourneyEventKind.train => 'Train',
        JourneyEventKind.bus => 'Bus',
        JourneyEventKind.movie => 'Film',
        JourneyEventKind.flight => 'Flight',
        JourneyEventKind.event => 'Event',
      };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTokens.groupedFieldFill(
          scheme,
          isDark: theme.brightness == Brightness.dark,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTokens.separator(scheme), width: 0.5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppTokens.secondaryLabel(scheme),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
