import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../core/validation/document_validators.dart';
import '../../../shared/prompt_flow/prompt_flow_controller.dart';
import '../../../shared/prompt_flow/prompt_flow_screen.dart';
import '../../../shared/prompt_flow/prompt_step.dart';
import '../../../shared/prompt_flow/widgets/prompt_inputs.dart';
import '../../../shared/prompt_flow/widgets/prompt_review.dart';
import '../../../shared/widgets/completion_celebration.dart';
import '../../mrz_scanner/domain/mrz_result.dart';
import '../../nfc/application/bac_key_format.dart';
import '../../nfc/application/chip_payload.dart';
import '../../nfc/application/nfc_service.dart';
import '../../nfc/domain/nfc_failure.dart';
import '../../nfc/presentation/nfc_prompt_step.dart';
import '../../mrz_scanner/presentation/mrz_scanner_screen.dart';
import '../../dashboard/application/wallet_order_provider.dart';
import '../application/passport_list_provider.dart';
import '../domain/passport_profile.dart';
import 'flow/passport_prompt_flow.dart';

/// Which kind of passport the user said they were adding.
///
/// Passed in explicitly rather than set as a side effect on a shared draft
/// before pushing the route. The chip route exists only for [ePassport], so a
/// "Regular passport" is never offered a chip read it does not have — the
/// screen this replaces asked, then ignored the answer.
enum PassportKind { ePassport, regular }

class PassportPromptScreen extends ConsumerStatefulWidget {
  const PassportPromptScreen({super.key, required this.kind});

  final PassportKind kind;

  @override
  ConsumerState<PassportPromptScreen> createState() =>
      _PassportPromptScreenState();
}

class _PassportPromptScreenState extends ConsumerState<PassportPromptScreen> {
  late final PromptFlowController _flow;
  final NfcService _nfc = NfcService();

  NfcPhase _nfcPhase = NfcPhase.idle;
  NfcFailure? _nfcFailure;

  /// Consecutive BAC failures. The second one pads the document number to
  /// nine characters, which some issuers require.
  int _bacAttempts = 0;

  @override
  void initState() {
    super.initState();
    _flow = PromptFlowController(
      steps: buildPassportFlow(),
      initialFlags: <String, bool>{
        PassportFlag.isEPassport: widget.kind == PassportKind.ePassport,
      },
    );
  }

  @override
  void dispose() {
    _nfc.stopNfcRead();
    _flow.dispose();
    super.dispose();
  }

  // -- Chip -------------------------------------------------------------------

  Future<void> _readChip() async {
    // Final gate before touching the platform channel. The empty-is-valid date
    // validators meant a read could previously start with no BAC data at all
    // and come back as an opaque INVALID_ARGS.
    final Map<String, String> errors = DocumentValidators.validateBacTriple(
      passportNumber: _flow.state.value(PassportField.passportNumber),
      dateOfBirth: _flow.state.value(PassportField.dateOfBirth),
      expiryDate: _flow.state.value(PassportField.expiryDate),
    );
    if (errors.isNotEmpty) {
      setState(() {
        _nfcPhase = NfcPhase.failed;
        _nfcFailure = NfcFailure.fromCode('INVALID_ARGS');
      });
      return;
    }

    final String raw = _flow.state.value(PassportField.passportNumber);
    final String number = _bacAttempts > 0
        ? BacKeyFormat.padDocumentNumber(raw)
        : BacKeyFormat.toBacDocumentNumber(raw);
    final String? dob = BacKeyFormat.toBacDate(
      _flow.state.value(PassportField.dateOfBirth),
    );
    final String? expiry = BacKeyFormat.toBacDate(
      _flow.state.value(PassportField.expiryDate),
    );

    if (dob == null || expiry == null) {
      setState(() {
        _nfcPhase = NfcPhase.failed;
        _nfcFailure = NfcFailure.fromCode('INVALID_ARGS');
      });
      return;
    }

    setState(() {
      _nfcPhase = NfcPhase.waiting;
      _nfcFailure = null;
    });
    HapticService.impact();

    try {
      final Map<String, dynamic>? chip = await _nfc.startNfcRead(
        passportNumber: number,
        dateOfBirth: dob,
        expiryDate: expiry,
      );
      if (!mounted) return;

      if (chip == null) {
        setState(() => _nfcPhase = NfcPhase.idle);
        return;
      }

      _bacAttempts = 0;
      _applyChip(chip);
    } on NfcException catch (e) {
      if (!mounted) return;
      if (e.code == 'BAC_FAILED') _bacAttempts++;

      final NfcFailure failure = NfcFailure.fromCode(
        e.code,
        attempt: _bacAttempts,
      );
      if (failure.isSilent) {
        setState(() => _nfcPhase = NfcPhase.idle);
        return;
      }

      HapticService.error();
      setState(() {
        _nfcPhase = NfcPhase.failed;
        _nfcFailure = failure;
      });
    }
  }

