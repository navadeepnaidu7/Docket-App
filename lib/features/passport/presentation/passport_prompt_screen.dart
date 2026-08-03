import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../shared/prompt_flow/prompt_flow_controller.dart';
import '../../../shared/prompt_flow/prompt_flow_screen.dart';
import '../../../shared/prompt_flow/prompt_step.dart';
import '../../../shared/prompt_flow/widgets/prompt_inputs.dart';
import '../../../shared/prompt_flow/widgets/prompt_review.dart';
import '../../../shared/widgets/completion_celebration.dart';
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
    _flow.dispose();
    super.dispose();
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

    _flow.next();
  }

  void _choosePath(PromptPath path) {
    HapticService.select();
    _flow.setPath(path);
    _flow.next();
  }

  void _save() {
    final PromptFlowState s = _flow.state;

    final PassportProfile profile = PassportProfile(
      name: s.value(PassportField.name).trim(),
      passportNumber: s.value(PassportField.passportNumber).trim(),
      nationality: s.value(PassportField.nationality).trim().toUpperCase(),
      dateOfBirth: s.value(PassportField.dateOfBirth),
      expiryDate: s.value(PassportField.expiryDate),
      imagePath: '',
      mrzRaw: s.value('mrzRaw'),
      photoBase64: s.value('photoBase64'),
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

  Widget _methodStep() {
    final bool chipAvailable = widget.kind == PassportKind.ePassport;

    return Column(
      children: <Widget>[
        PromptOptionTile(
          title: 'Scan the photo page',
          subtitle: 'Camera — reads the machine-readable zone',
          icon: Icons.document_scanner_rounded,
          emphasis: true,
          onTap: () => _choosePath(PromptPath.scan),
        ),
        if (chipAvailable)
          PromptOptionTile(
            title: 'Read the chip',
            subtitle: 'NFC — needs three details first',
            icon: Icons.nfc_rounded,
            onTap: () => _choosePath(PromptPath.chip),
          ),
        PromptOptionTile(
          title: 'Type it in',
          subtitle: 'Enter the details yourself',
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
    if (_flow.isConfirming) return "Yes, that's right";
    return 'Continue';
  }

  String? get _secondaryLabel {
    final PromptStep step = _flow.current;
    if (step.id == PassportField.method) return null;
    if (step.skippable && !_flow.isConfirming) return 'Skip for now';
    return null;
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
          primaryEnabled: !isMethod,
          secondaryLabel: _secondaryLabel,
          onSecondary: _flow.skip,
          onExit: () => Navigator.of(context).maybePop(),
        );
      },
    );
  }
}
