import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../shared/widgets/card_touch_layer.dart';

import '../domain/id_document.dart';
import 'cards/id_card_registry.dart';
import 'cards/id_wallet_shared.dart';

/// Horizontal wallet shell for ID documents with 3D tilt + tap-flip.
/// Card faces are resolved per document type via [IdCardRegistry].
class WalletIdCard extends StatefulWidget {
  const WalletIdCard({
    super.key,
    required this.document,
    this.onLongPress,
    this.backdropTilt,
  });

  final IdDocument document;
  final VoidCallback? onLongPress;
  final WalletBackdropTilt? backdropTilt;

  @override
  State<WalletIdCard> createState() => _WalletIdCardState();
}

class _WalletIdCardState extends State<WalletIdCard>
    with TickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _showBack = false;
  bool _dragging = false;

  final _tiltX = ValueNotifier<double>(0);
  final _tiltY = ValueNotifier<double>(0);
  late final _tiltNotifier = Listenable.merge([_tiltX, _tiltY]);

  late Widget _frontCard;
  late Widget _backCard;

  void _rebuildFaces() {
    _frontCard = RepaintBoundary(
      child: IdCardRegistry.buildFront(widget.document),
    );
    _backCard = RepaintBoundary(
      child: IdCardRegistry.buildBack(widget.document),
    );
  }

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnim =
        CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic);
    _rebuildFaces();
  }

  @override
  void didUpdateWidget(covariant WalletIdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.document.type != widget.document.type) {
      _rebuildFaces();
      if (_showBack) {
        _flipCtrl.reset();
        _showBack = false;
      }
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _tiltX.dispose();
    _tiltY.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_dragging) return;
    HapticService.flip();
    SoundService.flip();
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    _showBack = !_showBack;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Honour both axes: deriving height from width alone produced cards
        // taller than the viewport in landscape and on short screens.
        final Size card = WalletCardMetrics.resolve(
          constraints,
          WalletCardMetrics.idAspect,
        );
        final double cardW = card.width;
        final double cardH = card.height;

        return SizedBox(
          width: cardW,
          height: cardH,
          child: CardTouchLayer(
            tiltX: _tiltX,
            tiltY: _tiltY,
            backdropTilt: widget.backdropTilt,
            onTap: _handleTap,
            onDragStateChanged: (bool dragging) => _dragging = dragging,
            onLongPress: widget.onLongPress == null
                ? null
                : () {
                    HapticService.longPress();
                    SoundService.longPress();
                    widget.onLongPress!();
                  },
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (context, _) {
                final angle = _flipAnim.value * math.pi;
                final isBack = angle > math.pi / 2;
                final scale = 1.0 - 0.08 * math.sin(_flipAnim.value * math.pi);

                final facesStack = IndexedStack(
                  index: isBack ? 0 : 1,
                  sizing: StackFit.expand,
                  children: [
                    SizedBox.expand(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _backCard,
                      ),
                    ),
                    SizedBox.expand(child: _frontCard),
                  ],
                );

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scaleByDouble(scale, scale, 1.0, 1.0)
                    ..rotateY(angle),
                  child: AnimatedBuilder(
                    animation: _tiltNotifier,
                    builder: (context, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(_tiltX.value * 0.14)
                          ..rotateY(_tiltY.value * 0.14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            child!,
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: const [
                                        Colors.transparent,
                                        Color(0x14FFFFFF),
                                        Colors.transparent,
                                      ],
                                      transform:
                                          IdCardSlideGradient(_tiltY.value * 800),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: facesStack,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}