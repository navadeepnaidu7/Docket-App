import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/entry_reveal.dart';
import '../../../core/sound/sound_service.dart';
import '../../mrz_scanner/domain/mrz_result.dart';
import '../../mrz_scanner/presentation/mrz_scanner_screen.dart';
import '../../nfc/presentation/nfc_scanner_sheet.dart' as import_nfc_sheet;
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

    HapticFeedback.heavyImpact();
    SoundService.success();
    // Save to global list for Dashboard
    ref.read(passportListProvider.notifier).addPassport(profile);

    // Show full screen success overlay
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) => const _SuccessOverlay(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );

    // Give it a brief moment to show the updated sheet safely, then pop both the overlay and screen.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // pop success overlay
        Navigator.of(context).pop(); // pop entry screen back to dashboard
      }
    });
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
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFEFF4F9),
            Color(0xFFF8FAFC),
            Color(0xFFEDE7DD),
          ],
        ),
      ),
      child: SizedBox.expand(child: CustomPaint(painter: _StudioPainter())),
    );
  }
}

class _StudioPainter extends CustomPainter {
  const _StudioPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0x1207111F)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LivePassportPreview extends StatelessWidget {
  const _LivePassportPreview({required this.profile});

  final PassportProfile profile;

  @override
  Widget build(BuildContext context) {
    final String name = profile.name.trim().isEmpty
        ? 'Add a passport profile'
        : profile.name;

    return Container(
      height: 238,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF07111F).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF07111F),
                      Color(0xFF315CFF),
                      Color(0xFF19D3C5),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _PreviewPainter())),
            Positioned(
              left: 20,
              top: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'LIVE PREVIEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (profile.isEPassport) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.nfc_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _PreviewField(
                          label: 'Passport',
                          value: profile.passportNumber.isEmpty
                              ? 'Pending'
                              : profile.passportNumber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PreviewField(
                          label: 'Nationality',
                          value: profile.nationality.isEmpty
                              ? '--'
                              : profile.nationality,
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

class _PreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 7; i++) {
      final Path path = Path();
      final double y = 58 + i * 19;
      path.moveTo(-20, y);
      path.cubicTo(
        size.width * 0.24,
        y + 24,
        size.width * 0.62,
        y - 28,
        size.width + 18,
        y + 8,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: <Widget>[
          _ModeOption(
            label: 'E-Passport',
            icon: Icons.nfc_rounded,
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _ModeOption(
            label: 'Regular',
            icon: Icons.menu_book_rounded,
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _TapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF07111F) : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initDate = DateTime(2000);
    if (controller.text.isNotEmpty) {
      try {
        initDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return Container(
          height: 300,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initDate,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (DateTime newDate) {
                    controller.text = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
                    onChanged();
                  },
                ),
              ),
            ],
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
          _StudioField(
            controller: nameController,
            label: 'Full name',
            icon: Icons.person_rounded,
            onChanged: onChanged,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _StudioField(
                  controller: nationalityController,
                  label: 'Nationality',
                  icon: Icons.flag_rounded,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioField(
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
                child: _StudioField(
                  controller: dateOfBirthController,
                  label: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context, dateOfBirthController),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioField(
                  controller: expiryDateController,
                  label: 'Expiry date',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.event_available_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context, expiryDateController),
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initDate = DateTime(2000);
    if (controller.text.isNotEmpty) {
      try {
        initDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return Container(
          height: 300,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initDate,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (DateTime newDate) {
                    controller.text = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
                    onChanged();
                  },
                ),
              ),
            ],
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
          _StudioField(
            controller: nameController,
            label: 'Full name',
            icon: Icons.person_rounded,
            onChanged: onChanged,
          ),
          _StudioField(
            controller: passportNumberController,
            label: 'Passport number',
            icon: Icons.confirmation_number_rounded,
            onChanged: onChanged,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _StudioField(
                  controller: nationalityController,
                  label: 'Nationality',
                  icon: Icons.flag_rounded,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioField(
                  controller: dateOfBirthController,
                  label: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context, dateOfBirthController),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          _StudioField(
            controller: expiryDateController,
            label: 'Expiry date',
            hintText: 'YYYY-MM-DD',
            icon: Icons.event_available_rounded,
            readOnly: true,
            onTap: () => _selectDate(context, expiryDateController),
            onChanged: onChanged,
          ),
          _StudioField(
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

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScannerPainter());
  }
}

class _ScannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double y = 22; y < size.height; y += 24) {
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StudioField extends StatefulWidget {
  const _StudioField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.hintText,
    this.maxLines = 1,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;
  final String? hintText;
  final int maxLines;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  State<_StudioField> createState() => _StudioFieldState();
}

class _StudioFieldState extends State<_StudioField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: focused ? Colors.white : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: focused
              ? const Color(0xFF4C7CFF)
              : Colors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: widget.maxLines > 1 ? 16 : 0),
            child: Icon(
              widget.icon,
              color: focused
                  ? const Color(0xFF4C7CFF)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              maxLines: widget.maxLines,
              textInputAction: widget.textInputAction,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hintText,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF07111F),
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF07111F).withValues(alpha: 0.22),
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
    return _TapScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white),
            ),
            child: Icon(icon, color: const Color(0xFF07111F)),
          ),
        ),
      ),
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF34C759),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Passport Saved!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Securely added to your wallet.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  const _TapScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
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
    return _TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.25),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.1), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or enter manually',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.35), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.1), thickness: 1)),
        ],
      ),
    );
  }
}
