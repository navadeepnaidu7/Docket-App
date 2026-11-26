import '../../tickets/domain/pass_status.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.tripReminders = true,
    this.bookingUpdates = true,
    this.journeyLive = true,
    this.quietEnabled = true,
    this.quietStart = 22 * 60 + 30,
    this.quietEnd = 7 * 60,
    this.promptDismissed = false,
    this.leads = defaultLeads,
  });

  static const defaultLeads = {
    PassKind.movie: 120,
    PassKind.flight: 180,
    PassKind.train: 120,
    PassKind.bus: 60,
  };
  static const choices = {
    PassKind.movie: [0, 30, 60, 120, 180],
    PassKind.flight: [0, 120, 180, 240],
    PassKind.train: [0, 60, 120, 180],
    PassKind.bus: [0, 30, 60, 120],
  };
  final bool tripReminders,
      bookingUpdates,
      journeyLive,
      quietEnabled,
      promptDismissed;
  final int quietStart, quietEnd;
  final Map<PassKind, int> leads;

  NotificationPreferences copyWith({
    bool? tripReminders,
    bool? bookingUpdates,
    bool? journeyLive,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
    bool? promptDismissed,
    Map<PassKind, int>? leads,
  }) => NotificationPreferences(
    tripReminders: tripReminders ?? this.tripReminders,
    bookingUpdates: bookingUpdates ?? this.bookingUpdates,
    journeyLive: journeyLive ?? this.journeyLive,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    promptDismissed: promptDismissed ?? this.promptDismissed,
    leads: leads ?? this.leads,
  );

  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  static int? parseClock(Object? raw) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('$raw');
    if (m == null) return null;
    final h = int.parse(m[1]!), min = int.parse(m[2]!);
    return h < 24 && min < 60 ? h * 60 + min : null;
  }

  Map<String, dynamic> serverJson(String timezone) => {
    'bookingUpdates': bookingUpdates,
    'journeyLive': journeyLive,
    'quietHours': {
      'enabled': quietEnabled,
      'start': clock(quietStart),
      'end': clock(quietEnd),
    },
    'timezone': timezone,
  };
  Map<String, dynamic> toJson() => {
    ...serverJson(''),
    'tripReminders': tripReminders,
    'promptDismissed': promptDismissed,
    'leads': {for (final e in leads.entries) e.key.name: e.value},
  };
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final quiet = json['quietHours'] is Map
        ? json['quietHours'] as Map
        : const {};
    final raw = json['leads'] is Map ? json['leads'] as Map : const {};
    bool flag(Object? v, bool fallback) => v is bool ? v : fallback;
    return NotificationPreferences(
      tripReminders: flag(json['tripReminders'], true),
      bookingUpdates: flag(json['bookingUpdates'], true),
      journeyLive: flag(json['journeyLive'], true),
      quietEnabled: flag(quiet['enabled'], true),
      quietStart: parseClock(quiet['start']) ?? 1350,
      quietEnd: parseClock(quiet['end']) ?? 420,
      promptDismissed: flag(json['promptDismissed'], false),
      leads: {
        for (final kind in PassKind.values)
          kind: choices[kind]!.contains(raw[kind.name])
              ? raw[kind.name] as int
              : defaultLeads[kind]!,
      },
    );
  }
}
