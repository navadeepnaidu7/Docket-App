import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../domain/pass_code.dart';

/// Draws a pass's real, scannable code.
///
/// The single renderer for every surface that shows a code — the movie, bus and
/// train code screens, the pass faces, and the shared PNG — so the rule that a
/// code is drawn in its own symbology lives in exactly one place. A Code 128
/// booking reference re-rendered as a QR is a symbol no gate reads, which is
/// the whole reason [PassCode] carries its format.
///
/// Callers must not construct this for a pass without a code: `passCode` being
/// null is the no-code signal, and nothing draws a placeholder in its place.
/// See `docs/features/ticket-code-extraction.md`.
class PassCodeView extends StatelessWidget {
  const PassCodeView({
    super.key,
    required this.code,
    required this.width,
    this.height,
  });

  final PassCode code;

  /// Side length for a matrix symbol, or the strip width for a linear one.
  final double width;

  /// Explicit height. Defaults to [width] for matrix symbols and to a printed
  /// strip's proportions for linear ones.
  final double? height;

  /// Ratio of a linear barcode's height to its width. Roughly what a ticket
  /// prints, and tall enough that a scanner's laser line cannot miss it.
  static const double _linearAspect = 0.38;

  /// PDF417 is a stacked symbology, so it is wide but not as flat as a linear
  /// strip. Squashing it to [_linearAspect] would make the rows unreadable.
  static const double _pdf417Aspect = 0.32;

  /// Explicit black on white everywhere. A code tinted to match the brand loses
  /// contrast on a phone screen photographed by another phone, which is exactly
  /// how a forwarded ticket gets scanned.
  static const Color _ink = Color(0xFF000000);
  static const Color _paper = Color(0xFFFFFFFF);

