import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/id_attachment.dart';

/// Opens a full-screen zoomable viewer for image attachments.
Future<void> showAttachmentFullScreen(
  BuildContext context, {
  required IdAttachment attachment,
  required Future<Uint8List> Function(IdAttachment) resolveBytes,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      pageBuilder: (ctx, a1, a2) => AttachmentFullScreenViewer(
        attachment: attachment,
        resolveBytes: resolveBytes,
      ),
      transitionsBuilder: (ctx, anim, a2, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 220),
    ),
  );
}

/// Presentation overlay for viewing an image attachment with interactive zoom and pan.
class AttachmentFullScreenViewer extends StatefulWidget {
  const AttachmentFullScreenViewer({
    super.key,
    required this.attachment,
    required this.resolveBytes,
  });

  final IdAttachment attachment;
  final Future<Uint8List> Function(IdAttachment) resolveBytes;

  @override
  State<AttachmentFullScreenViewer> createState() =>
      _AttachmentFullScreenViewerState();
}

class _AttachmentFullScreenViewerState extends State<AttachmentFullScreenViewer>
    with SingleTickerProviderStateMixin {
  late final Future<Uint8List?> _bytesFuture;
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    // Resolve bytes once on initialization to avoid re-decrypting on every frame.
    _bytesFuture = _loadBytes();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  Future<Uint8List?> _loadBytes() async {
    try {
      final bytes = await widget.resolveBytes(widget.attachment);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    final Matrix4 currentMatrix = _transformationController.value;
    final bool isZoomed = !currentMatrix.isIdentity();

    final Matrix4 endMatrix;
    if (isZoomed) {
      endMatrix = Matrix4.identity();
    } else {
      // Zoom about the tapped point: translate it to the origin, scale, and the
      // combined matrix leaves that point where the finger was.
      const double zoom = 2.5;
      final Offset position = _doubleTapDetails?.localPosition ?? Offset.zero;
      endMatrix = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (zoom - 1),
          -position.dy * (zoom - 1),
          0.0,
          1.0,
        )
        ..scaleByDouble(zoom, zoom, 1.0, 1.0);
    }

    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: endMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          // Backdrop tap dismisses viewer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),

          // Main image content with zoom & double-tap support
          Positioned.fill(
            child: FutureBuilder<Uint8List?>(
              future: _bytesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.accentOf(brightness),
                      ),
                    ),
                  );
                }

                final bytes = snapshot.data;
                if (snapshot.hasError || bytes == null || bytes.isEmpty) {
                  final inkColor = AppTheme.ink(brightness);
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: inkColor.withValues(alpha: 0.40),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load attachment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: inkColor.withValues(alpha: 0.50),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        // Prevent tap on image from bubbling up to backdrop dismiss
                      },
                      onDoubleTapDown: _handleDoubleTapDown,
                      onDoubleTap: _handleDoubleTap,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          final inkColor = AppTheme.ink(brightness);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: inkColor.withValues(alpha: 0.40),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Unable to load attachment',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: inkColor.withValues(alpha: 0.50),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Close affordance button at top-left
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: BounceTap(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
