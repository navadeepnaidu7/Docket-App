import 'movie_pass_models.dart';
import 'pass_catalog.dart';
import 'pass_history_category.dart';
import 'ticket_models.dart';

/// One category folder in the History root grid.
class HistoryFolderSummary {
  const HistoryFolderSummary({
    required this.category,
    required this.count,
    required this.items,
    this.lastAddedLabel,
  });

  final PassHistoryCategory category;
  final int count;
  final List<WalletPassItem> items;

  /// Human line such as "Last added 10 Jan 2024", or null when unknown.
  final String? lastAddedLabel;

  String get countLabel => count == 1 ? '1 pass' : '$count passes';
}

/// Presentation helpers for history strip rows.
abstract final class HistoryPassPresentation {
  HistoryPassPresentation._();

  /// Primary title on a horizontal history strip.
  static String title(WalletPassItem item) => switch (item) {
        TrainPassItem(:final ticket) => _trainTitle(ticket),
        MoviePassItem(:final pass) => pass.movieTitle,
      };

  /// Secondary line under the title (date / cinema), may be empty.
  static String subtitle(WalletPassItem item) => switch (item) {
        TrainPassItem(:final ticket) => _trainSubtitle(ticket),
        MoviePassItem(:final pass) => _movieSubtitle(pass),
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

  static String _trainSubtitle(TrainPass ticket) {
    final List<String> parts = <String>[];
    if (ticket.date.trim().isNotEmpty) parts.add(ticket.date.trim());
    if (ticket.trainNumber.trim().isNotEmpty) {
      parts.add(ticket.trainNumber.trim());
    }
    return parts.join(' · ');
  }

  static String _movieSubtitle(MoviePass pass) {
    final List<String> parts = <String>[];
    if (pass.showDate.trim().isNotEmpty) parts.add(pass.showDate.trim());
    if (pass.cinemaName.trim().isNotEmpty) parts.add(pass.cinemaName.trim());
    return parts.join(' · ');
  }

  /// Best-effort activity date string already on the pass (display form).
  static String? activityDateLabel(WalletPassItem item) => switch (item) {
        TrainPassItem(:final ticket) =>
          ticket.date.trim().isEmpty ? null : ticket.date.trim(),
        MoviePassItem(:final pass) =>
          pass.showDate.trim().isEmpty ? null : pass.showDate.trim(),
      };
}

/// Groups expired passes into non-empty history folders.
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
    final List<WalletPassItem> items =
        List<WalletPassItem>.of(grouped[category]!);
    // Stable reverse order so newer fixtures (later in list) tend to surface;
    // real ISO timestamps can replace this later.
    final List<WalletPassItem> ordered = items.reversed.toList();
    final String? lastLabel = ordered.isEmpty
        ? null
        : HistoryPassPresentation.activityDateLabel(ordered.first);

    folders.add(
      HistoryFolderSummary(
        category: category,
        count: ordered.length,
        items: ordered,
        lastAddedLabel: lastLabel == null ? null : 'Last added $lastLabel',
      ),
    );
  }

  return folders;
}
