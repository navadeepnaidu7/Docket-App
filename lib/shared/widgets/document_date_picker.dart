import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'apple_sheet.dart';

enum DocumentDateKind { dateOfBirth, expiry, any }

/// Shared Cupertino date sheet used by passport and ID entry.
Future<void> showDocumentDatePicker({
  required BuildContext context,
  required TextEditingController controller,
  required VoidCallback onChanged,
  DocumentDateKind kind = DocumentDateKind.any,
  bool adultDob = false,
  String title = 'Select Date',
}) async {
  DateTime init = DateTime(2000, 1, 1);
  if (controller.text.isNotEmpty) {
    try {
      init = DateTime.parse(controller.text);
    } catch (_) {}
  }

  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  DateTime minDate = DateTime(1900);
  DateTime maxDate = DateTime(now.year + 30);

  switch (kind) {
    case DocumentDateKind.dateOfBirth:
      minDate = DateTime(1900);
      maxDate = adultDob
          ? DateTime(now.year - 18, now.month, now.day)
          : today.subtract(const Duration(days: 1));
    case DocumentDateKind.expiry:
      minDate = today.add(const Duration(days: 1));
      maxDate = DateTime(now.year + 20, now.month, now.day);
    case DocumentDateKind.any:
      break;
  }

  if (init.isBefore(minDate)) init = minDate;
  if (init.isAfter(maxDate)) init = maxDate;

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
              mode: CupertinoDatePickerMode.date,
              initialDateTime: init,
              minimumDate: minDate,
              maximumDate: maxDate,
              onDateTimeChanged: (DateTime d) {
                controller.text =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                onChanged();
              },
            ),
          ),
        ),
      );
    },
  );
}
