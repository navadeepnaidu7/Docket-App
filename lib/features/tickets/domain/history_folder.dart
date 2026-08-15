import 'bus_pass_models.dart';
import 'pass_activity_date.dart';
import 'pass_catalog.dart';
import 'pass_history_category.dart';
import 'ticket_models.dart';

/// One category folder in the archive root grid.
class HistoryFolderSummary {
  const HistoryFolderSummary({
    required this.category,
    required this.count,
    required this.items,
    this.lastAddedLabel,
  });

  final PassHistoryCategory category;
  final int count;

  /// Newest first. See [buildHistoryFolders].
  final List<WalletPassItem> items;

  /// Human line such as "Last added 10 Jan 2024", or null when unknown.
  final String? lastAddedLabel;

  String get countLabel => count == 1 ? '1 pass' : '$count passes';
}

/// One month bucket inside a category, newest first.
/// How far apart archive section headers are spaced.
enum HistorySectionSpan {
  /// "February 2025" — the default, and what dated rows use.
  month,

  /// "2025". Posters are dense enough that a header per month would leave
  /// one- and two-tile sections stranded between rules.
  year,
}

class HistoryDateSection {
  const HistoryDateSection({
    required this.label,
    required this.items,
    this.periodStart,
  });

  /// "February 2025", "2025", or "Undated" when no date could be resolved.
  final String label;

  /// Start of the section's period — first of the month or first of the year —
  /// or null for the undated bucket.
  final DateTime? periodStart;

  final List<WalletPassItem> items;

  bool get isUndated => periodStart == null;
}

/// Label for the trailing bucket of passes whose date could not be resolved.
const String kUndatedSectionLabel = 'Undated';

/// Presentation helpers for archive rows.
abstract final class HistoryPassPresentation {
  HistoryPassPresentation._();

  /// Primary title on an archive pass card.
  static String title(WalletPassItem item) => switch (item) {
        TrainPassItem(:final ticket) => _trainTitle(ticket),
        MoviePassItem(:final pass) => pass.movieTitle,
        BusPassItem(:final pass) => _busTitle(pass),
      };

  static String _busTitle(BusPass pass) {
    final String dest = pass.dropLocation.trim();
    if (dest.isEmpty) {
      return pass.operator.trim().isNotEmpty ? pass.operator : 'Bus journey';
    }
    return 'Bus to $dest';
  }

  static String _trainTitle(TrainPass ticket) {
    final String dest = ticket.toName.trim();
    if (dest.isEmpty) {
      final String code = ticket.toCode.trim();
      if (code.isNotEmpty) return 'Train to $code';
      return ticket.trainName.trim().isNotEmpty
          ? ticket.trainName
          : 'Train journey';
    }
    return 'Train to $dest';
  }

  /// Best-effort activity date string already on the pass (display form).
  ///
  /// Fallback for when [PassActivityDate.of] cannot resolve a real date.
  static String? activityDateLabel(WalletPassItem item) => switch (item) {
        TrainPassItem(:final ticket) =>
          ticket.date.trim().isEmpty ? null : ticket.date.trim(),
        MoviePassItem(:final pass) =>
          pass.showDate.trim().isEmpty ? null : pass.showDate.trim(),
        BusPassItem(:final pass) =>
          pass.date.trim().isEmpty ? null : pass.date.trim(),
      };

  /// Date line under the title: normalised when parseable, raw otherwise.
  static String? shortDateLabel(WalletPassItem item) {
    final DateTime? resolved = PassActivityDate.of(item);
    if (resolved != null) return PassActivityDate.shortDayLabel(resolved);
    return activityDateLabel(item);
  }
}

/// Groups expired passes into non-empty archive folders.
///
/// Pure function so tests can exercise grouping without Riverpod.
List<HistoryFolderSummary> buildHistoryFolders(List<WalletPassItem> all) {
  final List<WalletPassItem> expired = all
      .where((WalletPassItem p) => p.status == TicketStatus.expired)
      .toList();

  final Map<PassHistoryCategory, List<WalletPassItem>> grouped =
      <PassHistoryCategory, List<WalletPassItem>>{};

  for (final WalletPassItem item in expired) {
    final PassHistoryCategory cat = item.kind.historyCategory;
    grouped.putIfAbsent(cat, () => <WalletPassItem>[]).add(item);
  }

  final List<HistoryFolderSummary> folders = <HistoryFolderSummary>[];
  final List<PassHistoryCategory> keys = grouped.keys.toList()
    ..sort(
      (PassHistoryCategory a, PassHistoryCategory b) =>
          a.sortOrder.compareTo(b.sortOrder),
    );

  for (final PassHistoryCategory category in keys) {
    final List<WalletPassItem> ordered =
        _sortByActivityDateDesc(grouped[category]!);
    folders.add(
      HistoryFolderSummary(
        category: category,
        count: ordered.length,
        items: ordered,
        lastAddedLabel: _lastAddedLabel(ordered),
      ),
    );
  }

  return folders;
}

