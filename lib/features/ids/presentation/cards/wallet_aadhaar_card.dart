import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/assets/app_assets.dart';
import '../../domain/id_document.dart';
import 'id_wallet_shared.dart';

/// Aadhaar card front face for the wallet carousel.
class AadhaarCardFront extends StatelessWidget {
  const AadhaarCardFront({super.key, required this.document});

  final IdDocument document;

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
        : formatIdDate(document.dateOfBirth);
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
                  painter: const AadhaarGreenCurvesPainter()),
            ),

            // Decorative orange curves in the top-left
            Positioned.fill(
              child: CustomPaint(
                  painter: const AadhaarOrangeCurvesPainter(mirrored: true)),
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
                              child: IdCardEmblemPng(
                                size: IdCardEmblemSize.header,
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
                              AppAssets.aadhaarLogo,
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
                          child: isBase64IdImage(document.imagePath)
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
                              child: IdCardEmblemPng(
                                size: IdCardEmblemSize.hologram,
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
}

/// Aadhaar card back face for the wallet carousel.
class AadhaarCardBack extends StatelessWidget {
  const AadhaarCardBack({super.key, required this.document});

  final IdDocument document;

  @override
  Widget build(BuildContext context) {
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
                    child: IdCardEmblemPng(
                      size: IdCardEmblemSize.watermark,
                      color: const Color(0xFF557A2E),
                    ),
                  ),
                ),
              ),
            ),
            // Decorative green curves (mirrored for back)
            Positioned.fill(
              child: CustomPaint(
                painter: const AadhaarGreenCurvesPainter(mirrored: true),
              ),
            ),
            // Decorative orange curves (not mirrored for back, so bottom-right)
            Positioned.fill(
              child: CustomPaint(
                painter: const AadhaarOrangeCurvesPainter(mirrored: false),
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
                        child: IdCardEmblemPng(
                          size: IdCardEmblemSize.header,
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
                          AppAssets.aadhaarLogo,
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
                      if (document.qrImageBase64.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFCDC5BD),
                              width: 0.5,
                            ),
                          ),
                          child: QrImageView(
                            data: document.qrImageBase64,
                            version: QrVersions.auto,
                            size: 52,
                            padding: EdgeInsets.zero,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        )
                      else if (isBase64IdImage(document.imagePath))
                        GestureDetector(
                          onTap: () =>
                              showIdCardFullImage(context, document.imagePath),
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
}
