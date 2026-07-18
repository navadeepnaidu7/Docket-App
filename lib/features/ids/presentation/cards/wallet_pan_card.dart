import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/id_document.dart';
import 'id_wallet_shared.dart';

/// PAN card front face for the wallet carousel.
class PanCardFront extends StatelessWidget {
  const PanCardFront({super.key, required this.document});

  final IdDocument document;

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
        : formatIdDate(document.dateOfBirth);

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
                    child: IdCardEmblemPng(size: IdCardEmblemSize.watermark, color: primaryText),
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
                            child: IdCardEmblemPng(size: IdCardEmblemSize.header, color: primaryText),
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
                      if (isBase64IdImage(document.imagePath)) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 52,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFB0C4DE),
                                  width: 0.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  base64Decode(document.imagePath),
                                  fit: BoxFit.cover,
                                  width: 52,
                                  height: 64,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 52,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFFB0C4DE),
                                  style: BorderStyle.solid,
                                  width: 0.5,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'SIGNATURE',
                                  style: TextStyle(
                                    fontSize: 5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0x7F0F2C59),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],
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
                                    child: IdCardEmblemPng(
                                      size: IdCardEmblemSize.hologram,
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

/// PAN card back face for the wallet carousel.
class PanCardBack extends StatelessWidget {
  const PanCardBack({super.key, required this.document});

  final IdDocument document;

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
        : formatIdDate(document.dateOfBirth);

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
                  const SizedBox(height: 4),
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

                  // Contact details and QR code row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
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
                      ),
                      if (document.qrImageBase64.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 0.5,
                            ),
                          ),
                          child: QrImageView(
                            data: document.qrImageBase64,
                            version: QrVersions.auto,
                            size: 32,
                            padding: EdgeInsets.zero,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F2C59),
                            ),
                          ),
                        ),
                      ],
                    ],
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
                        PanBackDetailChip(label: 'PAN / स्थायी लेखा संख्या', value: docNum),
                        PanBackDetailChip(label: 'NAME / नाम', value: name),
                        PanBackDetailChip(label: 'FATHER\'S NAME / पिता का नाम', value: fatherName),
                        PanBackDetailChip(label: 'DOB / जन्म तिथि', value: dob),
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

class PanBackDetailChip extends StatelessWidget {
  const PanBackDetailChip({super.key, required this.label, required this.value});
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
