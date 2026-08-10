import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/id_attachment.dart';

/// Renders a single attachment preview (image or PDF placeholder).
///
/// Attachment byte loading is injected via [resolveBytes] so widget tests can
/// supply synchronous or in-memory byte resolvers without disk I/O.
class AttachmentPreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusCard);

    Widget content;
    if (attachment.kind == IdAttachmentKind.pdf) {
      // PHASE 4 EXTENSION POINT: pdfx page-1 bitmap rendering will replace this static placeholder.
      content = _buildPdfPlaceholder(context, brightness);
    } else {
      content = FutureBuilder<Uint8List>(
        future: resolveBytes(attachment),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
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
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildErrorPlaceholder(context, brightness);
          }
          return Image.memory(
            snapshot.data!,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder(context, brightness);
            },
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: AppTheme.surface(brightness),
        child: content,
      ),
    );
  }

  Widget _buildPdfPlaceholder(BuildContext context, Brightness brightness) {
    // Phase 4 extension point: replace this glyph with the real page-1 bitmap
    // rendered from decrypted bytes via pdfx (PdfDocument.openData).
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
