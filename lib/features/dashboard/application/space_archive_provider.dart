import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../../tickets/domain/movie_pass_models.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/ticket_models.dart';

class SpaceArchiveData {
  const SpaceArchiveData({
    required this.totalPassesCount,
    required this.totalIdsCount,
    required this.totalPassportsCount,
    required this.topCategoryName,
    required this.topCategoryIcon,
    required this.topCategoryColor,
    required this.categoryCounts,
    required this.dateToPassesMap,
    required this.milestoneTitle,
    required this.milestoneSubtitle,
    required this.peakMonthName,
    required this.recentPassItems,
  });

  final int totalPassesCount;
  final int totalIdsCount;
  final int totalPassportsCount;
  final String topCategoryName;
  final IconData topCategoryIcon;
  final Color topCategoryColor;
  final Map<String, int> categoryCounts;
  final Map<DateTime, List<Object>> dateToPassesMap;
  final String milestoneTitle;
  final String milestoneSubtitle;
  final String peakMonthName;
  final List<Object> recentPassItems;

  int get grandTotal => totalPassesCount + totalIdsCount + totalPassportsCount;
}

final spaceArchiveAnalyticsProvider = Provider<SpaceArchiveData>((Ref ref) {
  final AsyncValue<List<WalletPassItem>> asyncPasses = ref.watch(passListProvider);
  final List<WalletPassItem> passes = asyncPasses.value ?? <WalletPassItem>[];
  final List<IdDocument> ids = ref.watch(idListProvider);
  final List<PassportProfile> passports = ref.watch(passportListProvider);

  int trainCount = 0;
  int movieCount = 0;
  final Map<DateTime, List<Object>> dateMap = <DateTime, List<Object>>{};

  DateTime normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  for (final WalletPassItem item in passes) {
    if (item is TrainPassItem) {
      trainCount++;
      final TrainPass t = item.ticket;
      DateTime? dt;
      if (t.departAt != null) {
        dt = DateTime.tryParse(t.departAt!);
      }
      dt ??= _parseDateString(t.date);
      if (dt != null) {
        final DateTime norm = normalizeDate(dt);
        dateMap.putIfAbsent(norm, () => <Object>[]).add(item);
      }
    } else if (item is MoviePassItem) {
      movieCount++;
      final MoviePass m = item.pass;
      DateTime? dt;
      if (m.showAt != null) {
        dt = DateTime.tryParse(m.showAt!);
      }
      dt ??= _parseDateString(m.showDate);
      if (dt != null) {
        final DateTime norm = normalizeDate(dt);
        dateMap.putIfAbsent(norm, () => <Object>[]).add(item);
      }
    }
  }

  // Also map IDs and Passports to current month/days if date available
  final DateTime nowNorm = normalizeDate(DateTime.now());
  // IDs carry no date of their own. `IdDocument.issueDate` used to be read
  // here, but nothing ever wrote it, so this branch could only ever fall
  // through to today -- which is what it does now, directly.
  for (final IdDocument idDoc in ids) {
    dateMap.putIfAbsent(nowNorm, () => <Object>[]).add(idDoc);
  }

  for (final PassportProfile passport in passports) {
    DateTime? dt = _parseDateString(passport.issueDate);
    dt ??= nowNorm;
    dateMap.putIfAbsent(normalizeDate(dt), () => <Object>[]).add(passport);
  }

  final Map<String, int> catCounts = <String, int>{
    'Transit': trainCount,
    'Cinema': movieCount,
    'Identity': ids.length,
    'Passports': passports.length,
  };

  String topCat = 'Transit';
  int maxVal = trainCount;
  if (movieCount > maxVal) {
    topCat = 'Cinema';
    maxVal = movieCount;
  }
  if (ids.length > maxVal) {
    topCat = 'Identity';
    maxVal = ids.length;
  }
  if (passports.length > maxVal) {
    topCat = 'Passports';
    maxVal = passports.length;
  }

  IconData topIcon;
  Color topColor;
  switch (topCat) {
    case 'Cinema':
      topIcon = Icons.movie_filter_rounded;
      topColor = const Color(0xFF9E121E);
      break;
    case 'Identity':
      topIcon = Icons.badge_rounded;
      topColor = const Color(0xFF2A9D6B);
      break;
    case 'Passports':
      topIcon = Icons.public_rounded;
      topColor = const Color(0xFF1E3A8A);
      break;
    case 'Transit':
    default:
      topIcon = Icons.train_rounded;
      topColor = const Color(0xFFE07A2F);
      break;
  }

  String milestoneTitle = 'Pioneer Explorer';
  String milestoneSubtitle = 'Unlocking passes & seamless digital verification';
  final int grandTotal = passes.length + ids.length + passports.length;
  if (grandTotal > 8) {
    milestoneTitle = 'Galactic Voyager';
    milestoneSubtitle = 'Top 1% wallet activity with rich history archive';
  } else if (grandTotal > 4) {
    milestoneTitle = 'Frequent Traveler';
    milestoneSubtitle = 'Consistently storing active travel & access credentials';
  }

  final List<Object> recentItems = <Object>[
    ...passes,
    ...ids,
    ...passports,
  ];

  return SpaceArchiveData(
    totalPassesCount: passes.length,
    totalIdsCount: ids.length,
    totalPassportsCount: passports.length,
    topCategoryName: topCat,
    topCategoryIcon: topIcon,
    topCategoryColor: topColor,
    categoryCounts: catCounts,
    dateToPassesMap: dateMap,
    milestoneTitle: milestoneTitle,
    milestoneSubtitle: milestoneSubtitle,
    peakMonthName: 'July 2026',
    recentPassItems: recentItems,
  );
});

DateTime? _parseDateString(String raw) {
  if (raw.trim().isEmpty) return null;
  DateTime? dt = DateTime.tryParse(raw);
  if (dt != null) return dt;

  try {
    final List<String> parts = raw.trim().split(RegExp(r'[\s,\/\-]'));
    if (parts.length >= 3) {
      int? year = int.tryParse(parts.last);
      int? day = int.tryParse(parts.first);
      int month = 7;
      if (year != null && day != null) {
        return DateTime(year, month, day);
      }
    }
  } catch (_) {}
  return null;
}
