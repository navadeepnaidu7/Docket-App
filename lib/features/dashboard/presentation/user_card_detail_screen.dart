import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/domain/movie_pass_models.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/ticket_models.dart';
import '../application/space_archive_provider.dart';
import 'settings_screen.dart';

class UserCardDetailScreen extends ConsumerStatefulWidget {
  const UserCardDetailScreen({super.key});

  @override
  ConsumerState<UserCardDetailScreen> createState() => _UserCardDetailScreenState();
}

class _UserCardDetailScreenState extends ConsumerState<UserCardDetailScreen> {
  int _selectedTab = 0; // 0: Highlights, 1: Activity Calendar
  DateTime _calendarMonth = DateTime(2026, 7, 1);
  DateTime? _selectedDate = DateTime(2026, 7, 27);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SpaceArchiveData data = ref.watch(spaceArchiveAnalyticsProvider);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);

    final Color bg = theme.scaffoldBackgroundColor;
    final Color surface = isDark ? const Color(0xFF161820) : const Color(0xFFFFFFFF);
    final Color ink = isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final Color muted = isDark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top Navigation Bar (Clean Back Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () {
                      HapticService.select();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Content featuring Hero Card prominently on top
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: <Widget>[
                  // Prominent Hero Card visible on top
                  SizedBox(
                    height: kSettingsHeroHeight,
                    child: WalletMembershipCard(
                      passports: passports,
                      idDocs: idDocs,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Segmented Switcher directly below hero card
                  _buildSegmentedControl(surface, ink, muted, border, isDark),
                  const SizedBox(height: 16),

                  // Content Tabs (Highlights vs Activity Calendar)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _selectedTab == 0
                        ? _buildHighlightsTab(data, surface, ink, muted, border, isDark)
                        : _buildCalendarTab(data, surface, ink, muted, border, isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(
    Color surface,
    Color ink,
    Color muted,
    Color border,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticService.select();
                setState(() => _selectedTab = 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Highlights',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                      color: _selectedTab == 0 ? ink : muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticService.select();
                setState(() => _selectedTab = 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Activity Calendar',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                      color: _selectedTab == 1 ? ink : muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Highlights Presentation View ──────────────────────────────────
  Widget _buildHighlightsTab(
    SpaceArchiveData data,
    Color surface,
    Color ink,
    Color muted,
    Color border,
    bool isDark,
  ) {
    return Column(
      key: const ValueKey<int>(0),
      children: <Widget>[
        // Milestone Card with Rich Typography
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: data.topCategoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.sparkles,
                      color: data.topCategoryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MILESTONE SUMMARY',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: data.topCategoryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.milestoneTitle,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.milestoneSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: muted,
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildRichStatBadge(
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    iconColor: const Color(0xFF5E5CE6),
                    value: '${data.grandTotal}',
                    label: 'Total Credentials',
                    ink: ink,
                    muted: muted,
                  ),
                  _buildRichStatBadge(
                    icon: CupertinoIcons.ticket_fill,
                    iconColor: const Color(0xFFE07A2F),
                    value: '${data.totalPassesCount}',
                    label: 'Active Passes',
                    ink: ink,
                    muted: muted,
                  ),
                  _buildRichStatBadge(
                    icon: CupertinoIcons.calendar,
                    iconColor: const Color(0xFF2A9D6B),
                    value: data.peakMonthName.split(' ').first,
                    label: 'Peak Month',
                    ink: ink,
                    muted: muted,
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),

        const SizedBox(height: 16),

        // Category Breakdown Card with Rich Icons
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: data.topCategoryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data.topCategoryIcon,
                      color: data.topCategoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'TOP CATEGORY',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: muted,
                        ),
                      ),
                      Text(
                        data.topCategoryName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...data.categoryCounts.entries.map((MapEntry<String, int> entry) {
                final double fraction = data.grandTotal > 0
                    ? (entry.value / data.grandTotal).clamp(0.05, 1.0)
                    : 0.0;
                final IconData catIcon = _getCategoryIcon(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(catIcon, size: 16, color: muted),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${entry.value} items',
                            style: GoogleFonts.robotoMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          backgroundColor: border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.key == data.topCategoryName
                                ? data.topCategoryColor
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ).animate().fadeIn(duration: 450.ms, delay: 80.ms).slideY(begin: 0.04, end: 0),

        const SizedBox(height: 16),

        // Security & Verification Badge Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: Color(0xFF30D158),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '100% Encrypted & On-Device',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      'Passes & credentials are authenticated locally.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 140.ms).slideY(begin: 0.04, end: 0),
      ],
    );
  }

  Widget _buildRichStatBadge({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color ink,
    required Color muted,
  }) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Cinema':
        return Icons.movie_filter_rounded;
      case 'Identity':
        return Icons.badge_rounded;
      case 'Passports':
        return Icons.public_rounded;
      case 'Transit':
      default:
        return Icons.train_rounded;
    }
  }

  // ── Activity Calendar View ─────────────────────────────────────────
  Widget _buildCalendarTab(
    SpaceArchiveData data,
    Color surface,
    Color ink,
    Color muted,
    Color border,
    bool isDark,
  ) {
    final int daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final int firstWeekday =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday;

    final DateTime normSelected = _selectedDate != null
        ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day)
        : DateTime(2026, 7, 27);

    final List<Object> passesOnSelectedDate =
        data.dateToPassesMap[normSelected] ?? <Object>[];

    return Column(
      key: const ValueKey<int>(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Calendar Grid Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            children: <Widget>[
              // Month Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'July 2026',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded, color: ink),
                        onPressed: () {
                          HapticService.select();
                          setState(() {
                            _calendarMonth = DateTime(
                                _calendarMonth.year, _calendarMonth.month - 1);
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded, color: ink),
                        onPressed: () {
                          HapticService.select();
                          setState(() {
                            _calendarMonth = DateTime(
                                _calendarMonth.year, _calendarMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weekday Headers
              Row(
                children: <String>['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((String day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 35,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final int dayNum = index - (firstWeekday - 2);
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final DateTime date =
                      DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
                  final bool isSelected = date.year == normSelected.year &&
                      date.month == normSelected.month &&
                      date.day == normSelected.day;

                  final List<Object>? dayPasses = data.dateToPassesMap[date];
                  final bool hasPasses = dayPasses != null && dayPasses.isNotEmpty;

                  return GestureDetector(
                    onTap: () {
                      HapticService.select();
                      setState(() => _selectedDate = date);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5E5CE6)
                            : (hasPasses
                                ? (isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFE5E5EA))
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Text(
                            '$dayNum',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (hasPasses ? ink : muted.withValues(alpha: 0.6)),
                            ),
                          ),
                          if (hasPasses && !isSelected)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF5E5CE6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),

        const SizedBox(height: 18),

        // Selected Date Header
        Text(
          'Passes on ${_formatDateLabel(normSelected)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),

        if (passesOnSelectedDate.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Center(
              child: Text(
                'No recorded passes or documents for this date.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: muted,
                ),
              ),
            ),
          )
        else
          ...passesOnSelectedDate.map((Object item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPassDetailTile(item, surface, ink, muted, border, isDark),
            );
          }),
      ],
    );
  }

  Widget _buildPassDetailTile(
    Object item,
    Color surface,
    Color ink,
    Color muted,
    Color border,
    bool isDark,
  ) {
    String title = 'Pass Document';
    String subtitle = 'Wallet Item';
    IconData icon = Icons.confirmation_number_rounded;
    Color accent = const Color(0xFF5E5CE6);

    if (item is TrainPassItem) {
      final TrainPass t = item.ticket;
      title = '${t.trainNumber} · ${t.trainName}';
      subtitle = '${t.fromCode} → ${t.toCode} (${t.date})';
      icon = Icons.train_rounded;
      accent = const Color(0xFFE07A2F);
    } else if (item is MoviePassItem) {
      final MoviePass m = item.pass;
      title = m.movieTitle;
      subtitle = '${m.cinemaName} (${m.showDate} ${m.showTime})';
      icon = Icons.movie_filter_rounded;
      accent = const Color(0xFF9E121E);
    } else if (item is IdDocument) {
      title = item.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card';
      subtitle = item.holderName;
      icon = Icons.badge_rounded;
      accent = const Color(0xFF2A9D6B);
    } else if (item is PassportProfile) {
      title = 'Passport Profile';
      subtitle = item.name;
      icon = Icons.public_rounded;
      accent = const Color(0xFF1E3A8A);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  String _formatDateLabel(DateTime dt) {
    final List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
