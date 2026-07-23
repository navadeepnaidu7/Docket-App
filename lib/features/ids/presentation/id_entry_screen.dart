import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/document_validators.dart';
import '../../../shared/widgets/completion_celebration.dart';
import '../../../shared/widgets/document_date_picker.dart';
import '../../../shared/widgets/entry/document_entry_scaffold.dart';
import '../../../shared/widgets/entry/entry_method_card.dart';
import '../../../shared/widgets/entry/entry_review_summary.dart';
import '../../../shared/widgets/studio_field.dart';
import '../../../shared/widgets/studio_section.dart';
import '../../dashboard/application/wallet_order_provider.dart';
import '../application/id_draft_controller.dart';
import '../application/id_list_provider.dart';
import '../application/id_scanner_service.dart';
import '../domain/id_document.dart';
import '../domain/id_document_catalog.dart';
import 'id_scanner_screen.dart';

enum _IdStep { method, details, review }

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

  _IdStep _step = _IdStep.method;
  String? _bannerError;
  bool _cameFromScan = false;

  bool get _isPan => widget.type == IdDocumentType.pan;

  String get _docLabel =>
      IdDocumentCatalog.titleFor(widget.type);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _numberCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _fatherCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _genderCtrl = TextEditingController();
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
    final IdDraftController n = ref.read(idDraftProvider.notifier);
    n
      ..updateHolderName(_nameCtrl.text)
      ..updateDocumentNumber(_numberCtrl.text)
      ..updateDateOfBirth(_dobCtrl.text)
      ..updateFatherName(_fatherCtrl.text)
      ..updateAddress(_addressCtrl.text)
      ..updateGender(_genderCtrl.text);
  }

  void _goTo(_IdStep step) {
    HapticService.select();
    setState(() {
      _step = step;
      _bannerError = null;
    });
  }

  void _onBack() {
    switch (_step) {
      case _IdStep.method:
        Navigator.of(context).maybePop();
      case _IdStep.details:
        _goTo(_IdStep.method);
      case _IdStep.review:
        _goTo(_cameFromScan ? _IdStep.method : _IdStep.details);
    }
  }

  int get _progressIndex => switch (_step) {
        _IdStep.method => 0,
        _IdStep.details => 1,
        _IdStep.review => 2,
      };

  String get _title => switch (_step) {
        _IdStep.method => 'Add $_docLabel',
        _IdStep.details => '$_docLabel details',
        _IdStep.review => 'Review',
      };

  Future<void> _openScanner() async {
    final IdScanResult? result = await Navigator.of(context).push<IdScanResult>(
      MaterialPageRoute<IdScanResult>(
        builder: (_) => IdScannerScreen(type: widget.type),
      ),
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
    ref.read(idDraftProvider.notifier).updateQrImageBase64(result.qrCodeData);
    if (result.capturedImagePath.isNotEmpty) {
      try {
        final List<int> bytes =
            await File(result.capturedImagePath).readAsBytes();
        ref
            .read(idDraftProvider.notifier)
            .updateImagePath(base64Encode(bytes));
      } catch (_) {
        ref
            .read(idDraftProvider.notifier)
            .updateImagePath(result.capturedImagePath);
      }
    }

    _cameFromScan = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: <Widget>[
          Icon(Icons.check_circle_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text('Scanned — review details before saving'),
        ]),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
    _goTo(_IdStep.review);
  }

  bool _validateDetails() {
    _syncDraft();
    final IdDocument doc = ref.read(idDraftProvider);

    if (doc.holderName.trim().isEmpty && doc.documentNumber.trim().isEmpty) {
      setState(
        () => _bannerError =
            'Add at least a name or document number to continue.',
      );
      return false;
    }

    final IdDocumentTypeForValidation typeForVal = _isPan
        ? IdDocumentTypeForValidation.pan
        : IdDocumentTypeForValidation.aadhaar;

    final String? validationError = DocumentValidators.validateIdForSave(
      dateOfBirth: doc.dateOfBirth,
      documentNumber: doc.documentNumber,
      type: typeForVal,
    );

    if (validationError != null) {
      setState(() => _bannerError = validationError);
      return false;
    }

    setState(() => _bannerError = null);
    return true;
  }

  void _continueFromDetails() {
    if (!_validateDetails()) return;
    _cameFromScan = false;
    _goTo(_IdStep.review);
  }

  void _save() {
    if (!_validateDetails()) {
      _goTo(_IdStep.details);
      return;
    }

    final IdDocument doc = ref.read(idDraftProvider);
    HapticService.success();
    SoundService.success();
    ref.read(idListProvider.notifier).addDocument(doc);
    ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(doc.id);
    showWalletSaveCelebration(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool showCta =
        _step == _IdStep.details || _step == _IdStep.review;

    String? ctaLabel;
    IconData? ctaIcon;
    VoidCallback? ctaAction;

    switch (_step) {
      case _IdStep.method:
        break;
      case _IdStep.details:
        ctaLabel = 'Continue';
        ctaIcon = Icons.arrow_forward_rounded;
        ctaAction = _continueFromDetails;
      case _IdStep.review:
        ctaLabel = 'Save to wallet';
        ctaIcon = Icons.wallet_rounded;
        ctaAction = _save;
    }

    return DocumentEntryScaffold(
      title: _title,
      stepIndex: _progressIndex,
      stepCount: 3,
      onBack: _onBack,
      primaryLabel: showCta ? ctaLabel : null,
      primaryIcon: ctaIcon,
      onPrimary: ctaAction,
      banner: _bannerError != null ? EntryBanner(message: _bannerError!) : null,
      body: switch (_step) {
        _IdStep.method => _MethodStep(
            docLabel: _docLabel,
            isPan: _isPan,
            onScan: _openScanner,
            onManual: () => _goTo(_IdStep.details),
          ),
        _IdStep.details => _DetailsStep(
            isPan: _isPan,
            nameCtrl: _nameCtrl,
            numberCtrl: _numberCtrl,
            dobCtrl: _dobCtrl,
            fatherCtrl: _fatherCtrl,
            addressCtrl: _addressCtrl,
            genderCtrl: _genderCtrl,
            onChanged: () {
              _syncDraft();
              if (_bannerError != null) setState(() => _bannerError = null);
            },
          ),
        _IdStep.review => _ReviewStep(
            doc: ref.watch(idDraftProvider),
            isPan: _isPan,
            onEdit: () => _goTo(_IdStep.details),
          ),
      },
    );
  }
}

// ── Steps ─────────────────────────────────────────────────────────────────────

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.docLabel,
    required this.isPan,
    required this.onScan,
    required this.onManual,
  });

  final String docLabel;
  final bool isPan;
  final VoidCallback onScan;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'How would you like to add it?',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPan
              ? 'Scan the PAN card to auto-fill, or type the details yourself.'
              : 'Scan the Aadhaar card or QR to auto-fill, or enter details.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: AppTokens.secondaryLabel(scheme),
          ),
        ),
        const SizedBox(height: 24),
        EntryMethodCard(
          hero: true,
          icon: Icons.document_scanner_rounded,
          title: 'Scan $docLabel',
          subtitle: 'Camera · auto-fill fields',
          onTap: onScan,
        ),
        const SizedBox(height: 8),
        EntryTextAction(
          label: 'Enter details manually',
          onTap: onManual,
        ),
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.isPan,
    required this.nameCtrl,
    required this.numberCtrl,
    required this.dobCtrl,
    required this.fatherCtrl,
    required this.addressCtrl,
    required this.genderCtrl,
    required this.onChanged,
  });

  final bool isPan;
  final TextEditingController nameCtrl;
  final TextEditingController numberCtrl;
  final TextEditingController dobCtrl;
  final TextEditingController fatherCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController genderCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const EntrySectionLabel('Identity'),
        StudioSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: Column(
              children: <Widget>[
                StudioField(
                  controller: nameCtrl,
                  label: 'Full name',
                  icon: Icons.person_rounded,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.words,
                ),
                StudioField(
                  controller: dobCtrl,
                  label: 'Date of birth',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => showDocumentDatePicker(
                    context: context,
                    controller: dobCtrl,
                    onChanged: onChanged,
                    kind: DocumentDateKind.dateOfBirth,
                    adultDob: isPan,
                    title: 'Date of birth',
                  ),
                  onChanged: onChanged,
                ),
                if (isPan)
                  StudioField(
                    controller: fatherCtrl,
                    label: "Father's name",
                    icon: Icons.people_rounded,
                    onChanged: onChanged,
                    textCapitalization: TextCapitalization.words,
                  ),
                if (!isPan)
                  StudioField(
                    controller: genderCtrl,
                    label: 'Gender',
                    icon: Icons.person_outline_rounded,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const EntrySectionLabel('Document'),
        StudioSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: Column(
              children: <Widget>[
                StudioField(
                  controller: numberCtrl,
                  label: isPan ? 'PAN number' : 'Aadhaar number',
                  icon: Icons.badge_rounded,
                  onChanged: onChanged,
                  textCapitalization: isPan
                      ? TextCapitalization.characters
                      : TextCapitalization.none,
                  keyboardType:
                      isPan ? TextInputType.text : TextInputType.number,
                ),
                if (!isPan)
                  StudioField(
                    controller: addressCtrl,
                    label: 'Address',
                    icon: Icons.location_on_rounded,
                    onChanged: onChanged,
                    maxLines: 3,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.doc,
    required this.isPan,
    required this.onEdit,
  });

  final IdDocument doc;
  final bool isPan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return EntryReviewSummary(
      title: doc.holderName.isEmpty
          ? IdDocumentCatalog.titleFor(doc.type)
          : doc.holderName,
      onEdit: onEdit,
      rows: <(String, String)>[
        (isPan ? 'PAN' : 'Aadhaar', doc.documentNumber),
        ('Date of birth', doc.dateOfBirth),
        if (isPan) ("Father's name", doc.fatherName),
        if (!isPan) ...<(String, String)>[
          ('Gender', doc.gender),
          ('Address', doc.address),
        ],
      ],
    );
  }
}
