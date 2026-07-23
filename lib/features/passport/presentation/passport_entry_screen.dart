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
import '../../mrz_scanner/domain/mrz_result.dart';
import '../../mrz_scanner/presentation/mrz_scanner_screen.dart';
import '../../nfc/presentation/nfc_scanner_sheet.dart' as import_nfc_sheet;
import '../application/passport_draft_controller.dart';
import '../application/passport_list_provider.dart';
import '../domain/passport_profile.dart';

enum _PassportStep { method, details, nfcPrep, review }

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

  _PassportStep _step = _PassportStep.method;
  String? _bannerError;
  bool _cameFromScan = false;

  static const List<_PassportStep> _progressSteps = <_PassportStep>[
    _PassportStep.method,
    _PassportStep.details,
    _PassportStep.review,
  ];

  @override
  void initState() {
    super.initState();
    final PassportProfile profile = ref.read(passportDraftProvider);
    _nameController = TextEditingController(text: profile.name);
    _passportNumberController =
        TextEditingController(text: profile.passportNumber);
    _nationalityController = TextEditingController(text: profile.nationality);
    _dateOfBirthController = TextEditingController(text: profile.dateOfBirth);
    _expiryDateController = TextEditingController(text: profile.expiryDate);
    _mrzController = TextEditingController(text: profile.mrzRaw);
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
    final PassportDraftController controller =
        ref.read(passportDraftProvider.notifier);
    controller
      ..updateName(_nameController.text)
      ..updatePassportNumber(_passportNumberController.text)
      ..updateNationality(_nationalityController.text)
      ..updateDateOfBirth(_dateOfBirthController.text)
      ..updateExpiryDate(_expiryDateController.text)
      ..updateMrzRaw(_mrzController.text);
  }

  void _goTo(_PassportStep step) {
    HapticService.select();
    setState(() {
      _step = step;
      _bannerError = null;
    });
  }

  void _onBack() {
    switch (_step) {
      case _PassportStep.method:
        Navigator.of(context).maybePop();
      case _PassportStep.details:
        _goTo(_PassportStep.method);
      case _PassportStep.nfcPrep:
        _goTo(_PassportStep.method);
      case _PassportStep.review:
        _goTo(_cameFromScan ? _PassportStep.method : _PassportStep.details);
    }
  }

  int get _progressIndex {
    return switch (_step) {
      _PassportStep.method => 0,
      _PassportStep.details || _PassportStep.nfcPrep => 1,
      _PassportStep.review => 2,
    };
  }

  String get _title {
    return switch (_step) {
      _PassportStep.method => 'Add passport',
      _PassportStep.details => 'Passport details',
      _PassportStep.nfcPrep => 'e-Passport NFC',
      _PassportStep.review => 'Review',
    };
  }

  Future<void> _openCameraScanner() async {
    final MrzResult? result = await Navigator.of(context).push<MrzResult>(
      MaterialPageRoute<MrzResult>(builder: (_) => const MrzScannerScreen()),
    );
    if (result == null || !mounted) return;

    _nameController.text = result.displayName;
    _passportNumberController.text = result.passportNumber;
    _nationalityController.text = result.nationality;
    _dateOfBirthController.text = result.dateOfBirth;
    _expiryDateController.text = result.expiryDate;
    _syncDraft();
    if (result.capturedImagePath.isNotEmpty) {
      ref
          .read(passportDraftProvider.notifier)
          .updateImagePath(result.capturedImagePath);
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
    _goTo(_PassportStep.review);
  }

  Future<void> _startNfcScan() async {
    _syncDraft();
    final String? dateError = DocumentValidators.validatePassportDates(
      dateOfBirth: _dateOfBirthController.text,
      expiryDate: _expiryDateController.text,
    );
    if (dateError != null) {
      setState(() => _bannerError = 'Cannot scan NFC: $dateError');
      return;
    }
    if (_passportNumberController.text.trim().isEmpty) {
      setState(() => _bannerError = 'Passport number is required for NFC.');
      return;
    }

    final List<String> dobParts = _dateOfBirthController.text.split('-');
    final List<String> expParts = _expiryDateController.text.split('-');
    String dobFormatted = _dateOfBirthController.text;
    String expFormatted = _expiryDateController.text;
    if (dobParts.length == 3) {
      dobFormatted =
          '${dobParts[0].substring(2)}${dobParts[1]}${dobParts[2]}';
    }
    if (expParts.length == 3) {
      expFormatted =
          '${expParts[0].substring(2)}${expParts[1]}${expParts[2]}';
    }

    final Map<String, dynamic>? result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: import_nfc_sheet.NfcScannerSheet(
          passportNumber: _passportNumberController.text,
          dateOfBirth: dobFormatted,
          expiryDate: expFormatted,
        ),
      ),
    );

    if (result == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final String photoValue = result['photoBase64']?.toString() ?? '';
        final bool hasImage = photoValue.isNotEmpty;
        final Map<String, dynamic> debugData =
            Map<String, dynamic>.from(result);
        if (hasImage) {
          debugData['photoBase64'] =
              '[IMAGE RETRIEVED! Base64 String length: ${photoValue.length}]';
        } else {
          debugData['photoBase64'] = '[NO IMAGE FOUND OR DECODE FAILED]';
        }

        return AlertDialog(
          title: const Text(
            'NFC Chip Data (Raw)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              debugData.entries
                  .map((MapEntry<String, dynamic> e) => '${e.key}:\n${e.value}')
                  .join('\n\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply Details'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    setState(() {
      if (result['firstName'] != null) {
        _nameController.text =
            '${result['firstName']} ${result['lastName'] ?? ''}'.trim();
      }
      if (result['nationality'] != null) {
        _nationalityController.text = result['nationality'].toString();
      }
      if (result['documentNumber'] != null) {
        _passportNumberController.text = result['documentNumber'].toString();
      }
    });
    _syncDraft();

    final PassportDraftController draftNotifier =
        ref.read(passportDraftProvider.notifier);
    if (result['photoBase64'] != null) {
      draftNotifier.updateImagePath(result['photoBase64'].toString());
    }
    final PassportProfile updatedProfile =
        ref.read(passportDraftProvider).copyWith(
              gender: result['gender']?.toString(),
              placeOfBirth: result['dg11_placeOfBirth']?.toString(),
              issueDate: result['dg12_dateOfIssue']?.toString(),
              issuingAuthority: result['dg12_issuingAuthority']?.toString(),
            );
    draftNotifier.replaceWith(updatedProfile);
    draftNotifier.updateIsEPassport(true);
    _cameFromScan = true;
    _goTo(_PassportStep.review);
  }

  bool _validateDetails() {
    _syncDraft();
    final PassportProfile profile = ref.read(passportDraftProvider);
    if (profile.name.trim().isEmpty && profile.passportNumber.trim().isEmpty) {
      setState(
        () => _bannerError =
            'Add at least a full name or passport number to continue.',
      );
      return false;
    }
    final String? dateError = DocumentValidators.validatePassportDates(
      dateOfBirth: profile.dateOfBirth,
      expiryDate: profile.expiryDate,
    );
    if (dateError != null) {
      setState(() => _bannerError = dateError);
      return false;
    }
    setState(() => _bannerError = null);
    return true;
  }

  void _continueFromDetails() {
    if (!_validateDetails()) return;
    _cameFromScan = false;
    _goTo(_PassportStep.review);
  }

  void _continueFromNfcPrep() {
    if (!_validateDetails()) return;
    _startNfcScan();
  }

  void _saveDraft() {
    if (!_validateDetails()) {
      _goTo(_PassportStep.details);
      return;
    }

    final PassportProfile profile = ref.read(passportDraftProvider);
    HapticService.success();
    SoundService.success();
    ref.read(passportListProvider.notifier).addPassport(profile);
    ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(profile.id);
    showWalletSaveCelebration(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool showCta = _step == _PassportStep.details ||
        _step == _PassportStep.nfcPrep ||
        _step == _PassportStep.review;

    String? ctaLabel;
    IconData? ctaIcon;
    VoidCallback? ctaAction;

    switch (_step) {
      case _PassportStep.method:
        break;
      case _PassportStep.details:
        ctaLabel = 'Continue';
        ctaIcon = Icons.arrow_forward_rounded;
        ctaAction = _continueFromDetails;
      case _PassportStep.nfcPrep:
        ctaLabel = 'Scan chip';
        ctaIcon = Icons.nfc_rounded;
        ctaAction = _continueFromNfcPrep;
      case _PassportStep.review:
        ctaLabel = 'Save to wallet';
        ctaIcon = Icons.wallet_rounded;
        ctaAction = _saveDraft;
    }

    return DocumentEntryScaffold(
      title: _title,
      stepIndex: _progressIndex,
      stepCount: _progressSteps.length,
      onBack: _onBack,
      primaryLabel: showCta ? ctaLabel : null,
      primaryIcon: ctaIcon,
      onPrimary: ctaAction,
      banner: _bannerError != null ? EntryBanner(message: _bannerError!) : null,
      body: switch (_step) {
        _PassportStep.method => _MethodStep(
            onScanMrz: _openCameraScanner,
            onNfc: () => _goTo(_PassportStep.nfcPrep),
            onManual: () => _goTo(_PassportStep.details),
          ),
        _PassportStep.details => _DetailsStep(
            nameController: _nameController,
            nationalityController: _nationalityController,
            passportNumberController: _passportNumberController,
            dateOfBirthController: _dateOfBirthController,
            expiryDateController: _expiryDateController,
            onChanged: () {
              _syncDraft();
              if (_bannerError != null) setState(() => _bannerError = null);
            },
          ),
        _PassportStep.nfcPrep => _NfcPrepStep(
            passportNumberController: _passportNumberController,
            dateOfBirthController: _dateOfBirthController,
            expiryDateController: _expiryDateController,
            onChanged: () {
              _syncDraft();
              if (_bannerError != null) setState(() => _bannerError = null);
            },
          ),
        _PassportStep.review => _ReviewStep(
            profile: ref.watch(passportDraftProvider),
            onEdit: () => _goTo(_PassportStep.details),
            onNfc: () => _goTo(_PassportStep.nfcPrep),
          ),
      },
    );
  }
}

// ── Steps ─────────────────────────────────────────────────────────────────────

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.onScanMrz,
    required this.onNfc,
    required this.onManual,
  });

  final VoidCallback onScanMrz;
  final VoidCallback onNfc;
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
          'Scan the photo page for the best results. You can always edit before saving.',
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
          title: 'Scan passport',
          subtitle: 'Camera · MRZ auto-fill',
          onTap: onScanMrz,
        ),
        const SizedBox(height: 12),
        EntryMethodCard(
          icon: Icons.nfc_rounded,
          title: 'Read e-Passport chip',
          subtitle: 'NFC · needs number, DOB & expiry',
          onTap: onNfc,
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
    required this.nameController,
    required this.nationalityController,
    required this.passportNumberController,
    required this.dateOfBirthController,
    required this.expiryDateController,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final TextEditingController nationalityController;
  final TextEditingController passportNumberController;
  final TextEditingController dateOfBirthController;
  final TextEditingController expiryDateController;
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
                  controller: nameController,
                  label: 'Full name',
                  icon: Icons.person_rounded,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.words,
                ),
                StudioField(
                  controller: nationalityController,
                  label: 'Nationality',
                  icon: Icons.flag_rounded,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.characters,
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
                  controller: passportNumberController,
                  label: 'Passport number',
                  icon: Icons.confirmation_number_rounded,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.characters,
                ),
                StudioField(
                  controller: dateOfBirthController,
                  label: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => showDocumentDatePicker(
                    context: context,
                    controller: dateOfBirthController,
                    onChanged: onChanged,
                    kind: DocumentDateKind.dateOfBirth,
                    title: 'Date of birth',
                  ),
                  onChanged: onChanged,
                ),
                StudioField(
                  controller: expiryDateController,
                  label: 'Expiry date',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.event_available_rounded,
                  readOnly: true,
                  onTap: () => showDocumentDatePicker(
                    context: context,
                    controller: expiryDateController,
                    onChanged: onChanged,
                    kind: DocumentDateKind.expiry,
                    title: 'Expiry date',
                  ),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NfcPrepStep extends StatelessWidget {
  const _NfcPrepStep({
    required this.passportNumberController,
    required this.dateOfBirthController,
    required this.expiryDateController,
    required this.onChanged,
  });

  final TextEditingController passportNumberController;
  final TextEditingController dateOfBirthController;
  final TextEditingController expiryDateController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'BAC details',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'These match the data page and unlock the chip. Then hold your phone to the passport cover.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: AppTokens.secondaryLabel(scheme),
          ),
        ),
        const SizedBox(height: 20),
        StudioSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
            child: Column(
              children: <Widget>[
                StudioField(
                  controller: passportNumberController,
                  label: 'Passport number',
                  icon: Icons.confirmation_number_rounded,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.characters,
                ),
                StudioField(
                  controller: dateOfBirthController,
                  label: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.cake_rounded,
                  readOnly: true,
                  onTap: () => showDocumentDatePicker(
                    context: context,
                    controller: dateOfBirthController,
                    onChanged: onChanged,
                    kind: DocumentDateKind.dateOfBirth,
                    title: 'Date of birth',
                  ),
                  onChanged: onChanged,
                ),
                StudioField(
                  controller: expiryDateController,
                  label: 'Expiry date',
                  hintText: 'YYYY-MM-DD',
                  icon: Icons.event_available_rounded,
                  readOnly: true,
                  onTap: () => showDocumentDatePicker(
                    context: context,
                    controller: expiryDateController,
                    onChanged: onChanged,
                    kind: DocumentDateKind.expiry,
                    title: 'Expiry date',
                  ),
                  onChanged: onChanged,
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
    required this.profile,
    required this.onEdit,
    required this.onNfc,
  });

  final PassportProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onNfc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EntryReviewSummary(
          title: profile.name.isEmpty ? 'Passport' : profile.name,
          onEdit: onEdit,
          rows: <(String, String)>[
            ('Number', profile.passportNumber),
            ('Nationality', profile.nationality),
            ('Date of birth', profile.dateOfBirth),
            ('Expiry', profile.expiryDate),
            if (profile.gender.isNotEmpty) ('Gender', profile.gender),
            if (profile.placeOfBirth.isNotEmpty)
              ('Place of birth', profile.placeOfBirth),
          ],
        ),
        const SizedBox(height: 14),
        EntryMethodCard(
          icon: Icons.nfc_rounded,
          title: profile.isEPassport
              ? 'Re-scan e-Passport chip'
              : 'Add chip data (optional)',
          subtitle: 'NFC unlock · does not block saving',
          onTap: onNfc,
        ),
      ],
    );
  }
}
