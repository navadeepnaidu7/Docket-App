/// Chrome shared by the MRZ and ID scanners.
///
/// Both screens carried their own private `_GlassButton`, `_OutlineButton` and
/// `_PreviewField`, identical apart from drift: one had picked up a `maxLines`
/// option the other had not, and their paddings had diverged by a pixel or two.
/// Camera chrome sits over a live preview and is therefore always light-on-dark
/// regardless of the app theme, so it does not belong in `AppTheme`; it does
/// belong in one place.
library;

import 'package:flutter/material.dart';

/// A 44x44 translucent icon button for use over a camera preview.
class ScannerGlassButton extends StatelessWidget {
  const ScannerGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Inverts the button for the rare light surface -- a review sheet rather
  /// than the viewfinder.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: dark ? Colors.black12 : Colors.white24,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? Colors.black12 : Colors.white30),
        ),
        child: Icon(icon, color: dark ? Colors.black : Colors.white, size: 22),
      ),
    );
  }
}

/// A full-width outlined action for the scanner's error and permission states.
class ScannerOutlineButton extends StatelessWidget {
  const ScannerOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// An editable row on a scanner's review step.
class ScannerPreviewField extends StatelessWidget {
  const ScannerPreviewField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final bool multiline = maxLines > 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: multiline ? 14 : 0),
            child: Icon(icon, color: const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
