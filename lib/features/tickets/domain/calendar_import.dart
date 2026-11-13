import 'package:flutter/foundation.dart';

/// Server-side state of the Google Calendar link (`GET /v1/integrations/google-calendar`).
enum CalendarLinkState {
  unavailable,
  disconnected,
  connected,
  syncing,
  reconnectRequired;

  static CalendarLinkState fromWire(String? raw) => switch (raw) {
    'connected' => CalendarLinkState.connected,
    'syncing' => CalendarLinkState.syncing,
    'reconnect_required' => CalendarLinkState.reconnectRequired,
    _ => CalendarLinkState.disconnected,
  };
}

@immutable
class CalendarConnectionStatus {
  const CalendarConnectionStatus({
    required this.available,
    required this.state,
    this.unavailableReason,
    this.accountEmail,
    this.lastSyncAt,
    this.lastSuccessfulSyncAt,
    this.nextSyncAt,
    this.lastErrorCode,
    this.importedCount = 0,
    this.needsDetailsCount = 0,
  });

  /// Client-side only: mock passes are on, so there is no real server to link.
  static const CalendarConnectionStatus mockMode = CalendarConnectionStatus(
    available: false,
    state: CalendarLinkState.unavailable,
    unavailableReason: 'mock_mode',
  );

  final bool available;
  final CalendarLinkState state;
  final String? unavailableReason;
  final String? accountEmail;
  final DateTime? lastSyncAt;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? nextSyncAt;
  final String? lastErrorCode;
  final int importedCount;
  final int needsDetailsCount;

  bool get isLinked =>
      state == CalendarLinkState.connected ||
      state == CalendarLinkState.syncing;

  factory CalendarConnectionStatus.fromJson(Map<String, dynamic> json) {
    final bool available = json['available'] == true;
    return CalendarConnectionStatus(
      available: available,
      state: available
          ? CalendarLinkState.fromWire(json['status']?.toString())
          : CalendarLinkState.unavailable,
      unavailableReason: _str(json['unavailableReason']),
      accountEmail: _str(json['accountEmail']),
      lastSyncAt: _time(json['lastSyncAt']),
      lastSuccessfulSyncAt: _time(json['lastSuccessfulSyncAt']),
      nextSyncAt: _time(json['nextSyncAt']),
      lastErrorCode: _str(json['lastErrorCode']),
      importedCount: (json['importedCount'] as num?)?.toInt() ?? 0,
      needsDetailsCount: (json['needsDetailsCount'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _str(Object? v) {
    final String s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static DateTime? _time(Object? v) {
    final String? s = _str(v);
    return s == null ? null : DateTime.tryParse(s);
  }
}

/// A calendar call the server refused, with its stable `code`.
class CalendarImportException implements Exception {
  const CalendarImportException(
    this.code,
    this.message, {
    this.retryAfterSeconds,
  });

  final String code;
  final String message;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

/// Plain-language explanation for an unavailable or failed state.
String calendarReasonCopy(String? code) => switch (code) {
  'mock_mode' =>
    'Mock passes are on. Turn them off and use a real server to connect a calendar.',
  'disabled' ||
  'not_configured' => 'Calendar import is not set up on this server yet.',
  'shared_demo_account' =>
    'You are using the shared demo account. Sign in with your own Google account to connect your calendar.',
  'google_sign_in_required' => 'Sign in with Google to connect your calendar.',
  'grant_revoked' || 'access_forbidden' || 'credential_unreadable' =>
    'Google no longer allows Docket to read your calendar. Reconnect to resume.',
  'google_rate_limited' =>
    'Google asked Docket to slow down. Sync will retry automatically.',
  'google_unavailable' || 'token_refresh_failed' || 'list_failed' =>
    'Google Calendar could not be reached. Sync will retry automatically.',
  'import_failed' ||
  'sync_failed' => 'The last sync did not finish. It will retry automatically.',
  'sync_throttled' => 'A sync was requested moments ago. Try again shortly.',
  _ => 'Something went wrong. Try again.',
};

/// The `importInfo` block the server adds to passes that came from (or were merged with)
/// a Google Calendar event. Absent for ordinary uploads.
@immutable
class PassImportInfo {
  const PassImportInfo({
    required this.needsDetails,
    this.missingFields = const <String>[],
    this.sourceRemoved = false,
    this.ticketAttached = false,
  });

  final bool needsDetails;
  final List<String> missingFields;
  final bool sourceRemoved;
  final bool ticketAttached;

  /// A useful itinerary may still lack its entry code or booking reference.
  /// Let the user attach that evidence even when its basic event details exist.
  bool get canAttachTicket =>
      !ticketAttached && (needsDetails || missingFields.isNotEmpty);

  static PassImportInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? missing = raw['missingFields'];
    return PassImportInfo(
      needsDetails: raw['needsDetails'] == true,
      missingFields: missing is List
          ? missing.map((Object? e) => e.toString()).toList(growable: false)
          : const <String>[],
      sourceRemoved: raw['sourceRemoved'] == true,
      ticketAttached: raw['ticketAttached'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': 'googleCalendar',
    'needsDetails': needsDetails,
    'missingFields': missingFields,
    if (sourceRemoved) 'sourceRemoved': true,
    if (ticketAttached) 'ticketAttached': true,
  };

  /// Human labels for the fields a calendar event did not carry.
  List<String> get missingLabels => missingFields
      .map(
        (String f) => switch (f) {
          'pnr' => 'PNR',
          'departureTime' || 'boardingTime' || 'showTime' => 'time',
          'route' => 'route',
          'passengers' => 'passenger names',
          'seat' || 'seats' => 'seat',
          'ticketCode' => 'ticket code',
          'bookingId' => 'booking ID',
          'movieTitle' => 'film title',
          'cinemaName' => 'cinema',
          'boardingLocation' => 'boarding point',
          'dropLocation' => 'drop point',
          'operator' => 'operator',
          _ => f,
        },
      )
      .toSet()
      .toList(growable: false);
}
