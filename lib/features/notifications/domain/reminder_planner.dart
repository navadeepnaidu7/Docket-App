import 'package:timezone/timezone.dart' as tz;

import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/pass_display.dart';
import '../../tickets/domain/pass_status.dart';
import '../../tickets/domain/flight_pass_models.dart';
import '../../tickets/domain/train_booking_state.dart';
import 'notification_preferences.dart';

/// FNV-1a, independent of Dart's process-specific String.hashCode.
int notificationId(String identity) {
  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.ticketId,
    required this.at,
    required this.title,
    required this.body,
  });
  final int id;
  final String ticketId, title, body;
  final DateTime at;
  String get fingerprint =>
      '$ticketId|${at.toUtc().toIso8601String()}|$title|$body';
}

bool reminderEligible(WalletPassItem item) {
  if (item.status != TicketStatus.active) return false;
  if (item case TrainPassItem(:final ticket)) {
    if (ticket.runState == TrainRunState.cancelled ||
        ticket.runState == TrainRunState.arrived ||
        TrainBookingState.classify(ticket.bookingStatus) ==
            TrainBookingState.cancelled) {
      return false;
    }
  }
  if (item case FlightPassItem(:final pass)) {
    if (pass.live?.state == FlightLiveState.cancelled ||
        (pass.live?.state.hasDeparted ?? false)) {
      return false;
    }
  }
  return true;
}

/// Reads only genuine start times. Flights in a trip produce a reminder for the
/// first upcoming leg only; subsequent reconciliations advance to the next leg.
DateTime? reminderStart(WalletPassItem item, DateTime now) {
  if (item case FlightPassItem(:final pass)) {
    final upcoming =
        pass.trip?.legs
            .where((l) => l.departAt?.instant.isAfter(now) ?? false)
            .toList()
          ?..sort((a, b) => a.departAt!.instant.compareTo(b.departAt!.instant));
    if (upcoming != null &&
        upcoming.isNotEmpty &&
        upcoming.first.id != item.id) {
      return null;
    }
  }
  return passStartTime(item);
}

String _event(WalletPassItem item) {
  // An unknown venue/station cannot establish that two passes share an event.
  final place = switch (item) {
    MoviePassItem(:final pass) => pass.cinemaName,
    TrainPassItem(:final ticket) =>
      ticket.fromCode.isEmpty ? ticket.fromName : ticket.fromCode,
    BusPassItem(:final pass) => pass.boardingLocation,
    FlightPassItem(:final pass) => pass.origin.code,
  };
  if (place.trim().isEmpty) return '${item.kind.name}|${item.id}';
  return switch (item) {
    MoviePassItem(:final pass) =>
      'movie|${pass.movieTitle}|${pass.cinemaName}|${pass.cinemaAddress}|${pass.screen}',
    TrainPassItem(:final ticket) =>
      'train|${ticket.trainNumber}|${ticket.fromCode}|${ticket.toCode}',
    BusPassItem(:final pass) =>
      'bus|${pass.operator}|${pass.boardingLocation}|${pass.dropLocation}',
    FlightPassItem(:final pass) =>
      'flight|${pass.flightNumber}|${pass.origin.code}|${pass.destination.code}',
  };
}

String _displayClock(WalletPassItem item, DateTime start) {
  if (item case FlightPassItem(:final pass)) {
    final wall = pass.departAt!.local;
    return NotificationPreferences.clock(wall.hour * 60 + wall.minute);
  }
  final (String, String?) raw = switch (item) {
    TrainPassItem(:final ticket) => (ticket.departTime, ticket.departAt),
    MoviePassItem(:final pass) => (pass.showTime, pass.showAt),
    BusPassItem(:final pass) => (pass.departTime, pass.departAt),
    FlightPassItem() => ('', null),
  };
  final clock = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(raw.$1.trim());
  if (clock != null) {
    var hour = int.parse(clock[1]!);
    final minute = int.parse(clock[2]!);
    final meridiem = clock[3]?.toUpperCase();
    if (minute < 60 &&
        (meridiem == null ? hour < 24 : hour >= 1 && hour <= 12)) {
      if (meridiem != null) hour = hour % 12 + (meridiem == 'PM' ? 12 : 0);
      return NotificationPreferences.clock(hour * 60 + minute);
    }
  }
  // An explicit machine offset defines the event clock even when the phone is
  // abroad. DateTime.toLocal is right for scheduling, not for this label.
  final iso = RegExp(r'[Tt ](\d{2}):(\d{2})').firstMatch(raw.$2 ?? '');
  if (iso != null && int.parse(iso[1]!) < 24 && int.parse(iso[2]!) < 60) {
    return '${iso[1]}:${iso[2]}';
  }
  return NotificationPreferences.clock(start.hour * 60 + start.minute);
}

