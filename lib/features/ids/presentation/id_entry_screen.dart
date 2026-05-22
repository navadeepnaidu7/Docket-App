import 'dart:ui';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/entry_reveal.dart';
import '../../../core/sound/sound_service.dart';
import '../application/id_draft_controller.dart';
import '../application/id_list_provider.dart';
import '../application/id_scanner_service.dart';
import '../domain/id_document.dart';
import 'id_scanner_screen.dart';

class IdEntryScreen extends ConsumerStatefulWidget {
  const IdEntryScreen({super.key, required this.type});

  final IdDocumentType type;

  @override
  ConsumerState<IdEntryScreen> createState() => _IdEntryScreenState();
}

class _IdEntryScreenState extends ConsumerState<IdEntryScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _fatherCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _genderCtrl;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty values immediately
    _nameCtrl = TextEditingController();
    _numberCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _fatherCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _genderCtrl = TextEditingController();
    // Defer provider mutation until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(idDraftProvider.notifier).reset(widget.type);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _dobCtrl.dispose();
    _fatherCtrl.dispose();
    _addressCtrl.dispose();
    _genderCtrl.dispose();
    super.dispose();
  }

  void _syncDraft() {
    final n = ref.read(idDraftProvider.notifier);
    n
      ..updateHolderName(_nameCtrl.text)
      ..updateDocumentNumber(_numberCtrl.text)
      ..updateDateOfBirth(_dobCtrl.text)
      ..updateFatherName(_fatherCtrl.text)
      ..updateAddress(_addressCtrl.text)
      ..updateGender(_genderCtrl.text);
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<IdScanResult>(
      MaterialPageRoute<IdScanResult>(
          builder: (_) => IdScannerScreen(type: widget.type)),
    );
    if (result == null || !mounted) return;

    setState(() {
      _nameCtrl.text = result.holderName;
      _numberCtrl.text = result.documentNumber;
      _dobCtrl.text = result.dateOfBirth;
      _fatherCtrl.text = result.fatherName;
      _addressCtrl.text = result.address;
      _genderCtrl.text = result.gender;
    });
    _syncDraft();
    if (result.capturedImagePath.isNotEmpty) {
      // Encode the full image to base64 so it persists across app restarts
      try {
        final bytes = await File(result.capturedImagePath).readAsBytes();
        ref.read(idDraftProvider.notifier).updateImagePath(base64Encode(bytes));
      } catch (_) {
        ref.read(idDraftProvider.notifier).updateImagePath(result.capturedImagePath);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text('Fields filled from scan — please review'),
        ]),
        backgroundColor: const Color(0xFF34C759),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  void _save() {
    _syncDraft();
    final doc = ref.read(idDraftProvider);

    if (doc.holderName.trim().isEmpty && doc.documentNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text('Please fill in at least a name or document number.'),
        ]),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    HapticFeedback.heavyImpact();
    SoundService.success();
    ref.read(idListProvider.notifier).addDocument(doc);

    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim1, anim2) => _SuccessOverlay(type: widget.type),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim1, anim2, child) =>
          FadeTransition(opacity: anim1, child: child),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // pop overlay
        Navigator.of(context).pop(); // pop entry screen
      }
    });
  }

  Future<void> _selectDate(TextEditingController ctrl) async {
    DateTime init = DateTime(2000);
    if (ctrl.text.isNotEmpty) {
      try {
        init = DateTime.parse(ctrl.text);
      } catch (_) {}
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 300,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Date',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E))),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Done',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: init,
                minimumDate: DateTime(1900),
                maximumDate: DateTime(2100),
                onDateTimeChanged: (d) {
                  ctrl.text =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  _syncDraft();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPan = widget.type == IdDocumentType.pan;
    final label = isPan ? 'PAN Card' : 'Aadhaar Card';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop()),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CircleButton(icon: Icons.check_rounded, onTap: _save),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _StudioBackdrop(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 30),
              children: [
                const SizedBox(height: 18),
                EntryReveal(
                  child: _GlassPanel(
                    child: Column(
                      children: [
                        _ScanButton(
                            label: 'Scan $label',
                            onTap: _openScanner),
                        const _OrDivider(),
                        _StudioField(
                            controller: _nameCtrl,
                            label: 'Full Name',
                            icon: Icons.person_rounded,
                            onChanged: _syncDraft),
                        _StudioField(
                            controller: _numberCtrl,
                            label: isPan ? 'PAN Number' : 'Aadhaar Number',
                            icon: Icons.badge_rounded,
                            onChanged: _syncDraft,
                            textCapitalization: isPan
                                ? TextCapitalization.characters
                                : TextCapitalization.none),
                        _StudioField(
                            controller: _dobCtrl,
                            label: 'Date of Birth',
                            icon: Icons.cake_rounded,
                            onChanged: _syncDraft,
                            readOnly: true,
                            onTap: () => _selectDate(_dobCtrl)),
                        if (isPan)
                          _StudioField(
                              controller: _fatherCtrl,
                              label: "Father's Name",
                              icon: Icons.people_rounded,
                              onChanged: _syncDraft),
                        if (!isPan) ...[
                          _StudioField(
                              controller: _genderCtrl,
                              label: 'Gender',
                              icon: Icons.person_outline_rounded,
                              onChanged: _syncDraft),
                          _StudioField(
                              controller: _addressCtrl,
                              label: 'Address',
                              icon: Icons.location_on_rounded,
                              onChanged: _syncDraft,
                              maxLines: 3),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                EntryReveal(
                  delay: const Duration(milliseconds: 80),
                  child: _SaveButton(onTap: _save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Backdrop ──────────────────────────────────────────────────────────────────

class _StudioBackdrop extends StatelessWidget {
  const _StudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF4F9), Color(0xFFF8FAFC), Color(0xFFEDE7DD)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.label, required this.onTap});
  final String label;
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
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const Text('Auto-fill from camera',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: Colors.black.withValues(alpha: 0.1), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or enter manually',
                style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Divider(
                  color: Colors.black.withValues(alpha: 0.1), thickness: 1)),
        ],
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
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.words,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;

  @override
  State<_StudioField> createState() => _StudioFieldState();
}

class _StudioFieldState extends State<_StudioField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
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
                : Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: widget.maxLines > 1 ? 16 : 0),
            child: Icon(widget.icon,
                color: focused
                    ? const Color(0xFF4C7CFF)
                    : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _focus,
              controller: widget.controller,
              maxLines: widget.maxLines,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              textCapitalization: widget.textCapitalization,
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                  labelText: widget.label,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none),
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
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF07111F).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 14)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
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
  const _SuccessOverlay({required this.type});
  final IdDocumentType type;

  @override
  Widget build(BuildContext context) {
    final isPan = type == IdDocumentType.pan;
    return Scaffold(
      backgroundColor:
          isPan ? const Color(0xFF1C3252) : const Color(0xFF003F87),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 60),
            ),
            const SizedBox(height: 32),
            Text(
              isPan ? 'PAN Card Saved!' : 'Aadhaar Card Saved!',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Securely added to your wallet.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
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
          child: widget.child),
    );
  }
}