/// Buckets passes into dated sections, newest first, undated last.
///
/// [span] controls how coarse the buckets are — see [HistorySectionSpan].
///
/// Undated passes are never dropped — hiding a pass because a date string did
/// not parse would be worse than showing it without one.
List<HistoryDateSection> buildHistorySections(
  List<WalletPassItem> items, {
  HistorySectionSpan span = HistorySectionSpan.month,
}) {
  final List<HistoryDateSection> sections = <HistoryDateSection>[];
  final List<WalletPassItem> undated = <WalletPassItem>[];

  DateTime startOf(DateTime date) => switch (span) {
    HistorySectionSpan.month => DateTime(date.year, date.month),
    HistorySectionSpan.year => DateTime(date.year),
  };

  String labelFor(DateTime start) => switch (span) {
    HistorySectionSpan.month => PassActivityDate.monthLabel(start),
    HistorySectionSpan.year => PassActivityDate.yearLabel(start),
  };

  DateTime? currentStart;
  List<WalletPassItem> bucket = <WalletPassItem>[];

  void flush() {
    if (currentStart == null || bucket.isEmpty) return;
    sections.add(
      HistoryDateSection(
        label: labelFor(currentStart),
        periodStart: currentStart,
        items: bucket,
      ),
    );
  }

  // Sorted first, so every dated pass precedes every undated one and periods
  // arrive already in descending order.
  for (final WalletPassItem item in _sortByActivityDateDesc(items)) {
    final DateTime? date = PassActivityDate.of(item);
    if (date == null) {
      undated.add(item);
      continue;
    }
    final DateTime start = startOf(date);
    if (start != currentStart) {
      flush();
      currentStart = start;
      bucket = <WalletPassItem>[];
    }
    bucket.add(item);
  }
  flush();

  if (undated.isNotEmpty) {
    sections.add(
      HistoryDateSection(label: kUndatedSectionLabel, items: undated),
    );
  }
  return sections;
}

/// Newest first. Undated passes keep their catalog order and sort last.
List<WalletPassItem> _sortByActivityDateDesc(List<WalletPassItem> items) {
  final List<({int index, WalletPassItem item, DateTime? date})> decorated =
      <({int index, WalletPassItem item, DateTime? date})>[
    for (int i = 0; i < items.length; i++)
      (index: i, item: items[i], date: PassActivityDate.of(items[i])),
  ];

  decorated.sort((
    ({int index, WalletPassItem item, DateTime? date}) a,
    ({int index, WalletPassItem item, DateTime? date}) b,
  ) {
    final DateTime? ad = a.date;
    final DateTime? bd = b.date;
    if (ad != null && bd != null) {
      final int byDate = bd.compareTo(ad);
      if (byDate != 0) return byDate;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    // Original order breaks ties so the sort stays stable.
    return a.index.compareTo(b.index);
  });

  return decorated
      .map((({int index, WalletPassItem item, DateTime? date}) d) => d.item)
      .toList();
}

/// `Most recent <date>` from the newest pass, or null when none has a date.
///
/// Deliberately not "Last added": [ordered] is sorted by journey or show time,
/// and no pass model carries an added-at timestamp. A ticket imported today for
/// a trip taken in January is the most recent activity in the folder, not the
/// most recent import, and saying otherwise would be wrong on exactly the passes
/// an archive is full of.
String? _lastAddedLabel(List<WalletPassItem> ordered) {
  for (final WalletPassItem item in ordered) {
    final DateTime? resolved = PassActivityDate.of(item);
    if (resolved != null) {
      return 'Most recent ${PassActivityDate.dayLabel(resolved)}';
    }
  }
  final String? raw = ordered.isEmpty
      ? null
      : HistoryPassPresentation.activityDateLabel(ordered.first);
  return raw == null ? null : 'Most recent $raw';
}
