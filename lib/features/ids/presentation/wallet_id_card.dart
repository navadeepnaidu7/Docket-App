import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/id_document.dart';

/// Horizontal wallet card for PAN and Aadhaar with 3D tilt + tap-flip.
class WalletIdCard extends StatefulWidget {
  const WalletIdCard({
    super.key,
    required this.document,
    this.onLongPress,
  });

  final IdDocument document;
  final VoidCallback? onLongPress;

  @override
  State<WalletIdCard> createState() => _WalletIdCardState();
}

class _WalletIdCardState extends State<WalletIdCard>
    with TickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _showBack = false;

  double _tiltX = 0;
  double _tiltY = 0;
  bool _touching = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flipAnim =
        CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_dragging) return;
    HapticFeedback.mediumImpact();
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    _showBack = !_showBack;
  }

  void _onPanStart(DragStartDetails _) =>
      setState(() { _touching = true; _dragging = false; });

  void _onPanUpdate(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    setState(() {
      _dragging = true;
      _tiltX = ((d.localPosition.dy / size.height) - 0.5).clamp(-0.5, 0.5);
      _tiltY = -((d.localPosition.dx / size.width) - 0.5).clamp(-0.5, 0.5);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() { _touching = false; _tiltX = 0; _tiltY = 0; });
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _dragging = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Credit-card ratio: width fills parent, height = width / 1.586
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth;
        final cardH = cardW / 1.586;
        return SizedBox(
          width: cardW,
          height: cardH,
          child: GestureDetector(
            onTap: _handleTap,
            onLongPress: () {
              HapticFeedback.heavyImpact();
              widget.onLongPress?.call();
            },
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (context, child) {
                final angle = _flipAnim.value * math.pi;
                final isBack = angle > math.pi / 2;
                final scale = 1.0 - 0.08 * math.sin(_flipAnim.value * math.pi);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scaleByDouble(scale, scale, 1.0, 1.0)
                    ..rotateY(angle),
                  child: AnimatedContainer(
                    duration: _touching
                        ? const Duration(milliseconds: 60)
                        : const Duration(milliseconds: 500),
                    curve: _touching ? Curves.linear : Curves.easeOutCubic,
                    transformAlignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateX(_tiltX * 0.14)
                      ..rotateY(_tiltY * 0.14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: isBack ? 1.0 : 0.0,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(math.pi),
                            child: _CardBack(document: widget.document),
                          ),
                        ),
                        Opacity(
                          opacity: isBack ? 0.0 : 1.0,
                          child: _CardFront(
                              document: widget.document, tiltY: _tiltY),
                        ),
                      ],
                    ),
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

// ── Front ─────────────────────────────────────────────────────────────────────

class _CardFront extends StatelessWidget {
  const _CardFront({required this.document, required this.tiltY});
  final IdDocument document;
  final double tiltY;

  @override
  Widget build(BuildContext context) {
    final isPan = document.type == IdDocumentType.pan;
    final colors = isPan
        ? const [Color(0xFF1C3252), Color(0xFF0D1F36)]
        : const [Color(0xFF003F87), Color(0xFF002255)];
    final accent =
        isPan ? const Color(0xFFC6973F) : const Color(0xFFFF6B00);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 16)),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Security pattern
            Positioned.fill(
                child: CustomPaint(
                    painter: _SecurityPainter(
                        isPan: isPan,
                        color: Colors.white.withValues(alpha: 0.04)))),
            // Shimmer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Colors.transparent,
                      Color(0x14FFFFFF),
                      Colors.transparent,
                    ],
                    transform: _SlideGradient(tiltY * 800),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPan
                              ? Icons.account_balance_rounded
                              : Icons.fingerprint_rounded,
                          color: accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPan
                                ? 'INCOME TAX INDIA'
                                : 'UNIQUE IDENTIFICATION AUTHORITY',
                            style: TextStyle(
                                color: accent,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            isPan ? 'PERMANENT ACCOUNT NUMBER' : 'आधार  AADHAAR',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Document number
                  Text(
                    document.documentNumber.isEmpty
                        ? (isPan ? 'XXXXX0000X' : 'XXXX XXXX XXXX')
                        : document.documentNumber,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isPan ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isPan ? 3.0 : 4.0,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NAME',
                              style: TextStyle(
                                  color: accent.withValues(alpha: 0.8),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              document.holderName.isEmpty
                                  ? 'HOLDER NAME'
                                  : document.holderName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      if (!isPan && document.dateOfBirth.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('DOB',
                                style: TextStyle(
                                    color: accent.withValues(alpha: 0.8),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(document.dateOfBirth),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                      Icon(Icons.credit_card_rounded,
                          color: Colors.white.withValues(alpha: 0.28), size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String d) {
    if (d.contains('-')) {
      final p = d.split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    }
    return d;
  }
}

// ── Back ──────────────────────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack({required this.document});
  final IdDocument document;

  @override
  Widget build(BuildContext context) {
    final isPan = document.type == IdDocumentType.pan;
    final colors = isPan
        ? const [Color(0xFF1C3252), Color(0xFF0D1F36)]
        : const [Color(0xFF003F87), Color(0xFF002255)];
    final accent =
        isPan ? const Color(0xFFC6973F) : const Color(0xFFFF6B00);

    final fields = isPan
        ? [
            ('PAN NUMBER', document.documentNumber),
            ('NAME', document.holderName),
            ('DATE OF BIRTH', _formatDate(document.dateOfBirth)),
            ("FATHER'S NAME", document.fatherName),
          ]
        : [
            ('AADHAAR NUMBER', document.documentNumber),
            ('NAME', document.holderName),
            ('DATE OF BIRTH', _formatDate(document.dateOfBirth)),
            ('GENDER', document.gender),
            ('ADDRESS', document.address),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: _SecurityPainter(
                        isPan: isPan,
                        color: Colors.white.withValues(alpha: 0.03)))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPan ? 'PAN CARD DETAILS' : 'AADHAAR DETAILS',
                    style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _FieldGrid(fields: fields),
                  ),
                  if (_isBase64Image(document.imagePath))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => _showFullImage(context, document.imagePath),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(document.imagePath),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String d) {
    if (d.isEmpty) return '';
    if (d.contains('-')) {
      final p = d.split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    }
    return d;
  }

  void _showFullImage(BuildContext context, String base64Image) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, a1, a2) => _FullImageViewer(base64Image: base64Image),
        transitionsBuilder: (ctx, anim, a2, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  /// Returns true only if the string looks like base64-encoded image data
  /// (not a file path like /data/user/...).
  static bool _isBase64Image(String s) =>
      s.length > 100 && !s.startsWith('/') && !s.contains('\\');
}

// ── Full-screen image viewer ──────────────────────────────────────────────────

class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.base64Image});
  final String base64Image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    base64Decode(base64Image),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fields});
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fields
          .where((f) => f.$2.isNotEmpty)
          .map((f) => _FieldChip(label: f.$1, value: f.$2))
          .toList(),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _SecurityPainter extends CustomPainter {
  const _SecurityPainter({required this.isPan, required this.color});
  final bool isPan;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    if (isPan) {
      // Ashoka Chakra-style concentric circles + spokes
      final center = Offset(size.width * 0.82, size.height * 0.4);
      for (double r = 12; r < 80; r += 10) {
        canvas.drawCircle(center, r, paint);
      }
      for (int i = 0; i < 24; i++) {
        final a = (i / 24) * 2 * math.pi;
        canvas.drawLine(center,
            Offset(center.dx + 75 * math.cos(a), center.dy + 75 * math.sin(a)),
            paint);
      }
    } else {
      // Abstract diagonal microprint lines
      for (double x = -size.height; x < size.width * 2; x += 8) {
        canvas.drawLine(
            Offset(x, 0), Offset(x + size.height * 0.7, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SecurityPainter old) =>
      old.color != color || old.isPan != isPan;
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