  /// Folds a chip payload into the flow.
  ///
  /// The chip is the most trustworthy source there is, so its values take over
  /// from what was typed, and review marks them as chip-sourced. Mapping lives
  /// in [ChipPayload] so every DG field that reaches the card is covered —
  /// previously DG1 dates, DG2 photo, DG11 place of birth and DG12 issue
  /// metadata were read natively but only a subset was folded into the flow,
  /// and even that subset was dropped again on save.
  void _applyChip(Map<String, dynamic> chip) {
    _flow.applyScan(ChipPayload.toFlowValues(chip), source: FieldSource.chip);
    _flow.setFlag(PassportFlag.chipRead, value: true);

    HapticService.success();
    setState(() => _nfcPhase = NfcPhase.success);
  }

  /// Sends the user to the field most likely to be wrong, and back here after.
  void _recover(NfcRecovery action) {
    switch (action) {
      case NfcRecovery.retry:
        _readChip();
      case NfcRecovery.fixDetails:
        setState(() => _nfcPhase = NfcPhase.idle);
        _flow.jumpTo(
          PassportField.passportNumber,
          returnTo: PassportField.nfcRead,
        );
      case NfcRecovery.continueWithout:
        // Giving up on the chip means nothing else will supply the name,
        // nationality or sex, so those steps have to come back.
        setState(() => _nfcPhase = NfcPhase.idle);
        _flow.setFlag(PassportFlag.chipSkipped, value: true);
        _flow.next();
      case NfcRecovery.openSettings:
      case NfcRecovery.none:
        setState(() => _nfcPhase = NfcPhase.idle);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _onPrimary() {
    final PromptStep step = _flow.current;

    if (step.id == PassportField.review) {
      _save();
      return;
    }

    if (step.id == PassportField.method) {
      // The route tiles commit this step themselves.
      return;
    }

    if (step.id == PassportField.nfcRead) {
      switch (_nfcPhase) {
        case NfcPhase.idle:
          _readChip();
        case NfcPhase.failed:
          _recover(_nfcFailure?.primary ?? NfcRecovery.retry);
        case NfcPhase.waiting:
        case NfcPhase.reading:
          _nfc.stopNfcRead();
          setState(() => _nfcPhase = NfcPhase.idle);
        case NfcPhase.success:
          _flow.next();
      }
      return;
    }

    _flow.next();
  }

  void _choosePath(PromptPath path) {
    HapticService.select();
    _flow.setPath(path);
    if (path == PromptPath.scan) {
      _openScanner();
      return;
    }
    _flow.next();
  }

  /// Opens the camera, then folds whatever it read into the flow.
  ///
  /// A cancelled or failed scan does not dead-end: the flow continues on the
  /// manual route with whatever was already collected. The screen this
  /// replaces returned the user to the method chooser with no explanation.
  Future<void> _openScanner() async {
    final MrzResult? result = await Navigator.of(context).push<MrzResult>(
      MaterialPageRoute<MrzResult>(builder: (_) => const MrzScannerScreen()),
    );

    if (!mounted) return;

    if (result == null) {
      _flow.setPath(PromptPath.manual);
      _flow.next();
      return;
    }

    // Every field the MRZ carries, including the ones the old screen collected
    // and then dropped on the floor: gender, the raw lines, issuing country.
    _flow.applyScan(
      <String, String>{
        PassportField.name: result.displayName,
        PassportField.passportNumber: result.passportNumber,
        PassportField.dateOfBirth: result.dateOfBirth,
        PassportField.expiryDate: result.expiryDate,
        PassportField.nationality: result.nationality,
        PassportField.gender: normaliseGender(result.gender),
        'mrzRaw': <String>[
          result.rawLine1,
          result.rawLine2,
        ].where((String l) => l.isNotEmpty).join('\n'),
        'capturedImagePath': result.capturedImagePath,
      },
      source: FieldSource.scanned,
      // A checksum mismatch is shown as "double-check this" rather than
      // blocking, but it is never presented as confirmed.
      trusted: result.checksumValid,
    );
    _flow.next();
  }

  void _save() {
    final PromptFlowState s = _flow.state;

    // Every field the card paints must come through here. Chip reads used to
    // land placeOfBirth / issueDate / issuingAuthority / photoBase64 in the
    // flow and then drop them on this constructor, so the wallet card showed
    // em-dashes and a placeholder portrait after a successful NFC read.
    final PassportProfile profile = PassportProfile(
      name: s.value(PassportField.name).trim(),
      passportNumber: s.value(PassportField.passportNumber).trim(),
      nationality: s.value(PassportField.nationality).trim().toUpperCase(),
      dateOfBirth: s.value(PassportField.dateOfBirth),
      expiryDate: s.value(PassportField.expiryDate),
      imagePath: s.value('capturedImagePath'),
      mrzRaw: s.value('mrzRaw'),
      photoBase64: s.value('photoBase64'),
      placeOfBirth: s.value('placeOfBirth').trim(),
      issueDate: s.value('issueDate'),
      issuingAuthority: s.value('issuingAuthority').trim(),
      gender: normaliseGender(s.value(PassportField.gender)),
      isEPassport: widget.kind == PassportKind.ePassport,
    );

    HapticService.success();
    SoundService.success();
    ref.read(passportListProvider.notifier).addPassport(profile);
    ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(profile.id);
    showWalletSaveCelebration(context);
  }

  // ── Step bodies ────────────────────────────────────────────────────────────

  Widget _buildStep(BuildContext context, PromptStep step) {
    if (step.id == PassportField.method) return _methodStep();
    if (step.id == PassportField.review) return _reviewStep();
    if (step.id == PassportField.nfcRead) {
      return NfcPromptBody(phase: _nfcPhase, failure: _nfcFailure);
    }

    // A value that came from a scan or the chip is confirmed, not re-asked.
    if (_flow.isConfirming) {
      return PromptConfirmValue(
        value: _flow.state.value(step.id),
        source: _flow.state.sourceOf(step.id),
        mono: step.style == PromptInputStyle.mono,
        trusted: _flow.state.flags['trustedScan'] ?? true,
        onChange: () => _flow.setValue(step.id, _flow.state.value(step.id)),
      );
    }

    return switch (step.kind) {
      PromptStepKind.date => PromptDateInput(
        value: _flow.state.value(step.id),
        mode: step.id == PassportField.expiryDate
            ? PromptDateMode.future
            : PromptDateMode.past,
        onChanged: (String v) => _flow.setValue(step.id, v),
      ),
      PromptStepKind.choice => PromptChoiceList(
        choices: step.choices,
        value: _flow.state.value(step.id),
        onChanged: (String v) => _flow.setValue(step.id, v),
      ),
      _ => PromptTextInput(
        step: step,
        value: _flow.state.value(step.id),
        hasError: _flow.currentError != null,
        onChanged: (String v) => _flow.setValue(step.id, v),
        onSubmitted: _onPrimary,
      ),
    };
  }

  /// How to supply the details — never *whether* to read the chip.
  ///
  /// On an e-passport the read always follows, so offering it here as a third
  /// option was wrong: it made the document's whole point look optional, and
  /// sent the user through a longer set of questions to reach it.
  Widget _methodStep() {
    final bool chip = widget.kind == PassportKind.ePassport;

    return Column(
      children: <Widget>[
        PromptOptionTile(
          title: 'Scan the photo page',
          subtitle: chip
              ? 'Camera — reads what the chip needs to unlock'
              : 'Camera — reads the machine-readable zone',
          icon: Icons.document_scanner_rounded,
          emphasis: true,
          onTap: () => _choosePath(PromptPath.scan),
        ),
        PromptOptionTile(
          title: 'Type it in',
          subtitle: chip
              ? 'Three details, then hold it to your phone'
              : 'Enter the details yourself',
          icon: Icons.keyboard_rounded,
          onTap: () => _choosePath(PromptPath.manual),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final PromptFlowState s = _flow.state;

    PromptReviewRow row(String id, String label) {
      final String value = s.value(id);
      return PromptReviewRow(
        stepId: id,
        label: label,
        value: value,
        source: s.sourceOf(id),
        missing: value.trim().isEmpty,
      );
    }

    return PromptReviewCard(
      chipVerified: s.flag(PassportFlag.chipRead),
      onEdit: (String stepId) =>
          _flow.jumpTo(stepId, returnTo: PassportField.review),
      rows: <PromptReviewRow>[
        row(PassportField.name, 'Name'),
        row(PassportField.passportNumber, 'Number'),
        row(PassportField.dateOfBirth, 'Date of birth'),
        row(PassportField.expiryDate, 'Expires'),
        row(PassportField.nationality, 'Nationality'),
        row(PassportField.gender, 'Sex'),
      ],
    );
  }

  // ── Footer wiring ──────────────────────────────────────────────────────────

  String get _primaryLabel {
    final PromptStep step = _flow.current;
    if (step.id == PassportField.review) return 'Save to wallet';
    if (step.id == PassportField.nfcRead) {
      return switch (_nfcPhase) {
        NfcPhase.failed => _labelFor(_nfcFailure?.primary),
        NfcPhase.success => 'Continue',
        NfcPhase.waiting || NfcPhase.reading => 'Cancel',
        NfcPhase.idle => 'Start reading',
      };
    }
    if (_flow.isConfirming) return "Yes, that's right";
    return 'Continue';
  }

  static String _labelFor(NfcRecovery? action) => switch (action) {
    NfcRecovery.retry => 'Try again',
    NfcRecovery.fixDetails => 'Check my details',
    NfcRecovery.continueWithout => 'Continue without the chip',
    NfcRecovery.openSettings => 'Open settings',
    _ => 'Continue',
  };

  String? get _secondaryLabel {
    final PromptStep step = _flow.current;
    if (step.id == PassportField.method) return null;
    if (step.id == PassportField.nfcRead) {
      if (_nfcPhase == NfcPhase.failed) {
        final NfcRecovery? second = _nfcFailure?.secondary;
        return second == null || second == NfcRecovery.none
            ? null
            : _labelFor(second);
      }
      return _nfcPhase == NfcPhase.idle ? 'Skip the chip' : null;
    }
    if (step.skippable && !_flow.isConfirming) return 'Skip for now';
    return null;
  }

  void _onSecondary() {
    if (_flow.current.id == PassportField.nfcRead) {
      _recover(
        _nfcPhase == NfcPhase.failed
            ? (_nfcFailure?.secondary ?? NfcRecovery.none)
            : NfcRecovery.continueWithout,
      );
      return;
    }
    _flow.skip();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flow,
      builder: (BuildContext context, Widget? _) {
        final bool isMethod = _flow.current.id == PassportField.method;

        return PromptFlowScreen(
          controller: _flow,
          stepBuilder: _buildStep,
          primaryLabel: _primaryLabel,
          onPrimary: _onPrimary,
          // The route step is chosen by tapping a tile; a CTA underneath would
          // be a second way to do the same thing with no obvious default.
          showPrimary: !isMethod,
          secondaryLabel: _secondaryLabel,
          onSecondary: _onSecondary,
          // pop, never maybePop: maybePop re-enters the flow's own PopScope.
          onExit: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
