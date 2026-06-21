import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/sound/sound_service.dart';

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
  bool _dragging = false;

  // ValueNotifiers for tilt — updating them does NOT call setState, so the
  // card content widgets are never rebuilt during drag. Only the tiny tilt
  // AnimatedBuilder layer listens and repaints.
  final _tiltX = ValueNotifier<double>(0);
  final _tiltY = ValueNotifier<double>(0);

  // Combined notifier for the tilt AnimatedBuilder to listen to both axes.
  late final _tiltNotifier = Listenable.merge([_tiltX, _tiltY]);

  // Stable card faces — built once in initState so their RepaintBoundary
  // raster caches are never evicted by a rebuild of the parent.
  late final Widget _frontCard;
  late final Widget _backCard;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flipAnim =
        CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic);

    _frontCard = RepaintBoundary(
      child: _CardFront(document: widget.document),
    );
    _backCard = RepaintBoundary(
      child: _CardBack(document: widget.document),
    );
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
    HapticFeedback.mediumImpact();
    SoundService.flip();
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    _showBack = !_showBack;
  }

  void _onPanStart(DragStartDetails _) {
    _dragging = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    _dragging = true;
    // Write directly to notifiers — zero setState, zero widget rebuild.
    _tiltX.value = ((d.localPosition.dy / size.height) - 0.5).clamp(-0.5, 0.5);
    _tiltY.value = -((d.localPosition.dx / size.width) - 0.5).clamp(-0.5, 0.5);
  }

  void _onPanEnd(DragEndDetails _) {
    _tiltX.value = 0;
    _tiltY.value = 0;
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Credit-card ratio: width fills parent, height = width / 1.586.
    // build() is now only called on flip (AnimationController tick) —
    // tilt no longer triggers setState at all.
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
            // ── Outer AnimatedBuilder: driven by flip animation only ──────────
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (context, _) {
                final angle = _flipAnim.value * math.pi;
                final isBack = angle > math.pi / 2;
                final scale = 1.0 - 0.08 * math.sin(_flipAnim.value * math.pi);

                // Keep both faces laid out, but paint only the visible one.
                // This preserves their raster caches without compositing an
                // invisible, potentially expensive PAN face on every frame.
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
                    SizedBox.expand(
                      child: _frontCard,
                    ),
                  ],
                );

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scaleByDouble(scale, scale, 1.0, 1.0)
                    ..rotateY(angle),
                  // ── Inner AnimatedBuilder: driven by tilt notifiers only ───
                  // Only this Transform + shimmer overlay rebuilds on drag.
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
                            child!, // card faces — never rebuilt on tilt
                            // Shimmer overlay — the ONLY thing that repaints
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
                                      transform: _SlideGradient(_tiltY.value * 800),
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

// ── Front ─────────────────────────────────────────────────────────────────────

class _CardFront extends StatelessWidget {
  const _CardFront({required this.document});
  final IdDocument document;

