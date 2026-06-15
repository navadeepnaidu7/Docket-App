import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ── Aadhaar front — light card matching UIDAI design ─────────────────────────

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
    if (n.length == 12) return '${n.substring(0,4)} ${n.substring(4,8)} ${n.substring(8,12)}';
    return document.documentNumber.isEmpty ? 'XXXX XXXX XXXX' : document.documentNumber;
  }

  @override
  Widget build(BuildContext context) {
    const Color bg       = Color(0xFFFAF8F5);
    const Color ink      = Color(0xFF0D1B2A);
    const Color uidaiRed = Color(0xFFD32F2F);
    const Color subInk   = Color(0xFF4A5568);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          // Fingerprint watermark
          Positioned(
            right: -20, bottom: -20,
            child: Opacity(
              opacity: 0.045,
              child: Icon(Icons.fingerprint_rounded, size: 200, color: uidaiRed),
            ),
          ),
          // Shimmer tilt overlay removed from here — now a shared layer
          // in the parent Stack so Aadhaar card content is never repainted
          // by tilt changes.

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header ──────────────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Emblem placeholder (fingerprint icon styled as emblem)
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E0), width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF2D3748)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('UNIQUE IDENTIFICATION AUTHORITY OF INDIA',
                        style: TextStyle(color: uidaiRed, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                    const SizedBox(height: 1),
                    Text('भारत सरकार   GOVERNMENT OF INDIA',
                        style: TextStyle(color: subInk, fontSize: 7.5, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                  ]),
                ),
                // Aadhaar logo area
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: uidaiRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: uidaiRed.withValues(alpha: 0.20), width: 0.5),
                    ),
                    child: const Text('AADHAAR', style: TextStyle(color: uidaiRed, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ]),
              ]),

              const SizedBox(height: 16),

              // ── Aadhaar number — hero ────────────────────────────────────
              Text(
                _formattedNumber,
                style: GoogleFonts.robotoMono(
                  color: ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),

              const SizedBox(height: 12),

              // ── Name ────────────────────────────────────────────────────
              Text(
                document.holderName.isEmpty ? 'Holder Name' : document.holderName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
              ),

              const SizedBox(height: 4),

              // ── DOB · Gender ─────────────────────────────────────────────
              Row(children: [
                if (document.dateOfBirth.isNotEmpty) ...[
                  Text(_formatDate(document.dateOfBirth), style: TextStyle(color: subInk, fontSize: 13, fontWeight: FontWeight.w400)),
                  if (document.gender.isNotEmpty) ...[
                    Text('  ·  ', style: TextStyle(color: subInk.withValues(alpha: 0.5), fontSize: 13)),
                    Text(document.gender, style: TextStyle(color: subInk, fontSize: 13, fontWeight: FontWeight.w400)),
                  ],
                ],
              ]),

              const Spacer(),

              // ── Footer ───────────────────────────────────────────────────
              Text('Tap to view details', style: TextStyle(color: ink.withValues(alpha: 0.25), fontSize: 10, fontWeight: FontWeight.w400)),
            ]),
          ),
        ]),
      ),
    );
  }
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

    final colors = const [Color(0xFF003F87), Color(0xFF002255)];
    final accent = const Color(0xFFFF6B00);

    final fields = [
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: _SecurityPainter(
                        isPan: false,
                        color: Colors.white.withValues(alpha: 0.03)))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AADHAAR DETAILS',
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

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