  /// Square for the symbologies that are square, proportioned for the ones
  /// that are not. A DataMatrix drawn into a flat strip does not scan.
  double get _resolvedHeight {
    final double? given = height;
    if (given != null) return given;
    return switch (code.format) {
      PassCodeFormat.qr ||
      PassCodeFormat.aztec ||
      PassCodeFormat.dataMatrix =>
        width,
      PassCodeFormat.pdf417 => width * _pdf417Aspect,
      _ => width * _linearAspect,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (code.format == PassCodeFormat.qr) return _qr();
    return _barcode();
  }

  /// QR goes through `qr_flutter` rather than `barcode_widget`.
  ///
  /// It is what the ID cards and the share card already draw, and it is the
  /// only one of the two that renders a byte-mode payload from raw bytes.
  Widget _qr() {
    final Uint8List? bytes = code.bytes;
    if (bytes != null) {
      // A symbol whose content is not valid UTF-8. Re-encoding it through a
      // String would corrupt it, so the bytes go in untouched.
      final QrCode qr = QrCode.fromUint8List(
        data: bytes,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      return QrImageView.withQr(
        qr: qr,
        size: width,
        gapless: true,
        backgroundColor: _paper,
        eyeStyle: _eyeStyle,
        dataModuleStyle: _moduleStyle,
      );
    }

    return QrImageView(
      data: code.text ?? '',
      version: QrVersions.auto,
      size: width,
      gapless: true,
      backgroundColor: _paper,
      eyeStyle: _eyeStyle,
      dataModuleStyle: _moduleStyle,
    );
  }

  Widget _barcode() {
    final bw.Barcode symbology = _symbologyFor(code.format);
    final Uint8List? bytes = code.bytes;

    // `drawText: false` throughout: the reference a person reads out is already
    // printed under the code in the app's own type, and the package's built-in
    // caption would fight it in a different face.
    if (bytes != null) {
      return bw.BarcodeWidget.fromBytes(
        barcode: symbology,
        data: bytes,
        width: width,
        height: _resolvedHeight,
        drawText: false,
        color: _ink,
        backgroundColor: _paper,
        errorBuilder: (BuildContext _, String _) => const SizedBox.shrink(),
      );
    }

    final String text = code.text ?? '';
    return bw.BarcodeWidget(
      barcode: symbology,
      data: text,
      width: width,
      height: _resolvedHeight,
      drawText: false,
      color: _ink,
      backgroundColor: _paper,
      // A payload the symbology refuses — a check digit the decoder read but
      // the encoder rejects, say. Printing it as text is not a scannable code,
      // but it is the string a counter clerk can type in, which beats an error
      // glyph or an empty box.
      errorBuilder: (BuildContext context, String _) => Center(
        child: SelectableText(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: _ink,
          ),
        ),
      ),
    );
  }

  static const QrEyeStyle _eyeStyle = QrEyeStyle(
    eyeShape: QrEyeShape.square,
    color: _ink,
  );

  static const QrDataModuleStyle _moduleStyle = QrDataModuleStyle(
    dataModuleShape: QrDataModuleShape.square,
    color: _ink,
  );

  /// Maps a decoded format onto the encoder that reproduces it.
  ///
  /// Never guesses: every value here is one ML Kit can return, and QR is
  /// handled before this is reached.
  static bw.Barcode _symbologyFor(PassCodeFormat format) => switch (format) {
        PassCodeFormat.qr => bw.Barcode.qrCode(),
        PassCodeFormat.aztec => bw.Barcode.aztec(),
        PassCodeFormat.dataMatrix => bw.Barcode.dataMatrix(),
        PassCodeFormat.pdf417 => bw.Barcode.pdf417(),
        PassCodeFormat.code128 => bw.Barcode.code128(),
        PassCodeFormat.code39 => bw.Barcode.code39(),
        PassCodeFormat.code93 => bw.Barcode.code93(),
        PassCodeFormat.codabar => bw.Barcode.codabar(),
        PassCodeFormat.ean13 => bw.Barcode.ean13(),
        PassCodeFormat.ean8 => bw.Barcode.ean8(),
        PassCodeFormat.itf => bw.Barcode.itf(),
        PassCodeFormat.upcA => bw.Barcode.upcA(),
        PassCodeFormat.upcE => bw.Barcode.upcE(),
      };
}

/// A pass code on the white plate a scanner expects, or an honest empty state.
///
/// The plate is white and the code is black on it regardless of theme: a gate
/// scanner reads reflected contrast, and a dark-mode code is the one that fails
/// at the turnstile.
///
/// When [code] is null this draws a bordered box saying so instead. That is the
/// whole point — before this feature the code screens drew a procedural grid
/// that encoded nothing, and a user cannot tell that apart from a real code
/// until a scanner rejects it. The rule matches the shared PNG's, written down
/// in `docs/features/pass-share.md`.
class PassCodePlate extends StatelessWidget {
  const PassCodePlate({
    super.key,
    required this.code,
    this.width = 260,
    this.emptyLabel = 'This ticket has no scannable code',
    this.shadowColor,
  });

  final PassCode? code;

  /// Side of the plate for a matrix code; the strip width for a linear one.
  final double width;

  /// Shown in place of the plate when the pass carries no code.
  final String emptyLabel;

  /// Tint under the plate. Defaults to plain black at theme-appropriate alpha.
  final Color? shadowColor;

  static const double _plateInset = 18;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final PassCode? c = code;

    if (c == null) return _empty(context, isDark);

    return Container(
      padding: const EdgeInsets.all(_plateInset),
      decoration: BoxDecoration(
        color: PassCodeView._paper,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (shadowColor ?? Colors.black)
                .withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: PassCodeView(code: c, width: width),
    );
  }

  /// No plate here on purpose. A white slab reads as "code goes here" and
  /// invites the user to hold up a blank rectangle at a gate.
  Widget _empty(BuildContext context, bool isDark) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: width + _plateInset * 2,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.withValues(alpha: isDark ? 0.16 : 0.12)),
      ),
      child: Text(
        emptyLabel,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: ink.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
