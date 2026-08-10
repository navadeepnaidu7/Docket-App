import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/id_attachment.dart';
import 'attachment_preview.dart';

/// Horizontal PageView displaying the main attachment previews.
///
/// Off-center pages scale down to 0.92 scale and 60% opacity to keep focus
/// unambiguously on the current document.
class AttachmentHeroPager extends StatefulWidget {
  const AttachmentHeroPager({
    super.key,
    required this.attachments,
    required this.currentIndex,
    required this.resolveBytes,
    required this.onPageChanged,
    this.height = 216.0,
  });

  final List<IdAttachment> attachments;
  final int currentIndex;
  final Future<Uint8List> Function(IdAttachment) resolveBytes;
  final ValueChanged<int> onPageChanged;
  final double height;

  @override
  State<AttachmentHeroPager> createState() => _AttachmentHeroPagerState();
}

class _AttachmentHeroPagerState extends State<AttachmentHeroPager> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.currentIndex,
      viewportFraction: 0.90,
    );
  }

  @override
  void didUpdateWidget(covariant AttachmentHeroPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        _pageController.hasClients &&
        _pageController.page?.round() != widget.currentIndex) {
      _pageController.animateToPage(
        widget.currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) {
      return SizedBox(height: widget.height);
    }

    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.attachments.length,
        onPageChanged: (index) {
          HapticService.select();
          widget.onPageChanged(index);
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double pageOffset = index.toDouble();
              if (_pageController.position.haveDimensions) {
                pageOffset =
                    _pageController.page ?? _pageController.initialPage.toDouble();
              } else {
                pageOffset = widget.currentIndex.toDouble();
              }

              final double diff = (pageOffset - index).abs().clamp(0.0, 1.0);
              final double scale = 1.0 - (0.08 * diff); // 1.0 -> 0.92
              final double opacity = 1.0 - (0.40 * diff); // 1.0 -> 0.60

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: AttachmentPreview(
                      attachment: widget.attachments[index],
                      resolveBytes: widget.resolveBytes,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
