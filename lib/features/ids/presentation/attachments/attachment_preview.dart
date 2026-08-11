import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/id_attachment.dart';

/// Renders a single attachment preview (image or PDF page 1 bitmap).
///
/// Attachment byte loading is injected via [resolveBytes] so widget tests can
/// supply synchronous or in-memory byte resolvers without disk I/O.
class AttachmentPreview extends StatefulWidget {
  const AttachmentPreview({
    super.key,
    required this.attachment,
    required this.resolveBytes,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final IdAttachment attachment;
  final Future<Uint8List> Function(IdAttachment) resolveBytes;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<AttachmentPreview> {
  /// Resolved once per attachment, never inside build.
  ///
  /// Starting the future in build would restart it on every frame: the hero
  /// pager animates scale and opacity while swiping, so each frame would
  /// re-decrypt the bytes and, for a PDF, re-rasterise page one through the
  /// native renderer. Holding it in State means the work runs once and the
  /// store's decrypted-bytes cache is actually reachable.
  late Future<Uint8List?> _payload;

  @override
  void initState() {
    super.initState();
    _payload = _load();
  }

  @override
  void didUpdateWidget(AttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload only when this slot is actually showing a different attachment.
    // The pager recycles these widgets, so identity is the attachment id, not
    // the widget's position.
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachment.kind != widget.attachment.kind) {
      _payload = _load();
    }
  }

  Future<Uint8List?> _load() {
    return widget.attachment.kind == IdAttachmentKind.pdf
        ? _renderPdfPage1()
        : _loadImageBytes();
  }

  Future<Uint8List?> _loadImageBytes() async {
    try {
      final bytes = await widget.resolveBytes(widget.attachment);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusCard);
    final bool isPdf = widget.attachment.kind == IdAttachmentKind.pdf;

    final Widget content = FutureBuilder<Uint8List?>(
      future: _payload,
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // A PDF shows its own glyph while rasterising, so the tile never
          // reads as empty; an image shows a spinner.
          return isPdf
              ? _buildPdfPlaceholder(context, brightness)
              : Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentOf(brightness),
                    ),
                  ),
                );
        }

        final Uint8List? bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return isPdf
              ? _buildPdfPlaceholder(context, brightness)
              : _buildErrorPlaceholder(context, brightness);
        }

        final Widget image = Image.memory(
          bytes,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (BuildContext context, Object error, StackTrace? _) {
            return isPdf
                ? _buildPdfPlaceholder(context, brightness)
                : _buildErrorPlaceholder(context, brightness);
          },
        );

        if (!isPdf) return image;

        // The badge keeps a PDF distinguishable from a photo at thumbnail size,
        // where the rendered page alone reads as just another document image.
        return Stack(
          children: <Widget>[
            Positioned.fill(child: image),
            Positioned(
              top: 6,
              right: 6,
              child: _buildPdfBadge(context, brightness),
            ),
          ],
        );
      },
    );

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: AppTheme.surface(brightness),
        child: content,
      ),
    );
  }

  /// Decrypts attachment bytes and rasterises page one through pdfx.
  ///
  /// Bytes are handled entirely in memory: no temp file, no path handed to
  /// another app. That is the reason pdfx was chosen over a viewer plugin --
  /// an external viewer would need plaintext written outside the sandbox,
  /// giving away exactly what the at-rest encryption protects.
  ///
  /// Native document and page handles are closed in a finally block; the tray
  /// builds one of these per attachment, so a leaked handle compounds.
  Future<Uint8List?> _renderPdfPage1() async {
    try {
      final bytes = await widget.resolveBytes(widget.attachment);
      if (bytes.isEmpty) return null;

      PdfDocument? document;
      try {
        document = await PdfDocument.openData(bytes);
        final page = await document.getPage(1);
        try {
          // Rendering at the page's own point size leaves the 216pt hero
          // visibly soft, so scale up to a sensible raster and let BoxFit do
          // the rest. Capped so a large-format page cannot allocate wildly.
          final double longEdge = math.max(page.width, page.height);
          final double scale = longEdge <= 0
              ? 1.0
              : (1400 / longEdge).clamp(1.0, 4.0);

          final pageImage = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.jpeg,
          );
          return pageImage?.bytes;
        } finally {
          await page.close();
        }
      } finally {
        await document?.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Overlay badge indicating the attachment is a PDF document.
  Widget _buildPdfBadge(BuildContext context, Brightness brightness) {
    final accent = AppTheme.accentOf(brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        'PDF',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          // Fixed dark ink rather than ink(brightness): the badge sits on the
          // accent fill in both themes, and the dark theme's near-white ink
          // would be unreadable on amber.
          color: AppTheme.ink(Brightness.light),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPdfPlaceholder(BuildContext context, Brightness brightness) {
    return _glyphPlaceholder(
      icon: Icons.picture_as_pdf_rounded,
      iconColor: AppTheme.accentOf(brightness),
      label: 'PDF',
      labelColor: AppTheme.ink(brightness).withValues(alpha: 0.80),
      labelWeight: FontWeight.w600,
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context, Brightness brightness) {
    final inkColor = AppTheme.ink(brightness);
    return _glyphPlaceholder(
      icon: Icons.broken_image_outlined,
      iconColor: inkColor.withValues(alpha: 0.40),
      label: 'Unable to load attachment',
      labelColor: inkColor.withValues(alpha: 0.50),
    );
  }

  /// Icon-over-label placeholder that survives both sizes it is rendered at.
  ///
  /// The same preview is used for the 216pt hero and the 54pt thumbnail, so a
  /// fixed icon and label overflow the strip. The glyph scales with the box and
  /// the label is dropped entirely once there is no honest room for it --
  /// clipping the text instead would leave a half-word looking like damage.
  Widget _glyphPlaceholder({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color labelColor,
    FontWeight labelWeight = FontWeight.w400,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double box = constraints.biggest.shortestSide;
        final bool compact = constraints.maxHeight < 88;
        final double iconSize = box.isFinite
            ? (box * 0.34).clamp(14.0, 36.0)
            : 36.0;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: iconSize, color: iconColor),
              if (!compact) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: labelWeight,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
