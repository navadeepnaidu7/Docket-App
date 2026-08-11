import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/id_attachment.dart';
import 'attachment_add_tile.dart';
import 'attachment_hero_pager.dart';
import 'attachment_thumb_strip.dart';
import 'attachment_tray_state.dart';

/// Complete presentation shell for an ID card's media attachments.
///
/// Composes hint caption, hero preview (or empty-state add tile), page counter,
/// thumbnail strip, and swipe hint. Holds no attachment state and performs no I/O,
/// owning only the current active page index.
class IdAttachmentTray extends StatefulWidget {
  const IdAttachmentTray({
    super.key,
    required this.attachments,
    required this.resolveBytes,
    required this.onAdd,
    required this.onRemoveRequested,
    required this.onOpenRequested,
    required this.canAddMore,
  });

  final List<IdAttachment> attachments;
  final Future<Uint8List> Function(IdAttachment) resolveBytes;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveRequested;
  final ValueChanged<int> onOpenRequested;
  final bool canAddMore;

  @override
  State<IdAttachmentTray> createState() => _IdAttachmentTrayState();
}

class _IdAttachmentTrayState extends State<IdAttachmentTray> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant IdAttachmentTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachments.isEmpty) {
      _currentPage = 0;
    } else if (_currentPage >= widget.attachments.length) {
      _currentPage = widget.attachments.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final tertiaryStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppTheme.ink(brightness).withValues(
        alpha: brightness == Brightness.dark ? 0.52 : 0.40,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final count = widget.attachments.length;
        final heroHeight = AttachmentTrayLayout.heroHeight(
          availableHeight: availableHeight,
          attachmentCount: count,
        );

        final showCounter = AttachmentTrayLayout.shouldShowCounter(count);
        final showSwipeHint = AttachmentTrayLayout.shouldShowSwipeHint(
          attachmentCount: count,
          availableHeight: availableHeight,
        );

        final safePageIndex =
            count == 0 ? 0 : _currentPage.clamp(0, count - 1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hint caption
            Text(
              'You can add images or PDFs',
              style: tertiaryStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Hero preview or empty state add tile
            if (count == 0)
              AttachmentAddTile(
                variant: AttachmentAddTileVariant.hero,
                onTap: widget.onAdd,
                height: heroHeight,
              )
            else
              AttachmentHeroPager(
                attachments: widget.attachments,
                currentIndex: safePageIndex,
                resolveBytes: widget.resolveBytes,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                onOpenRequested: widget.onOpenRequested,
                height: heroHeight,
              ),

            // Counter (only when count > 1)
            if (showCounter) ...[
              const SizedBox(height: 12),
              Text(
                '${safePageIndex + 1} of $count',
                style: tertiaryStyle,
              ),
            ],

            // Strip (only when attachments exist)
            if (count > 0) ...[
              const SizedBox(height: 12),
              AttachmentThumbStrip(
                attachments: widget.attachments,
                selectedIndex: safePageIndex,
                resolveBytes: widget.resolveBytes,
                onSelect: (index) {
                  setState(() => _currentPage = index);
                },
                onAdd: widget.onAdd,
                onRemoveRequested: widget.onRemoveRequested,
                canAddMore: widget.canAddMore,
              ),
            ],

            // Swipe hint (only when count > 1 and height allows)
            if (showSwipeHint) ...[
              const SizedBox(height: 14),
              Text(
                'Swipe to see more',
                style: tertiaryStyle,
              ),
            ],
          ],
        );
      },
    );
  }
}
