import 'dart:convert';
import 'dart:math' as math;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../passport/domain/passport_profile.dart';

/// Portrait-style Indian Passport card with 3D tilt & single-tap flip.
class WalletPassportCard extends StatefulWidget {
  const WalletPassportCard({
    super.key,
    required this.profile,
    this.onLongPress,
  });

  final PassportProfile profile;
  final VoidCallback? onLongPress;

  @override
  State<WalletPassportCard> createState() => _WalletPassportCardState();
}

class _WalletPassportCardState extends State<WalletPassportCard>
    with TickerProviderStateMixin {
  // -- flip --
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _showBack = false;

  // -- tilt --
  double _tiltX = 0;
  double _tiltY = 0;
  bool _touching = false;
  bool _dragging = false;


  // -- tap glow pulse --
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipCtrl,
      curve: Curves.easeInOutCubic,
    );


    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _flipCtrl.dispose();

    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_dragging) return;
    HapticFeedback.mediumImpact();
    _pulseCtrl.forward(from: 0);
    if (_showBack) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    _showBack = !_showBack;
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _touching = true;
      _dragging = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size size = box.size;
    setState(() {
      _dragging = true;
      _tiltX = ((d.localPosition.dy / size.height) - 0.5).clamp(-0.5, 0.5);
      _tiltY = -((d.localPosition.dx / size.width) - 0.5).clamp(-0.5, 0.5);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() {
      _touching = false;
      _tiltX = 0;
      _tiltY = 0;
    });
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _dragging = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const double cardHeight = 570.0;

    return SizedBox(
      height: cardHeight,
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleTap();
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onLongPress?.call();
        },
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (context, _) {
                final double angle = _flipAnim.value * math.pi;
                final bool isBack = angle > math.pi / 2;

                // Add a smooth scale-down effect at the middle of the flip (angle = pi/2)
                final double scale = 1.0 - 0.08 * math.sin(_flipAnim.value * math.pi);

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
                        // Back (rotated to face away)
                        Opacity(
                          opacity: isBack ? 1.0 : 0.0,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(math.pi),
                            child: RepaintBoundary(
                              child: _CardBack(
                                profile: widget.profile,
                                tiltY: _tiltY,
                              ),
                            ),
                          ),
                        ),
                        // Front
                        Opacity(
                          opacity: isBack ? 0.0 : 1.0,
                          child: RepaintBoundary(
                            child: _CardFront(
                              profile: widget.profile,
                              tiltY: _tiltY,
                              pulseCtrl: _pulseCtrl,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

// ─── FRONT SIDE ──────────────────────────────────────────────────────────────

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.profile,
    required this.tiltY,
    required this.pulseCtrl,
  });

  final PassportProfile profile;
  final double tiltY;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    final String name =
        profile.name.trim().isEmpty ? 'HOLDER NAME' : profile.name.toUpperCase();
    final String number = profile.passportNumber.trim().isEmpty
        ? 'A 1234567'
        : profile.passportNumber;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.28),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          // Subtle glow mimicking gloss
          BoxShadow(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
            blurRadius: 1,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Stack(
          children: <Widget>[
            // — base gradient (rich navy matching Indian passport) —
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF1E3163),
                    Color(0xFF152347),
                    Color(0xFF0F1A38),
                  ],
                ),
              ),
            ),

            // — Ashoka Chakra watermark background —
            const Positioned.fill(child: CustomPaint(painter: _AshokaPainter())),

            // — subtle security pattern lines —
            const Positioned.fill(child: CustomPaint(painter: _SecurityLinePainter())),

            // — shimmer overlay —
            // — dynamic interactive shimmer —
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const <Color>[
                      Colors.transparent,
                      Color(0x18FFFFFF),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.5, 1.0],
                    transform: _SlideGradient(tiltY * 1200),
                  ),
                ),
              ),
            ),

            // — tricolor top strip —
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 6,
                child: Row(
                  children: <Widget>[
                    Expanded(child: Container(color: const Color(0xFFFF9933))),
                    Expanded(child: Container(color: Colors.white)),
                    Expanded(child: Container(color: const Color(0xFF138808))),
                  ],
                ),
              ),
            ),

            // — main content —
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 6), // tricolor strip
                // top header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 0),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: SvgPicture.asset(
                          'assets/identity/Emblem_of_India.svg',
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFD4A843),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          Text(
                            'REPUBLIC OF INDIA',
                            style: TextStyle(
                              color: Color(0xFFD4A843),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'PASSPORT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (profile.isEPassport) const _EPassportSymbol(),
                    ],
                  ),
                ),

                const Spacer(),

                // — central emblem oval —
                _EmblemOval(),

                const Spacer(),

                // — bottom details —
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'NAME',
                              style: TextStyle(
                                color: const Color(0xFFD4A843).withValues(alpha: 0.95),
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'PASSPORT NO.',
                              style: TextStyle(
                                color: const Color(0xFFD4A843).withValues(alpha: 0.95),
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              number,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // — tap-to-flip indicator —
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.credit_card_rounded,
                        color: Colors.white.withValues(alpha: 0.30),
                        size: 13,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BACK SIDE ───────────────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack({required this.profile, required this.tiltY});

  final PassportProfile profile;
  final double tiltY;

  String _generateMRZ(PassportProfile profile) {
    if (profile.mrzRaw.trim().isNotEmpty) return profile.mrzRaw;

    int calcCheckDigit(String str) {
      const weights = [7, 3, 1];
      int sum = 0;
      for (int i = 0; i < str.length; i++) {
        int val;
        final char = str[i];
        if (char == '<') {
          val = 0;
        } else if (char.codeUnitAt(0) >= '0'.codeUnitAt(0) && char.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
          val = int.parse(char);
        } else {
          val = char.codeUnitAt(0) - 'A'.codeUnitAt(0) + 10;
        }
        sum += val * weights[i % 3];
      }
      return sum % 10;
    }

    final country = profile.nationality.isEmpty ? 'IND' : profile.nationality.padRight(3, '<').substring(0, 3).toUpperCase();
    
    final nameParts = profile.name.trim().isEmpty ? ['HOLDER', 'NAME'] : profile.name.toUpperCase().split(' ');
    String nameField;
    if (nameParts.length > 1) {
      final surname = nameParts.last;
      final givenNames = nameParts.sublist(0, nameParts.length - 1).join('<');
      nameField = '$surname<<$givenNames';
    } else {
      nameField = nameParts.first;
    }
    nameField = nameField.padRight(39, '<').substring(0, 39);
    final line1 = 'P<$country$nameField';

    final passNo = profile.passportNumber.isEmpty ? 'A1234567' : profile.passportNumber.padRight(9, '<').substring(0, 9).toUpperCase();
    final passCheck = calcCheckDigit(passNo);
    
    String formatYYMMDD(String date) {
      if (date.isEmpty) return '<<<<<<';
      try {
        if (date.length == 6 && int.tryParse(date) != null) return date;
        final parts = date.split(' ');
        if (parts.length == 3) {
          final d = parts[0].padLeft(2, '0');
          const months = {'JAN':'01','FEB':'02','MAR':'03','APR':'04','MAY':'05','JUN':'06','JUL':'07','AUG':'08','SEP':'09','OCT':'10','NOV':'11','DEC':'12'};
          final m = months[parts[1].toUpperCase().substring(0, 3)] ?? '01';
          final y = parts[2].substring(parts[2].length - 2);
          return '$y$m$d';
        }
      } catch (_) {}
      return '000000';
    }
    
    final dob = formatYYMMDD(profile.dateOfBirth);
    final dobCheck = calcCheckDigit(dob);
    
    final sex = profile.gender.toUpperCase().startsWith('F') ? 'F' : (profile.gender.toUpperCase().startsWith('M') ? 'M' : '<');
    
    final exp = formatYYMMDD(profile.expiryDate);
    final expCheck = calcCheckDigit(exp);
    
    final personalNo = '<<<<<<<<<<<<<<';
    final personalCheck = calcCheckDigit(personalNo);
    
    final composite = '$passNo$passCheck$dob$dobCheck$exp$expCheck$personalNo$personalCheck';
    final compositeCheck = calcCheckDigit(composite);
    
    final line2 = '$passNo$passCheck$country$dob$dobCheck$sex$exp$expCheck$personalNo$personalCheck$compositeCheck';
    
    return '$line1\n$line2';
  }

  @override
  Widget build(BuildContext context) {
    String formatNiceDate(String date) {
      if (date.isEmpty) return 'N/A';
      try {
        if (date.contains('-')) {
          final parts = date.split('-');
          if (parts.length == 3) {
            final y = parts[0];
            final mInt = int.parse(parts[1]);
            final d = int.parse(parts[2]).toString();
            const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
            final m = (mInt >= 1 && mInt <= 12) ? months[mInt - 1] : parts[1];
            return '$y $m $d';
          }
        }

        if (date.length == 8 && !date.contains(' ')) {
          final y = date.substring(0, 4);
          final mStr = date.substring(4, 6);
          final dStr = date.substring(6, 8);
          final mInt = int.parse(mStr);
          const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
          final m = (mInt >= 1 && mInt <= 12) ? months[mInt - 1] : mStr;
          final d = int.parse(dStr).toString();
          return '$y $m $d';
        }
        
        if (date.length == 6 && !date.contains(' ')) {
          final yy = int.parse(date.substring(0, 2));
          final y = (yy > 50 ? 1900 + yy : 2000 + yy).toString();
          final mStr = date.substring(2, 4);
          final dStr = date.substring(4, 6);
          final mInt = int.parse(mStr);
          const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
          final m = (mInt >= 1 && mInt <= 12) ? months[mInt - 1] : mStr;
          final d = int.parse(dStr).toString();
          return '$y $m $d';
        }

        final parts = date.split(' ');
        if (parts.length == 3) {
          final d = int.parse(parts[0]).toString();
          const months = {'JAN':'January','FEB':'February','MAR':'March','APR':'April','MAY':'May','JUN':'June','JUL':'July','AUG':'August','SEP':'September','OCT':'October','NOV':'November','DEC':'December'};
          final m = months[parts[1].toUpperCase().substring(0, 3)] ?? parts[1];
          final y = parts[2];
          return '$y $m $d';
        }
      } catch (_) {}
      return date;
    }

    final String fullName = profile.name.trim().isEmpty ? 'NAVADEEP NAIDU GUDI' : profile.name.toUpperCase();
    final String dob = profile.dateOfBirth.isEmpty ? '2005 August 10' : formatNiceDate(profile.dateOfBirth);
    final String expiry = profile.expiryDate.isEmpty ? '2035 October 27' : formatNiceDate(profile.expiryDate);
    final String gender = profile.gender.isEmpty ? 'MALE' : profile.gender.toUpperCase();
    final String nationality = profile.nationality.isEmpty ? 'IND' : profile.nationality.toUpperCase();
    final String placeOfBirth = profile.placeOfBirth.isEmpty ? 'PARIGI, TELANGANA' : profile.placeOfBirth;
    final String issueDate = profile.issueDate.isEmpty ? '2025 October 28' : formatNiceDate(profile.issueDate);
    final String issuingAuthority = profile.issuingAuthority.isEmpty ? 'Regional Passport Office, Hyderabad' : profile.issuingAuthority;
    final String passNum = profile.passportNumber.isEmpty ? 'A1234567' : profile.passportNumber.toUpperCase();
        
    final String mrz = _generateMRZ(profile);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3163), Color(0xFF152347), Color(0xFF0F1A38)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.28),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Stack(
          children: <Widget>[
            // Watermarks
            Positioned.fill(child: CustomPaint(painter: _AshokaPainter(color: Colors.white.withValues(alpha: 0.05)))),
            Positioned.fill(child: CustomPaint(painter: _SecurityLinePainter(color: Colors.white.withValues(alpha: 0.02)))),

            // Tricolor top strip
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 4,
                child: Row(
                  children: <Widget>[
                    Expanded(child: Container(color: const Color(0xFFFF9933))),
                    Expanded(child: Container(color: Colors.white)),
                    Expanded(child: Container(color: const Color(0xFF138808))),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: <Widget>[
                  // Emblem & Header
                  if (nationality == 'IND')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/identity/Emblem_of_India.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFFD4A843),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'REPUBLIC OF INDIA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Profile Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo
                      Container(
                        width: 100,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: profile.imagePath.isNotEmpty
                              ? Image.memory(
                                  base64Decode(profile.imagePath),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 130,
                                )
                              : Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Colors.grey.shade400,
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name and Badges
                      Expanded(
                        child: SizedBox(
                          height: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    passNum,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                      letterSpacing: 3.0,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Builder(
                                    builder: (context) {
                                      String getFlagEmoji(String countryCode) {
                                        if (countryCode.isEmpty) return '🛂';
                                        const alpha3To2 = {
                                          'IND': 'IN', 'USA': 'US', 'GBR': 'GB', 'CAN': 'CA', 'AUS': 'AU', 
                                          'DEU': 'DE', 'FRA': 'FR', 'JPN': 'JP', 'CHN': 'CN', 'BRA': 'BR',
                                        };
                                        final alpha2 = countryCode.length == 3 
                                            ? (alpha3To2[countryCode.toUpperCase()] ?? countryCode.substring(0, 2)) 
                                            : countryCode.toUpperCase();
                                        
                                        if (alpha2.length < 2) return '🛂';
                                        try {
                                          final first = alpha2.codeUnitAt(0) - 0x41 + 0x1F1E6;
                                          final second = alpha2.codeUnitAt(1) - 0x41 + 0x1F1E6;
                                          return String.fromCharCodes([first, second]);
                                        } catch (_) {
                                          return '🛂';
                                        }
                                      }
                                      return Text(
                                        getFlagEmoji(nationality),
                                        style: const TextStyle(fontSize: 28),
                                      );
                                    }
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Badge(icon: Icons.person_outline, text: gender),
                                  _Badge(icon: Icons.calendar_today_outlined, text: dob),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Detail Blocks
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DetailBlock(
                          label: 'DATE OF ISSUE',
                          value: issueDate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DetailBlock(
                          label: 'DATE OF EXPIRY',
                          value: expiry,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _DetailBlock(
                          label: 'PLACE OF BIRTH',
                          value: placeOfBirth,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: _DetailBlock(
                          label: 'NATIONALITY',
                          value: nationality,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DetailBlock(
                    label: 'ISSUING AUTHORITY',
                    value: issuingAuthority,
                  ),
                  
                  const Spacer(),
                  
                  // MRZ Zone
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MACHINE READABLE ZONE',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          mrz,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                            height: 1.8,
                          ),
                        ),
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

// ─── SUB-WIDGETS ─────────────────────────────────────────────────────────────

class _EmblemOval extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SvgPicture.asset(
        'assets/identity/Emblem_of_India.svg',
        width: 140,
        height: 140,
        colorFilter: const ColorFilter.mode(
          Color(0xFFD4A843),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _EPassportSymbol extends StatelessWidget {
  const _EPassportSymbol();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 20),
      painter: _EPassportSymbolPainter(),
    );
  }
}

class _EPassportSymbolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFD4A843)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Outer rectangle
    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, paint);

    // Circle in the middle
    final double circleRadius = size.height * 0.22;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      circleRadius,
      paint,
    );

    // Left line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width / 2 - circleRadius, size.height / 2),
      paint,
    );

    // Right line
    canvas.drawLine(
      Offset(size.width / 2 + circleRadius, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text, this.darkTheme = true});
  final IconData icon;
  final String text;
  final bool darkTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: darkTheme ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: darkTheme ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: darkTheme ? Colors.white70 : const Color(0xFF14244B).withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: darkTheme ? Colors.white : const Color(0xFF14244B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value, this.darkTheme = true});
  final String label;
  final String value;
  final bool darkTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: darkTheme ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: darkTheme ? Colors.white60 : const Color(0xFF14244B).withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: darkTheme ? Colors.white : const Color(0xFF14244B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAINTERS ────────────────────────────────────────────────────────────────

class _AshokaPainter extends CustomPainter {
  const _AshokaPainter({this.color});
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color ?? Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Bottom-right position matching the reference passport
    final Offset center = Offset(size.width * 0.78, size.height * 0.62);
    for (double r = 20; r < 200; r += 18) {
      canvas.drawCircle(center, r, paint);
    }
    for (int i = 0; i < 24; i++) {
      final double angle = (i / 24) * 2 * math.pi;
      canvas.drawLine(
        center,
        Offset(
          center.dx + 190 * math.cos(angle),
          center.dy + 190 * math.sin(angle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SecurityLinePainter extends CustomPainter {
  const _SecurityLinePainter({this.color});
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    // Horizontal brushed-fabric texture matching the real passport cover
    final Paint paint = Paint()
      ..color = color ?? Colors.white.withValues(alpha: 0.028)
      ..strokeWidth = 0.7;

    for (double y = 0; y < size.height; y += 3.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}
