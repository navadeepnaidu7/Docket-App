import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/id_attachment.dart';
import 'attachment_add_tile.dart';
import 'attachment_preview.dart';

/// Horizontal row of attachment thumbnails with an optional trailing add tile.
class AttachmentThumbStrip extends StatelessWidget {
  const AttachmentThumbStrip({
    super.key,
    required this.attachments,
    required this.selectedIndex,
    required this.resolveBytes,
    required this.onSelect,
    required this.onAdd,
    required this.onRemoveRequested,
    required this.canAddMore,
  });

  final List<IdAttachment> attachments;
  final int selectedIndex;
  final Future<Uint8List> Function(IdAttachment) resolveBytes;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveRequested;
  final bool canAddMore;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final children = <Widget>[];

    for (int i = 0; i < attachments.length; i++) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 12.0));
      }
      children.add(
        _buildThumb(
          context,
          index: i,
          attachment: attachments[i],
          isActive: i == selectedIndex,
          brightness: brightness,
        ),
      );
    }

    if (canAddMore) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 12.0));
      }
      children.add(
        AttachmentAddTile(
          variant: AttachmentAddTileVariant.strip,
          onTap: onAdd,
        ),
      );
    }

    return SizedBox(
      height: 54.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildThumb(
    BuildContext context, {
    required int index,
    required IdAttachment attachment,
    required bool isActive,
    required Brightness brightness,
  }) {
    final accentColor = AppTheme.accentOf(brightness);

    final preview = SizedBox(
      width: 86.0,
      height: 54.0,
      child: AttachmentPreview(
        attachment: attachment,
        resolveBytes: resolveBytes,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
    );

    Widget content;
    if (isActive) {
      content = CustomPaint(
        painter: DashedRRectPainter(
          color: accentColor,
          borderRadius: AppTheme.radiusControl + 2.0,
          strokeWidth: 1.5,
          dashLength: 6.0,
          gapLength: 5.0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: preview,
        ),
      );
    } else {
      content = Opacity(
        opacity: 0.60,
        child: preview,
      );
    }

    return BounceTap(
      onTap: () => onSelect(index),
      onLongPress: () => onRemoveRequested(index),
      child: content,
    );
  }
}
