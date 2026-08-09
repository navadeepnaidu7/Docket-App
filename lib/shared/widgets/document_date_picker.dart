import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'apple_sheet.dart';

enum DocumentDateKind { dateOfBirth, expiry, any }

/// Sentinel returned by [showDocumentDatePicker] when the user taps Clear.
const String kDocumentDateCleared = '';

/// Shared Cupertino date sheet used by passport and ID entry.
///
/// Two modes. By default the picker writes straight through to [controller] as
/// the wheel turns, which is what a form field bound to that controller wants,
/// and the return value is null. With [showActions] the sheet grows a
/// Clear/Cancel/Done row, leaves [controller] alone, and returns the ISO date on
/// Done, [kDocumentDateCleared] on Clear, or null when dismissed — for callers
/// where closing the sheet *is* the commit, and a spin-then-dismiss must not
/// save.
Future<String?> showDocumentDatePicker({
  required BuildContext context,
  required TextEditingController controller,
  VoidCallback? onChanged,
  DocumentDateKind kind = DocumentDateKind.any,
  bool adultDob = false,
  String title = 'Select Date',
  bool showActions = false,
  bool allowClear = false,
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

  String pending = _isoDate(init);

  return showModalBottomSheet<String?>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
      final Color ink =
          isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);

      return AppleSheet(
        title: title,
        showDragHandle: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
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
                    if (showActions) {
                      pending = _isoDate(d);
                      return;
                    }
                    controller.text = _isoDate(d);
                    onChanged?.call();
                  },
                ),
              ),
            ),
            if (showActions) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  if (allowClear)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(kDocumentDateCleared),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: ink.withValues(alpha: 0.55)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(pending),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