  String _formatDate(String d) {
    if (d.contains('-')) {
      final p = d.split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final isPan = document.type == IdDocumentType.pan;
    if (!isPan) return _AadhaarFront(document: document);

    final String docNum = document.documentNumber.isEmpty
        ? 'ABCDE1234F'
        : document.documentNumber.toUpperCase();
    final String name = document.holderName.isEmpty
        ? 'RAHUL KUMAR'
        : document.holderName.toUpperCase();
    final String fatherName = document.fatherName.isEmpty
        ? 'SURESH KUMAR'
        : document.fatherName.toUpperCase();
    final String dob = document.dateOfBirth.isEmpty
        ? '15/08/1992'
        : _formatDate(document.dateOfBirth);

    const Color primaryText = Color(0xFF0F2C59);
    const Color labelText = Color(0xFF5A738E);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBF3FC), Color(0xFFD3E6F8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Center background watermark of Emblem of India
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.09,
                  child: RepaintBoundary(
                    child: _EmblemPng(size: _EmblemSize.watermark, color: primaryText),
                  ),
                ),
              ),
            ),
            // Holographic reflection overlay removed from here —
            // it is now a single shared layer in the parent Stack so that
            // SVG card content is never invalidated by tilt changes.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // ─── HEADER ROW ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'आयकर विभाग',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'INCOME TAX DEPARTMENT',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      // Center Logo
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            child: _EmblemPng(size: _EmblemSize.header, color: primaryText),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'सत्यमेव जयते',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      // Right Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            'भारत सरकार',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'GOVT. OF INDIA',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // ─── CONTENT ROW ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left details column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            const Text(
                              'नाम / Name',
                              style: TextStyle(color: labelText, fontSize: 7.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              name,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Father's Name
                            const Text(
                              'पिता का नाम / Father\'s Name',
                              style: TextStyle(color: labelText, fontSize: 7.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              fatherName,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // DOB
                            const Text(
                              'जन्म की तारीख / Date of Birth',
                              style: TextStyle(color: labelText, fontSize: 7.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              dob,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Permanent Account Number
                            const Text(
                              'स्थायी लेखा संख्या / Permanent Account Number',
                              style: TextStyle(color: labelText, fontSize: 7.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              docNum,
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFF1B3A6B),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right details column (Hologram + Vertical PAN Number)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Circular Hologram with Sweep Gradient
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const SweepGradient(
                                    colors: [
                                      Color(0xFFE2F0D9),
                                      Color(0xFFBDD7EE),
                                      Color(0xFFF8CBAD),
                                      Color(0xFFC5E0B4),
                                      Color(0xFFD6D6D6),
                                      Color(0xFFF2C2C2),
                                      Color(0xFFBDD7EE),
                                      Color(0xFFE2F0D9),
                                    ],
                                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFBDD7EE).withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: RepaintBoundary(
                                    child: _EmblemPng(
                                      size: _EmblemSize.hologram,
                                      color: const Color(0xCC0F2C59),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Vertical PAN Number
                              RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  docNum,
                                  style: TextStyle(
                                    color: primaryText.withValues(alpha: 0.45),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}

// ── Aadhaar front — official UIDAI card design ───────────────────────────────

class _AadhaarFront extends StatelessWidget {
  const _AadhaarFront({required this.document});
  final IdDocument document;

  String _formatDate(String d) {
    if (d.contains('-')) {
      final p = d.split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    }
    return d;
  }

  String get _formattedNumber {
    final n = document.documentNumber.replaceAll(' ', '');
    if (n.length == 12) {
      return '${n.substring(0, 4)} ${n.substring(4, 8)} ${n.substring(8, 12)}';
    }
    return document.documentNumber.isEmpty
        ? 'XXXX XXXX XXXX'
        : document.documentNumber;
  }

  String _genderHindi(String g) {
    final upper = g.toUpperCase();
    if (upper == 'MALE') return 'पुरुष';
    if (upper == 'FEMALE') return 'स्त्री';
    if (upper == 'OTHER') return 'अन्य';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    const Color cardBg = Color(0xFFFAF6F0);
    const Color ink = Color(0xFF1A1A1A);
    const Color headerInk = Color(0xFF2D2D2D);
    const Color labelColor = Color(0xFF666666);

    final String name = document.holderName.isEmpty
        ? 'HOLDER NAME'
        : document.holderName.toUpperCase();
    final String dob = document.dateOfBirth.isEmpty
        ? '15/08/1992'
        : _formatDate(document.dateOfBirth);
    final String gender =
        document.gender.isEmpty ? 'MALE' : document.gender.toUpperCase();
    final String genderHi = _genderHindi(gender);
    final String genderDisplay =
        genderHi.isNotEmpty ? '$genderHi / $gender' : gender;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0D8CE), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative green curves in the bottom-right
            Positioned.fill(
              child: CustomPaint(
                  painter: const _AadhaarGreenCurvesPainter()),
            ),

            // Decorative orange curves in the top-left
            Positioned.fill(
              child: CustomPaint(
                  painter: const _AadhaarOrangeCurvesPainter(mirrored: true)),
            ),

            // Subtle saffron wash — top-left area
            Positioned(
              left: -40,
              top: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF5A623).withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: Emblem | Sun Logo | UIDAI ──────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Emblem + Government of India
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RepaintBoundary(
                              child: _EmblemPng(
                                size: _EmblemSize.header,
                                color: headerInk,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'भारत सरकार',
                                    style: TextStyle(
                                      color: headerInk,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'GOVERNMENT OF INDIA',
                                    style: TextStyle(
                                      color: headerInk,
                                      fontSize: 5.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center: Aadhaar Sun Logo
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: SvgPicture.asset(
                              'assets/identity/Aadhaar.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // Right: UIDAI text
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'भारतीय विशिष्ट पहचान\nप्राधिकरण',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: headerInk,
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'UNIQUE IDENTIFICATION\nAUTHORITY OF INDIA',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: headerInk,
                                fontSize: 5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.15,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── Body: Photo + Details ──────────────────────────
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo placeholder
                        Container(
                          width: 68,
                          height: 82,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2DBD3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFCDC5BD),
                              width: 0.5,
                            ),
                          ),
                          child: _isBase64Image(document.imagePath)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    base64Decode(document.imagePath),
                                    fit: BoxFit.cover,
                                    width: 68,
                                    height: 82,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Color(0xFFAEA79F),
                                ),
                        ),

                        const SizedBox(width: 12),

                        // Personal details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Name
                              const Text(
                                'नाम / Name',
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Date of Birth
                              const Text(
                                'जन्म तिथि / Date of Birth',
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                dob,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Gender
                              const Text(
                                'लिंग / Gender',
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                genderDisplay,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Footer: Aadhaar Number + tricolor ─────────────
                  const Text(
                    'आधार संख्या / Aadhaar Number',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formattedNumber,
                              style: GoogleFonts.robotoMono(
                                color: ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Tricolor underline
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFDCD6CD),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      height: 2.5,
                                      width: 55,
                                      color: const Color(0xFFFF9933)),
                                  Container(
                                      height: 2.5,
                                      width: 55,
                                      color: const Color(0xFFFFFFFF)),
                                  Container(
                                      height: 2.5,
                                      width: 55,
                                      color: const Color(0xFF138808)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Tagline
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto',
                                ),
                                children: [
                                  TextSpan(text: 'मेरा '),
                                  TextSpan(
                                    text: 'आधार',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  TextSpan(text: ', मेरी पहचान'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Emblem hologram circle
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                Color(0xFFE2F0D9),
                                Color(0xFFBDD7EE),
                                Color(0xFFF8CBAD),
                                Color(0xFFC5E0B4),
                                Color(0xFFD6D6D6),
                                Color(0xFFF2C2C2),
                                Color(0xFFBDD7EE),
                                Color(0xFFE2F0D9),
                              ],
                              stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFBDD7EE).withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: RepaintBoundary(
                              child: _EmblemPng(
                                size: _EmblemSize.hologram,
                                color: const Color(0xCC0F2C59),
                              ),
                            ),
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

  static bool _isBase64Image(String s) =>
      s.length > 100 && !s.startsWith('/') && !s.contains('\\');
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.document});
  final IdDocument document;

  @override
  Widget build(BuildContext context) {
    final isPan = document.type == IdDocumentType.pan;
    if (isPan) {
      return _PanBack(document: document);
    }

    // Aadhaar back — matching front design language
    final String aadhaarNum = document.documentNumber.replaceAll(' ', '');
    final String formattedNum = aadhaarNum.length == 12
        ? '${aadhaarNum.substring(0, 4)} ${aadhaarNum.substring(4, 8)} ${aadhaarNum.substring(8, 12)}'
        : (document.documentNumber.isEmpty
            ? 'XXXX XXXX XXXX'
            : document.documentNumber);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFFAF6F0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0D8CE), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Emblem watermark
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.05,
                  child: RepaintBoundary(
                    child: _EmblemPng(
                      size: _EmblemSize.watermark,
                      color: const Color(0xFF557A2E),
                    ),
                  ),
                ),
              ),
            ),
            // Decorative green curves (mirrored for back)
            Positioned.fill(
              child: CustomPaint(
                painter: const _AadhaarGreenCurvesPainter(mirrored: true),
              ),
            ),
            // Decorative orange curves (not mirrored for back, so bottom-right)
            Positioned.fill(
              child: CustomPaint(
                painter: const _AadhaarOrangeCurvesPainter(mirrored: false),
              ),
            ),
            // Subtle saffron wash — top-right
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF5A623).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RepaintBoundary(
                        child: _EmblemPng(
                          size: _EmblemSize.header,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'भारतीय विशिष्ट पहचान प्राधिकरण',
                              style: TextStyle(
                                color: Color(0xFF2D2D2D),
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'UNIQUE IDENTIFICATION AUTHORITY OF INDIA',
                              style: TextStyle(
                                color: Color(0xFF2D2D2D),
                                fontSize: 5.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: SvgPicture.asset(
                          'assets/identity/Aadhaar.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Address
                  if (document.address.isNotEmpty) ...[
                    const Text(
                      'पता / Address',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 6.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      document.address,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Bottom row: Aadhaar number + photo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'आधार संख्या / Aadhaar Number',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 6.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedNum,
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFF1A1A1A),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Tricolor accent line
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFDCD6CD),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      height: 2,
                                      width: 40,
                                      color: const Color(0xFFFF9933)),
                                  Container(
                                      height: 2,
                                      width: 40,
                                      color: const Color(0xFFFFFFFF)),
                                  Container(
                                      height: 2,
                                      width: 40,
                                      color: const Color(0xFF138808)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Help: 1947  |  www.uidai.gov.in',
                              style: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 6.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isBase64Image(document.imagePath))
                        GestureDetector(
                          onTap: () =>
                              _showFullImage(context, document.imagePath),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFCDC5BD),
                                width: 0.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                base64Decode(document.imagePath),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
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

class _PanBack extends StatelessWidget {
  const _PanBack({required this.document});
  final IdDocument document;

  String _formatDate(String d) {
    if (d.contains('-')) {
      final p = d.split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final String docNum = document.documentNumber.isEmpty
        ? 'ABCDE1234F'
        : document.documentNumber.toUpperCase();
    final String name = document.holderName.isEmpty
        ? 'RAHUL KUMAR'
        : document.holderName.toUpperCase();
    final String fatherName = document.fatherName.isEmpty
        ? 'SURESH KUMAR'
        : document.fatherName.toUpperCase();
    final String dob = document.dateOfBirth.isEmpty
        ? '15/08/1992'
        : _formatDate(document.dateOfBirth);

    const Color primaryText = Color(0xFF0F2C59);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBF3FC), Color(0xFFD3E6F8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [

            // Layout content containing NSDL details & bottom frosted summary row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top section: NSDL Info & Bilingual lost-card instructions
                  const Text(
                    'यदि यह कार्ड खो जाता है तो कृपया इसे लौटाएं / सूचित करें:',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 6.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'आयकर पैन सेवा इकाई, एनएसडीएल ई-गवर्नेंस इंफ्रास्ट्रक्चर लिमिटेड, 5वीं मंजिल, मंतरी स्टर्लिंग, प्लॉट नं. 341, सर्वे नं. 997/8, मॉडल कॉलोनी, दीप बंगला चौक के पास, पुणे - 411 016',
                    style: TextStyle(
                      color: Color(0xFF5A738E),
                      fontSize: 6.0,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'If found or lost, please return / inform to:',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 6.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Income Tax PAN Services Unit, NSDL e-Governance Infrastructure Limited, 5th Floor, Mantri Sterling, Plot No. 341, Survey No. 997/8, Model Colony, Near Deep Bungalow Chowk, Pune - 411 016.',
                    style: TextStyle(
                      color: Color(0xFF5A738E),
                      fontSize: 6.0,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Contact details row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Expanded(
                              child: Text(
                                'Tel: +91-20-2721 8080, Fax: +91-20-2721 8081',
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 6.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Email: tininfo@nsdl.co.in',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 6.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Website: www.tin-nsdl.com or www.incometaxindia.gov.in',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 6.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Bottom Frosted Data Summary Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _BackDetailChip(label: 'PAN / स्थायी लेखा संख्या', value: docNum),
                        _BackDetailChip(label: 'NAME / नाम', value: name),
                        _BackDetailChip(label: 'FATHER\'S NAME / पिता का नाम', value: fatherName),
                        _BackDetailChip(label: 'DOB / जन्म तिथि', value: dob),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackDetailChip extends StatelessWidget {
  const _BackDetailChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5A738E),
                fontSize: 5.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F2C59),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

// ── Shared emblem widget ───────────────────────────────────────────────────────
// Uses pre-rasterized PNGs instead of the 437 KB SVG so there is zero
// parse cost. ColorFiltered applies the tint at GPU composition time.
enum _EmblemSize { watermark, header, hologram }

class _EmblemPng extends StatelessWidget {
  const _EmblemPng({required this.size, required this.color});
  final _EmblemSize size;
  final Color color;

  String get _asset {
    switch (size) {
      case _EmblemSize.watermark: return 'assets/identity/emblem_120.png';
      case _EmblemSize.header:    return 'assets/identity/emblem_34.png';
      case _EmblemSize.hologram:  return 'assets/identity/emblem_28.png';
    }
  }

  double get _height {
    switch (size) {
      case _EmblemSize.watermark: return 120;
      case _EmblemSize.header:    return 34;
      case _EmblemSize.hologram:  return 28;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(_asset, height: _height, fit: BoxFit.contain),
    );
  }
}

// ── Aadhaar-specific painters ─────────────────────────────────────────────────

/// Draws soft organic green curves matching the official Aadhaar card motif.
/// Set [mirrored] to true for the back card (curves from top-left).
class _AadhaarGreenCurvesPainter extends CustomPainter {
  const _AadhaarGreenCurvesPainter({this.mirrored = false});
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (mirrored) {
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.25),
        cp1: Offset(w * 0.3, h * 0.08),
        cp2: Offset(w * 0.55, h * 0.18),
        end: Offset(w * 0.75, 0),
        color: const Color(0x1C718B3D),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.40),
        cp1: Offset(w * 0.25, h * 0.15),
        cp2: Offset(w * 0.48, h * 0.25),
        end: Offset(w * 0.68, 0),
        color: const Color(0x14A4C264),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.52),
        cp1: Offset(w * 0.18, h * 0.25),
        cp2: Offset(w * 0.38, h * 0.32),
        end: Offset(w * 0.58, 0),
        color: const Color(0x10C5D99A),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(0, h * 0.15)
        ..cubicTo(w * 0.15, 0, w * 0.3, h * 0.05, w * 0.5, 0)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08718B3D)
          ..style = PaintingStyle.fill,
      );
    } else {
      _drawCurve(
        canvas,
        start: Offset(w * 0.35, h),
        cp1: Offset(w * 0.55, h * 0.65),
        cp2: Offset(w * 0.75, h * 0.80),
        end: Offset(w, h * 0.45),
        color: const Color(0x1C718B3D),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.45, h),
        cp1: Offset(w * 0.60, h * 0.72),
        cp2: Offset(w * 0.78, h * 0.85),
        end: Offset(w, h * 0.55),
        color: const Color(0x14A4C264),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.52, h),
        cp1: Offset(w * 0.66, h * 0.78),
        cp2: Offset(w * 0.84, h * 0.90),
        end: Offset(w, h * 0.65),
        color: const Color(0x10C5D99A),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(w * 0.6, h)
        ..cubicTo(w * 0.72, h * 0.82, w * 0.86, h * 0.88, w, h * 0.72)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08718B3D)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCurve(
    Canvas canvas, {
    required Offset start,
    required Offset cp1,
    required Offset cp2,
    required Offset end,
    required Color color,
    required double strokeWidth,
  }) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AadhaarGreenCurvesPainter old) =>
      old.mirrored != mirrored;
}

class _AadhaarOrangeCurvesPainter extends CustomPainter {
  const _AadhaarOrangeCurvesPainter({this.mirrored = false});
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (mirrored) {
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.25),
        cp1: Offset(w * 0.3, h * 0.08),
        cp2: Offset(w * 0.55, h * 0.18),
        end: Offset(w * 0.75, 0),
        color: const Color(0x1CF5A623),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.40),
        cp1: Offset(w * 0.25, h * 0.15),
        cp2: Offset(w * 0.48, h * 0.25),
        end: Offset(w * 0.68, 0),
        color: const Color(0x14FFAB40),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.52),
        cp1: Offset(w * 0.18, h * 0.25),
        cp2: Offset(w * 0.38, h * 0.32),
        end: Offset(w * 0.58, 0),
        color: const Color(0x10FFD180),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(0, h * 0.15)
        ..cubicTo(w * 0.15, 0, w * 0.3, h * 0.05, w * 0.5, 0)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08F5A623)
          ..style = PaintingStyle.fill,
      );
    } else {
      _drawCurve(
        canvas,
        start: Offset(w * 0.35, h),
        cp1: Offset(w * 0.55, h * 0.65),
        cp2: Offset(w * 0.75, h * 0.80),
        end: Offset(w, h * 0.45),
        color: const Color(0x1CF5A623),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.45, h),
        cp1: Offset(w * 0.60, h * 0.72),
        cp2: Offset(w * 0.78, h * 0.85),
        end: Offset(w, h * 0.55),
        color: const Color(0x14FFAB40),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.52, h),
        cp1: Offset(w * 0.66, h * 0.78),
        cp2: Offset(w * 0.84, h * 0.90),
        end: Offset(w, h * 0.65),
        color: const Color(0x10FFD180),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(w * 0.6, h)
        ..cubicTo(w * 0.72, h * 0.82, w * 0.86, h * 0.88, w, h * 0.72)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08F5A623)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCurve(
    Canvas canvas, {
    required Offset start,
    required Offset cp1,
    required Offset cp2,
    required Offset end,
    required Color color,
    required double strokeWidth,
  }) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AadhaarOrangeCurvesPainter old) =>
      old.mirrored != mirrored;
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
