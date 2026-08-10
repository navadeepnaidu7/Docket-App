import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/id_attachment.dart';
import 'attachment_add_tile.dart';
import 'attachment_preview.dart';

/// Horizontal row of attachment thumbnails with smooth scroll positioning and implicit animations.
class AttachmentThumbStrip extends StatefulWidget {
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
  State<AttachmentThumbStrip> createState() => _AttachmentThumbStripState();
}

class _AttachmentThumbStripState extends State<AttachmentThumbStrip> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToSelected();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AttachmentThumbStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToSelected();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calculates scroll offset to center the selected thumbnail within the viewport.
  void _scrollToSelected() {
    if (!_controller.hasClients) return;
    final double viewportWidth = _controller.position.viewportDimension;
    // Geometry: thumb width 86 + gap 12 = 98pt pitch.
    final double itemLeft = widget.selectedIndex * 98.0;
    const double thumbWidth = 86.0;
    final double targetOffset = (itemLeft + (thumbWidth / 2.0) - (viewportWidth / 2.0)).clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final children = <Widget>[];

    for (int i = 0; i < widget.attachments.length; i++) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 12.0));
      }
      children.add(
        _buildThumb(
          context,
          index: i,
          attachment: widget.attachments[i],
          isActive: i == widget.selectedIndex,
          brightness: brightness,
        ),
      );
    }

    if (widget.canAddMore) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 12.0));
      }
      children.add(
        AttachmentAddTile(
          variant: AttachmentAddTileVariant.strip,
          onTap: widget.onAdd,
        ),
      );
    }

    return SizedBox(
      height: 58.0,
      child: SingleChildScrollView(
        controller: _controller,
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
        resolveBytes: widget.resolveBytes,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
    );

    final content = AnimatedScale(
      scale: isActive ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl + 2.0),
            border: Border.all(
              color: isActive ? accentColor : Colors.transparent,
              width: 2.0,
            ),
          ),
          child: preview,
        ),
      ),
    );

    return BounceTap(
      onTap: () => widget.onSelect(index),
      onLongPress: () => widget.onRemoveRequested(index),
      child: content,
    );
  }
}
