import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/apple_sheet.dart';

/// Formats minutes-from-midnight as a short local time, e.g. "7:00 AM".
String formatMinutesOfDay(int minutes) {
  final int clamped = minutes.clamp(0, 24 * 60 - 1);
  final int h24 = clamped ~/ 60;
  final int m = clamped % 60;
  final int h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final String period = h24 >= 12 ? 'PM' : 'AM';
  final String mm = m.toString().padLeft(2, '0');
  return '$h12:$mm $period';
}

DateTime _dateTimeFromMinutes(int minutes) {
  final int clamped = minutes.clamp(0, 24 * 60 - 1);
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day, clamped ~/ 60, clamped % 60);
}

/// Cupertino time sheet consistent with document date pickers.
Future<int?> showThemeTimePicker({
  required BuildContext context,
  required String title,
  required int initialMinutes,
}) async {
  int selected = initialMinutes.clamp(0, 24 * 60 - 1);

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AppleSheet(
        title: title,
        showDragHandle: true,
        child: SizedBox(
          height: 220,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 20,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: _dateTimeFromMinutes(selected),
              onDateTimeChanged: (DateTime d) {
                selected = d.hour * 60 + d.minute;
              },
            ),
          ),
        ),
      );
    },
  );

  return selected;
}
