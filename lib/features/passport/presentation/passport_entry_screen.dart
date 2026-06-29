import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/motion/entry_reveal.dart';
import '../../../core/sound/sound_service.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../../../shared/widgets/apple_sheet.dart';
import '../../../shared/widgets/completion_celebration.dart';
import '../../../shared/widgets/studio_field.dart';
import '../../mrz_scanner/domain/mrz_result.dart';
import '../../mrz_scanner/presentation/mrz_scanner_screen.dart';
import '../../nfc/presentation/nfc_scanner_sheet.dart' as import_nfc_sheet;
import '../../../core/validation/document_validators.dart';
import '../application/passport_draft_controller.dart';
import '../application/passport_list_provider.dart';
import '../domain/passport_profile.dart';

class PassportEntryScreen extends ConsumerStatefulWidget {
  const PassportEntryScreen({super.key});

  @override
  ConsumerState<PassportEntryScreen> createState() =>
      _PassportEntryScreenState();
}

class _PassportEntryScreenState extends ConsumerState<PassportEntryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _passportNumberController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _mrzController;
  int _modeIndex = 0;

  @override
  void initState() {
    super.initState();
    final PassportProfile profile = ref.read(passportDraftProvider);
    _nameController = TextEditingController(text: profile.name);
    _passportNumberController = TextEditingController(
      text: profile.passportNumber,
    );
    _nationalityController = TextEditingController(text: profile.nationality);
    _dateOfBirthController = TextEditingController(text: profile.dateOfBirth);
    _expiryDateController = TextEditingController(text: profile.expiryDate);
    _mrzController = TextEditingController(text: profile.mrzRaw);
    _modeIndex = profile.isEPassport ? 0 : 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passportNumberController.dispose();
    _nationalityController.dispose();
    _dateOfBirthController.dispose();
    _expiryDateController.dispose();
    _mrzController.dispose();
    super.dispose();
  }

  void _syncDraft() {
    final PassportDraftController controller = ref.read(
      passportDraftProvider.notifier,
    );
    controller
      ..updateName(_nameController.text)
      ..updatePassportNumber(_passportNumberController.text)
      ..updateNationality(_nationalityController.text)
      ..updateDateOfBirth(_dateOfBirthController.text)
      ..updateExpiryDate(_expiryDateController.text)
      ..updateMrzRaw(_mrzController.text)
      ..updateIsEPassport(_modeIndex == 0);
  }

  Future<void> _openCameraScanner() async {
    final result = await Navigator.of(context).push<MrzResult>(
      MaterialPageRoute<MrzResult>(builder: (_) => const MrzScannerScreen()),
    );
    if (result == null || !mounted) return;

    // Populate all text controllers from scan result
    _nameController.text = result.displayName;
    _passportNumberController.text = result.passportNumber;
    _nationalityController.text = result.nationality;
    _dateOfBirthController.text = result.dateOfBirth;
    _expiryDateController.text = result.expiryDate;

    // Sync to draft + save image path
    _syncDraft();
    if (result.capturedImagePath.isNotEmpty) {
      ref.read(passportDraftProvider.notifier).updateImagePath(result.capturedImagePath);
    }

    // Brief success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Fields filled from scan — please review'),
          ]),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _startNfcScan() async {
    _syncDraft();

    // Validate dates before attempting NFC (bad dates cause hard BAC failures)
    final dateError = DocumentValidators.validatePassportDates(
      dateOfBirth: _dateOfBirthController.text,
      expiryDate: _expiryDateController.text,
    );
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.warning_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Cannot scan NFC: $dateError')),
          ]),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    // Passport needs to be YYMMDD for BAC
    final dobParts = _dateOfBirthController.text.split('-');
    final expParts = _expiryDateController.text.split('-');
    
    String dobFormatted = _dateOfBirthController.text;
    String expFormatted = _expiryDateController.text;
    
    if (dobParts.length == 3) dobFormatted = "${dobParts[0].substring(2)}${dobParts[1]}${dobParts[2]}";
    if (expParts.length == 3) expFormatted = "${expParts[0].substring(2)}${expParts[1]}${expParts[2]}";

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: import_nfc_sheet.NfcScannerSheet(
          passportNumber: _passportNumberController.text,
          dateOfBirth: dobFormatted,
          expiryDate: expFormatted,
        ),
      ),
    );

    if (result != null) {
      if (!mounted) return;
      // 1 & 3: Raw Output Debug Dialog so you can see exactly what came from the chip
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          final photoValue = result['photoBase64']?.toString() ?? '';
          final hasImage = photoValue.isNotEmpty;
          final debugData = Map<String, dynamic>.from(result);
          if (hasImage) {
             debugData['photoBase64'] = '[IMAGE RETRIEVED! Base64 String length: ${photoValue.length}]';
          } else {
             debugData['photoBase64'] = '[NO IMAGE FOUND OR DECODE FAILED]';
          }

          return AlertDialog(
            title: const Text('NFC Chip Data (Raw)', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: SelectableText(
                debugData.entries.map((e) => '${e.key}:\n${e.value}').join('\n\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Details'),
              )
            ],
          );
        }
      );

      // Update fields from NFC data
      setState(() {
        if (result['firstName'] != null) {
          _nameController.text = "${result['firstName']} ${result['lastName'] ?? ''}".trim();
        }
        if (result['nationality'] != null) _nationalityController.text = result['nationality'];
        if (result['documentNumber'] != null) _passportNumberController.text = result['documentNumber'];
      });
      _syncDraft();
      
      final draftNotifier = ref.read(passportDraftProvider.notifier);
      if (result['photoBase64'] != null) {
         draftNotifier.updateImagePath(result['photoBase64']);
      }
      
      // Update new fields if they exist
      final updatedProfile = ref.read(passportDraftProvider).copyWith(
        gender: result['gender']?.toString(),
        placeOfBirth: result['dg11_placeOfBirth']?.toString(),
        issueDate: result['dg12_dateOfIssue']?.toString(),
        issuingAuthority: result['dg12_issuingAuthority']?.toString(),
      );
      draftNotifier.replaceWith(updatedProfile);
      
      // We keep it as e-passport since we just NFC scanned it.
      draftNotifier.updateIsEPassport(true);
    }
  }

  void _saveDraft() {
    _syncDraft();

    final profile = ref.read(passportDraftProvider);

    // Require at least a name or passport number before saving
    if (profile.name.trim().isEmpty && profile.passportNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Please fill in at least your name or passport number.'),
          ]),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Date validation (DOB + future expiry)
    final dateError = DocumentValidators.validatePassportDates(
      dateOfBirth: profile.dateOfBirth,
      expiryDate: profile.expiryDate,
    );
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.warning_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(dateError)),
          ]),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    HapticService.success();
    SoundService.success();
    // Save to global list for Dashboard
    ref.read(passportListProvider.notifier).addPassport(profile);

    showWalletSaveCelebration(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Capture studio',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CircleButton(icon: Icons.check_rounded, onTap: _saveDraft),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          const _StudioBackdrop(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 30),
              children: <Widget>[
                const SizedBox(height: 18),
                EntryReveal(
                  child: _modeIndex == 0
                      ? _EPassportPanel(
                          key: const ValueKey<String>('epassport'),
                          nameController: _nameController,
                          nationalityController: _nationalityController,
                          passportNumberController: _passportNumberController,
                          dateOfBirthController: _dateOfBirthController,
                          expiryDateController: _expiryDateController,
                          onChanged: _syncDraft,
                          onScanNfc: _startNfcScan,
                          onScanCamera: _openCameraScanner,
                        )
                      : _RegularPassportPanel(
                          key: const ValueKey<String>('regular'),
                          nameController: _nameController,
                          passportNumberController: _passportNumberController,
                          nationalityController: _nationalityController,
                          dateOfBirthController: _dateOfBirthController,
                          expiryDateController: _expiryDateController,
                          mrzController: _mrzController,
                          onChanged: _syncDraft,
                          onScanCamera: _openCameraScanner,
                        ),
                ),
                const SizedBox(height: 18),
                EntryReveal(
                  delay: const Duration(milliseconds: 80),
                  child: _SaveButton(onTap: _saveDraft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioBackdrop extends StatelessWidget {
  const _StudioBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Color> colors = isDark
        ? const <Color>[
            Color(0xFF080E1A),
            Color(0xFF0F1829),
            Color(0xFF0A0F1D),
          ]
        : const <Color>[
            Color(0xFFEFF4F9),
            Color(0xFFF8FAFC),
            Color(0xFFEDE7DD),
          ];

    final Color lineColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0x1207111F);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: SizedBox.expand(child: CustomPaint(painter: _StudioPainter(lineColor: lineColor))),
    );
  }
}

class _StudioPainter extends CustomPainter {
  const _StudioPainter({required this.lineColor});
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 12; i++) {
      final double top = 86 + i * 34;
      final Rect rect = Rect.fromLTWH(
        18 + i * 3,
        top,
        size.width - 36 - i * 6,
        22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StudioPainter oldDelegate) => oldDelegate.lineColor != lineColor;
}

class _EPassportPanel extends StatelessWidget {
  const _EPassportPanel({
    super.key,
    required this.nameController,
    required this.nationalityController,
    required this.passportNumberController,
    required this.dateOfBirthController,
    required this.expiryDateController,
    required this.onChanged,
    required this.onScanNfc,
    required this.onScanCamera,
  });

  final TextEditingController nameController;
  final TextEditingController nationalityController;
  final TextEditingController passportNumberController;
  final TextEditingController dateOfBirthController;
  final TextEditingController expiryDateController;
  final VoidCallback onChanged;
  final VoidCallback onScanNfc;
  final VoidCallback onScanCamera;

  Future<void> _selectDate(BuildContext context, TextEditingController controller, {bool isDob = false, bool isExpiry = false}) async {
    DateTime initDate = DateTime(2000);
    if (controller.text.isNotEmpty) {
      try {
        initDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final now = DateTime.now();
    DateTime minDate = DateTime(1900);
    DateTime maxDate = DateTime(2100);

    if (isDob) {
      minDate = DateTime(1900);
      maxDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    } else if (isExpiry) {
      minDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      maxDate = DateTime(now.year + 20, now.month, now.day);
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AppleSheet(
          title: 'Select Date',
          showDragHandle: true,
          child: SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: isDark ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    fontSize: 20,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initDate,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (DateTime newDate) {
                  controller.text = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
                  onChanged();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: <Widget>[
          // Camera scan button
          _ScanPassportButton(onTap: onScanCamera),
          const _OrDivider(),
          const Padding(
            padding: EdgeInsets.only(bottom: 16, top: 4),
            child: Text(
              'Enter your details below, then tap Verify Identity to scan your E-Passport chip.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ),
          StudioField(
            controller: nameController,
            label: 'Full name',
            icon: Icons.person_rounded,
            onChanged: onChanged,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: StudioField(
                  controller: nationalityController,
                  label: 'Nationality',
                  icon: Icons.flag_rounded,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudioField(
                  controller: passportNumberController,
                  label: 'Passport No.',
                  icon: Icons.confirmation_number_rounded,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: StudioField(
                  controller: dateOfBirthController,
                  label: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context, dateOfBirthController, isDob: true),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudioField(
                  controller: expiryDateController,
                  label: 'Expiry date',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.event_available_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context, expiryDateController, isExpiry: true),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onScanNfc,
              icon: const Icon(Icons.nfc_rounded, color: Colors.white),
              label: const Text(
                'Verify Identity (NFC)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegularPassportPanel extends StatelessWidget {
  const _RegularPassportPanel({
    super.key,
    required this.nameController,
    required this.passportNumberController,
    required this.nationalityController,
    required this.dateOfBirthController,
    required this.expiryDateController,
    required this.mrzController,
    required this.onChanged,
    required this.onScanCamera,
  });

  final TextEditingController nameController;
  final TextEditingController passportNumberController;
  final TextEditingController nationalityController;
  final TextEditingController dateOfBirthController;
  final TextEditingController expiryDateController;
  final TextEditingController mrzController;
  final VoidCallback onChanged;
  final VoidCallback onScanCamera;

  Future<void> _selectDate(BuildContext context, TextEditingController controller, {bool isDob = false, bool isExpiry = false}) async {
    DateTime initDate = DateTime(2000);
    if (controller.text.isNotEmpty) {
      try {
        initDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final now = DateTime.now();
    DateTime minDate = DateTime(1900);
    DateTime maxDate = DateTime(2100);

    if (isDob) {
      minDate = DateTime(1900);
      maxDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    } else if (isExpiry) {
      minDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      maxDate = DateTime(now.year + 20, now.month, now.day);
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AppleSheet(
          title: 'Select Date',
          showDragHandle: true,
          child: SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: isDark ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    fontSize: 20,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initDate,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (DateTime newDate) {
                  controller.text = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
                  onChanged();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: <Widget>[
          _ScanPassportButton(onTap: onScanCamera),
          const _OrDivider(),
          StudioField(
            controller: nameController,
            label: 'Full name',
            icon: Icons.person_rounded,
            onChanged: onChanged,
          ),
          StudioField(
            controller: passportNumberController,
            label: 'Passport number',
            icon: Icons.confirmation_number_rounded,
            onChanged: onChanged,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: StudioField(
                  controller: nationalityController,
                  label: 'Nationality',
                  icon: Icons.flag_rounded,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudioField(
                  controller: dateOfBirthController,
                  label: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context, dateOfBirthController, isDob: true),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          StudioField(
            controller: expiryDateController,
            label: 'Expiry date',
            hintText: 'YYYY-MM-DD',
            icon: Icons.event_available_rounded,
            readOnly: true,
            onTap: () => _selectDate(context, expiryDateController, isExpiry: true),
            onChanged: onChanged,
          ),
          StudioField(
            controller: mrzController,
            label: 'MRZ raw text',
            icon: Icons.subject_rounded,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.40),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color buttonColor = isDark ? theme.colorScheme.primary : const Color(0xFF07111F);
    final Color shadowColor = isDark ? theme.colorScheme.primary.withValues(alpha: 0.22) : const Color(0xFF07111F).withValues(alpha: 0.22);

    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.save_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Save draft',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BounceTap(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
              ),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : const Color(0xFF07111F),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Camera Scan Button ────────────────────────────────────────────────────────

class _ScanPassportButton extends StatelessWidget {
  const _ScanPassportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Gradient gradient = isDark
        ? LinearGradient(
            colors: <Color>[
              theme.colorScheme.primary.withValues(alpha: 0.9),
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
          )
        : const LinearGradient(
            colors: <Color>[Color(0xFF1A1A2E), Color(0xFF16213E)],
          );

    final Color shadowColor = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.20)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.25);

    return BounceTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Scan Passport',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  'Auto-fill from camera',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── "or enter manually" divider ───────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color lineColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final Color textColor = isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: lineColor, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or enter manually',
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Divider(color: lineColor, thickness: 1)),
        ],
      ),
    );
  }
}
