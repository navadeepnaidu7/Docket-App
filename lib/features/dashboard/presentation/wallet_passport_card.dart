import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../shared/widgets/card_touch_layer.dart';
import '../../../shared/widgets/safe_base64_image.dart';

import '../../passport/domain/passport_profile.dart';

/// Shown in place of a field the holder never filled in.
const String _absent = '—';

bool _isIndianNationality(String raw) {
  final String v = raw.trim().toUpperCase();
  return v == 'IND' || v == 'INDIAN' || v == 'INDIA';
}

/// Display-only split. Storage stays a single [PassportProfile.name]; the
/// last token is treated as the surname, matching [_CardBack._generateMRZ].
({String surname, String given}) _splitHolderName(String raw) {
  final List<String> parts = raw
      .trim()
      .toUpperCase()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return (surname: _absent, given: _absent);
  if (parts.length == 1) return (surname: parts.first, given: _absent);
  return (
    surname: parts.last,
    given: parts.sublist(0, parts.length - 1).join(' '),
  );
}

String _formatPageDate(String raw) {
  final String v = raw.trim();
  if (v.isEmpty) return _absent;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
    final List<String> p = v.split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }
  if (RegExp(r'^\d{8}$').hasMatch(v)) {
    return '${v.substring(6, 8)}/${v.substring(4, 6)}/${v.substring(0, 4)}';
  }
  if (RegExp(r'^\d{6}$').hasMatch(v)) {
    final int yy = int.parse(v.substring(0, 2));
    final int year = yy > 50 ? 1900 + yy : 2000 + yy;
    return '${v.substring(4, 6)}/${v.substring(2, 4)}/$year';
  }
  if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(v)) return v;
  return v;
}

String _formatSex(String raw) {
  final String v = raw.trim().toUpperCase();
  if (v.isEmpty) return _absent;
  if (v.startsWith('F')) return 'F';
  if (v.startsWith('M')) return 'M';
  if (v.startsWith('X') || v == 'OTHER') return 'X';
  return v;
}

String _formatNationality(String raw) {
  if (raw.trim().isEmpty) return _absent;
  if (_isIndianNationality(raw)) return 'INDIAN';
  return raw.trim().toUpperCase();
}

String _formatIssuingCode(String raw) {
  if (_isIndianNationality(raw)) return 'IND';
  final String v = raw.trim().toUpperCase();
  if (v.length >= 3) return v.substring(0, 3);
  return _absent;
}

/// Portrait-style Indian Passport card with 3D tilt & single-tap flip.
class WalletPassportCard extends StatefulWidget {
  const WalletPassportCard({
    super.key,
    required this.profile,
    this.onLongPress,
    this.backdropTilt,
  });

  final PassportProfile profile;
  final VoidCallback? onLongPress;
  final WalletBackdropTilt? backdropTilt;

  /// Kicks off Noto Sans Devanagari so `main()`'s `pendingFonts()` wait covers
  /// the Hindi cover titles. Inter is already warmed by the app theme.
  static void warmUp() {
    _PassportCover.warmUp();
    _PassportPage.warmUp();
  }

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
  final _tiltX = ValueNotifier<double>(0);
  final _tiltY = ValueNotifier<double>(0);
  late final Listenable _tiltNotifier = Listenable.merge([_tiltX, _tiltY]);
  bool _dragging = false;

  late Widget _frontCard;
  late Widget _backCard;

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

