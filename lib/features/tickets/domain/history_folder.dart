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
class HistoryMonthSection {
  const HistoryMonthSection({
    required this.label,
    required this.items,
    this.month,
  });

  /// "February 2025", or "Undated" when no date could be resolved.
  final String label;

  /// First of the month, or null for the undated bucket.
  final DateTime? month;

  final List<WalletPassItem> items;

  bool get isUndated => month == null;
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
      };

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

/// Buckets passes into month sections, newest first, undated last.
///
/// Undated passes are never dropped — hiding a pass because a date string did
/// not parse would be worse than showing it without one.
List<HistoryMonthSection> buildHistoryMonthSections(List<WalletPassItem> items) {
  final List<HistoryMonthSection> sections = <HistoryMonthSection>[];
  final List<WalletPassItem> undated = <WalletPassItem>[];

  DateTime? currentMonth;
  List<WalletPassItem> bucket = <WalletPassItem>[];

  void flush() {
    if (currentMonth == null || bucket.isEmpty) return;
    sections.add(
      HistoryMonthSection(
        label: PassActivityDate.monthLabel(currentMonth),
        month: currentMonth,
        items: bucket,
      ),
    );
  }

  // Sorted first, so every dated pass precedes every undated one and months
  // arrive already in descending order.
  for (final WalletPassItem item in _sortByActivityDateDesc(items)) {
    final DateTime? date = PassActivityDate.of(item);
    if (date == null) {
      undated.add(item);
      continue;
    }
    final DateTime month = DateTime(date.year, date.month);
    if (month != currentMonth) {
      flush();
      currentMonth = month;
      bucket = <WalletPassItem>[];
    }
    bucket.add(item);
  }
  flush();

  if (undated.isNotEmpty) {
    sections.add(
      HistoryMonthSection(label: kUndatedSectionLabel, items: undated),
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

/// `Last added <date>` from the newest pass, or null when none has a date.
String? _lastAddedLabel(List<WalletPassItem> ordered) {
  for (final WalletPassItem item in ordered) {
    final DateTime? resolved = PassActivityDate.of(item);
    if (resolved != null) {
      return 'Last added ${PassActivityDate.dayLabel(resolved)}';
    }
  }
  final String? raw = ordered.isEmpty
      ? null
      : HistoryPassPresentation.activityDateLabel(ordered.first);
  return raw == null ? null : 'Last added $raw';
}