/// Pure planner. [firstSeen] is persisted by the scheduler; no model exposes an
/// added timestamp. Missing entries are treated as newly seen, never as old.
List<PlannedReminder> planReminders({
  required List<WalletPassItem> passes,
  required NotificationPreferences preferences,
  required Map<String, DateTime> firstSeen,
  required DateTime now,
  required tz.Location deviceZone,
  Set<String> excludedIds = const {},
}) {
  if (!preferences.tripReminders) return [];
  final candidates = <({WalletPassItem item, DateTime start})>[];
  for (final item in passes) {
    if (item.id.trim().isEmpty) continue;
    if (excludedIds.contains(item.id) || !reminderEligible(item)) continue;
    final start = reminderStart(item, now);
    if (start != null && start.isAfter(now)) {
      candidates.add((item: item, start: start));
    }
  }
  candidates.sort((a, b) {
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : a.item.id.compareTo(b.item.id);
  });
  final groups = <List<({WalletPassItem item, DateTime start})>>[];
  for (final candidate in candidates) {
    final matching = groups.where(
      (g) =>
          _event(g.first.item) == _event(candidate.item) &&
          candidate.start.difference(g.first.start) <=
              const Duration(minutes: 10),
    );
    if (matching.isEmpty) {
      groups.add([candidate]);
    } else {
      matching.first.add(candidate);
    }
  }
  final result = <PlannedReminder>[];
  for (final group in groups) {
    final start = group.first.start;
    final lead = preferences.leads[group.first.item.kind] ?? 0;
    if (lead == 0) continue;
    var at = start.subtract(Duration(minutes: lead));
    var shifted = false;
    if (preferences.quietEnabled &&
        preferences.quietStart != preferences.quietEnd) {
      final local = tz.TZDateTime.from(at, deviceZone);
      final minutes = local.hour * 60 + local.minute;
      final s = preferences.quietStart, e = preferences.quietEnd;
      final inside = s < e
          ? minutes >= s && minutes < e
          : minutes >= s || minutes < e;
      if (inside) {
        // Fire on the evening this quiet period began: the night before for an
        // early departure, the same evening for a late show. Quiet hours that
        // begin before 21:00 move it to their start instead.
        final beganYesterday = s > e && minutes < e;
        final quietBegin = tz.TZDateTime(
          deviceZone,
          local.year,
          local.month,
          local.day - (beganYesterday ? 1 : 0),
          s ~/ 60,
          s % 60,
        );
        final nine = tz.TZDateTime(
          deviceZone,
          quietBegin.year,
          quietBegin.month,
          quietBegin.day,
          21,
        );
        final evening = nine.isBefore(quietBegin) ? nine : quietBegin;
        var end = tz.TZDateTime(
          deviceZone,
          local.year,
          local.month,
          local.day,
          e ~/ 60,
          e % 60,
        );
        if (!end.isAfter(local)) {
          end = tz.TZDateTime(
            deviceZone,
            local.year,
            local.month,
            local.day + 1,
            e ~/ 60,
            e % 60,
          );
        }
        at = evening.isAfter(now) ? evening : end;
        shifted = true;
      }
    }
    if (!at.isAfter(now) || !at.isBefore(start)) continue;
    final aware = group
        .where(
          (p) =>
              at.difference(firstSeen[p.item.id] ?? now) >=
              const Duration(minutes: 15),
        )
        .toList();
    if (aware.isEmpty) continue;
    final item = aware.first.item;
    final ids = aware.map((p) => p.item.id).toList()..sort();
    final clock = _displayClock(item, start);
    final title = switch (item) {
      MoviePassItem(:final pass) => '${pass.movieTitle} at $clock',
      TrainPassItem(:final ticket) =>
        'Train ${ticket.trainNumber} departs $clock',
      BusPassItem(:final pass) => '${pass.operator} departs $clock',
      FlightPassItem(:final pass) =>
        'Flight ${pass.flightNumber} to ${pass.destination.displayCity} at $clock',
    };
    final body = switch (item) {
      MoviePassItem(:final pass) => [
        pass.cinemaName,
        pass.screen,
        pass.seatListLabel,
      ].where((s) => s.isNotEmpty).join(' · '),
      TrainPassItem(:final ticket) => [
        ticket.fromName,
        ticket.coachSeatLabel,
      ].where((s) => s.isNotEmpty).join(' · '),
      BusPassItem(:final pass) => [
        pass.boardingPoint.isEmpty ? pass.boardingLocation : pass.boardingPoint,
        pass.seatDetails,
      ].where((s) => s.isNotEmpty).join(' · '),
      FlightPassItem(:final pass) => [
        pass.origin.displayCity,
        if (pass.resolvedDepartTerminal.isNotEmpty)
          'Terminal ${pass.resolvedDepartTerminal}',
      ].join(' · '),
    };
    final tomorrow =
        shifted &&
        tz.TZDateTime.from(start, deviceZone).day !=
            tz.TZDateTime.from(at, deviceZone).day;
    result.add(
      PlannedReminder(
        id: notificationId('reminder:${ids.first}'),
        ticketId: item.id,
        at: at,
        title:
            '${aware.length > 1 ? '${aware.length} tickets - ' : ''}${tomorrow ? 'Tomorrow - ' : ''}$title',
        body: body,
      ),
    );
  }
  return result;
}