    _rebuildFaces();
  }

  /// Faces are authored against a fixed canvas and scaled to the card box.
  void _rebuildFaces() {
    _frontCard = RepaintBoundary(
      child: WalletCardCanvas(
        designSize: WalletCardMetrics.passportCanvas,
        child: _CardFront(profile: widget.profile),
      ),
    );
    _backCard = RepaintBoundary(
      child: WalletCardCanvas(
        designSize: WalletCardMetrics.passportCanvas,
        child: _CardBack(profile: widget.profile),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant WalletPassportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _rebuildFaces();
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
      builder: (BuildContext context, BoxConstraints constraints) {
        // Was a hardcoded 570dp tall, full-width box — taller than an iPhone
        // SE's entire screen and a different shape on every device. Now the
        // booklet ratio is fixed and the box fits whatever space it is given.
        final Size card = WalletCardMetrics.resolve(
          constraints,
          WalletCardMetrics.passportAspect,
        );

        return SizedBox(
          height: card.height,
          width: card.width,
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
                  child: AnimatedBuilder(
                    animation: _tiltNotifier,
                    builder: (context, child) => Transform(
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  _PassportCover.radius,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment(
                                        -0.45 + _tiltY.value * 0.4,
                                        -0.72 + _tiltX.value * 0.25,
                                      ),
                                      radius: 1.2,
                                      colors: const <Color>[
                                        Color(0x12FFFFFF),
                                        Color(0x00FFFFFF),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: IndexedStack(
                      index: isBack ? 0 : 1,
                      sizing: StackFit.expand,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: _backCard,
                        ),
                        _frontCard,
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

// ─── FRONT SIDE ──────────────────────────────────────────────────────────────
//
// 2021 / 2024 Indian passport cover lockup. Positions are card-local on the
// 382 x 570 canvas, scaled from the 400 x 568 Commons artboards. The cream
// data page on the reverse uses [_PassportPage], not these foil tokens.

abstract final class _PassportCover {
  static const Color navy = Color(0xFF070930);
  static const Color navyLift = Color(0xFF12184A);
  static const Color navyShade = Color(0xFF04061C);
  static const Color gold = Color(0xFFF4CA81);
  static const double radius = 40;

  static TextStyle hindi(double size) => GoogleFonts.notoSansDevanagari(
        color: gold,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: 0.2,
      );

  static TextStyle latin(double size) => GoogleFonts.inter(
        color: gold,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.05,
      );

  static void warmUp() {
    hindi(28);
    latin(20);
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.profile});

  final PassportProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_PassportCover.radius),
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
        borderRadius: BorderRadius.circular(_PassportCover.radius),
        child: Stack(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    _PassportCover.navyLift,
                    _PassportCover.navy,
                    _PassportCover.navyShade,
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _SecurityLinePainter()),
            ),
            Positioned(
              top: 68,
              left: 16,
              right: 16,
              child: Column(
                children: <Widget>[
                  Text(
                    'भारत गणराज्य',
                    textAlign: TextAlign.center,
                    style: _PassportCover.hindi(28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'REPUBLIC OF INDIA',
                    textAlign: TextAlign.center,
                    style: _PassportCover.latin(20),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 178,
              left: 0,
              right: 0,
              child: _CoverEmblem(),
            ),
            Positioned(
              top: 360,
              left: 16,
              right: 16,
              child: Text(
                'सत्यमेव जयते',
                textAlign: TextAlign.center,
                style: _PassportCover.hindi(16),
              ),
            ),
            Positioned(
              top: 430,
              left: 16,
              right: 16,
              child: Column(
                children: <Widget>[
                  Text(
                    'पासपोर्ट',
                    textAlign: TextAlign.center,
                    style: _PassportCover.hindi(28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PASSPORT',
                    textAlign: TextAlign.center,
                    style: _PassportCover.latin(20),
                  ),
                ],
              ),
            ),
            if (profile.isEPassport)
              const Positioned(
                key: Key('e-passport-chip'),
                top: 516,
                left: 0,
                right: 0,
                child: Center(child: _EPassportSymbol()),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── BACK SIDE ───────────────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack({required this.profile});

  final PassportProfile profile;

  /// Builds the two MRZ lines from the stored fields, or returns `''` when
  /// there is not enough real data to build them from.
  ///
  /// The synthesised lines used to substitute `HOLDER<<NAME`, `IND` and
  /// `A1234567` for whatever was missing, which produced a well-formed,
  /// check-digit-correct MRZ for a passport that does not exist. An empty
  /// return hides the zone instead.
  String _generateMRZ(PassportProfile profile) {
    if (profile.mrzRaw.trim().isNotEmpty) return profile.mrzRaw;
    if (profile.name.trim().isEmpty || profile.passportNumber.trim().isEmpty) {
      return '';
    }

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

    final country = profile.nationality.trim().isEmpty
        ? '<<<'
        : profile.nationality.padRight(3, '<').substring(0, 3).toUpperCase();

    final nameParts = profile.name.toUpperCase().split(' ');
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

    final passNo =
        profile.passportNumber.padRight(9, '<').substring(0, 9).toUpperCase();
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
    // A document wallet must never show identity data the holder did not give
    // it. Missing reads as missing — never a sample stranger.
    String orAbsent(String v) => v.trim().isEmpty ? _absent : v.trim();

    final ({String surname, String given}) names = _splitHolderName(profile.name);
    final String dob = _formatPageDate(profile.dateOfBirth);
    final String expiry = _formatPageDate(profile.expiryDate);
    final String issueDate = _formatPageDate(profile.issueDate);
    final String sex = _formatSex(profile.gender);
    final String placeOfBirth = orAbsent(profile.placeOfBirth.toUpperCase());
    final String placeOfIssue = orAbsent(profile.issuingAuthority.toUpperCase());
    final String passNum = orAbsent(profile.passportNumber.toUpperCase());
    final String nationality = _formatNationality(profile.nationality);
    final String code = _formatIssuingCode(profile.nationality);
    final String mrz = _generateMRZ(profile);
    final bool hasPortrait = profile.photoBase64.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_PassportPage.radius),
        color: _PassportPage.paper,
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
        borderRadius: BorderRadius.circular(_PassportPage.radius),
        child: Stack(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFFFBF8F0),
                    _PassportPage.paper,
                    Color(0xFFEFE8D8),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              right: -36,
              top: 120,
              child: Opacity(
                opacity: 0.07,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    _PassportPage.wash,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    AppAssets.passportEmblemWatermark,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SecurityLinePainter(
                  color: _PassportPage.ink.withValues(alpha: 0.035),
                ),
              ),
            ),
            if (hasPortrait)
              Positioned(
                right: 18,
                top: 228,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.16,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF5A9BB0),
                        BlendMode.srcATop,
                      ),
                      child: SafeBase64Image(
                        base64: profile.photoBase64,
                        width: 92,
                        height: 118,
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: _PageHeader(isEPassport: profile.isEPassport),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: _PassportPage.rule, width: 0.7),
                      ),
                    ),
                    child: SizedBox(width: double.infinity, height: 0),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Expanded(
                        child: _PageField(
                          label: 'Type',
                          value: 'P',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PageField(
                          label: 'Code',
                          value: code,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _PageField(
                          label: 'Nationality',
                          value: nationality,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _PageField(
                          label: 'Passport No.',
                          value: passNum,
                          mono: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _PagePhoto(base64: profile.photoBase64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            _PageField(
                              label: 'Surname',
                              value: names.surname,
                            ),
                            const SizedBox(height: 12),
                            _PageField(
                              label: 'Given Names',
                              value: names.given,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  flex: 3,
                                  child: _PageField(
                                    label: 'Date of Birth',
                                    value: dob,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PageField(
                                    label: 'Sex',
                                    value: sex,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _PageField(
                              label: 'Place of Birth',
                              value: placeOfBirth,
                            ),
                            const SizedBox(height: 12),
                            _PageField(
                              label: 'Place of Issue',
                              value: placeOfIssue,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _PageField(
                                    label: 'Date of Issue',
                                    value: issueDate,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PageField(
                                    label: 'Date of Expiry',
                                    value: expiry,
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
                const Spacer(),
                if (mrz.isNotEmpty) _PageMrz(mrz: mrz) else const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SUB-WIDGETS ─────────────────────────────────────────────────────────────

abstract final class _PassportPage {
  static const Color paper = Color(0xFFF6F2E8);
  static const Color paperShade = Color(0xFFEBE4D4);
  static const Color ink = Color(0xFF1A2744);
  static const Color label = Color(0xFF2C4F5C);
  static const Color rule = Color(0xFFC5D0D4);
  static const Color wash = Color(0xFF7AA3B0);
  static const double radius = 40;

  static TextStyle labelStyle() => GoogleFonts.inter(
        color: label,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        height: 1.15,
      );

  static TextStyle value({bool mono = false}) {
    if (mono) {
      return GoogleFonts.robotoMono(
        color: ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 1.2,
      );
    }
    return GoogleFonts.inter(
      color: ink,
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
  }

  static void warmUp() {
    labelStyle();
    value();
    value(mono: true);
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isEPassport});

  final bool isEPassport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            _PassportPage.ink,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            AppAssets.passportEmblemStandard,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'REPUBLIC OF INDIA',
            style: GoogleFonts.inter(
              color: _PassportPage.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              height: 1.1,
            ),
          ),
        ),
        if (isEPassport) const _EPassportSymbol(),
      ],
    );
  }
}

class _PageField extends StatelessWidget {
  const _PageField({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _PassportPage.labelStyle(),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _PassportPage.value(mono: mono),
        ),
        const SizedBox(height: 5),
        const ColoredBox(
          color: _PassportPage.rule,
          child: SizedBox(width: double.infinity, height: 0.8),
        ),
      ],
    );
  }
}

class _PagePhoto extends StatelessWidget {
  const _PagePhoto({required this.base64});

  final String base64;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 144,
      decoration: BoxDecoration(
        color: _PassportPage.paperShade,
        border: Border.all(color: _PassportPage.rule, width: 0.8),
      ),
      // Portrait is chip DG2 base64 only. imagePath is the captured data page
      // and must never be decoded as a photo.
      child: SafeBase64Image(
        base64: base64,
        width: 112,
        height: 144,
        placeholder: const ColoredBox(
          color: _PassportPage.paperShade,
          child: Center(
            child: Icon(
              Icons.person_rounded,
              color: Color(0xFFB7AFA0),
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageMrz extends StatelessWidget {
  const _PageMrz({required this.mrz});

  final String mrz;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _PassportPage.paperShade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            mrz,
            maxLines: 2,
            style: GoogleFonts.robotoMono(
              color: _PassportPage.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.55,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverEmblem extends StatelessWidget {
  const _CoverEmblem();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(
          _PassportCover.gold,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          AppAssets.passportEmblemLarge,
          width: 176,
          height: 176,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _EPassportSymbol extends StatelessWidget {
  const _EPassportSymbol();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(42, 26),
      painter: _EPassportSymbolPainter(),
    );
  }
}

class _EPassportSymbolPainter extends CustomPainter {
  const _EPassportSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint foil = Paint()
      ..color = _PassportCover.gold
      ..style = PaintingStyle.fill;
    final Paint punch = Paint()
      ..color = _PassportCover.navy
      ..style = PaintingStyle.fill;

    final double barH = size.height * 0.36;
    final double gap = size.height - barH * 2;
    const Radius barRadius = Radius.circular(1.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, barH),
        barRadius,
      ),
      foil,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barH + gap, size.width, barH),
        barRadius,
      ),
      foil,
    );

    final Offset centre = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(centre, size.height * 0.38, punch);
    canvas.drawCircle(centre, size.height * 0.20, foil);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── PAINTERS ────────────────────────────────────────────────────────────────
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


