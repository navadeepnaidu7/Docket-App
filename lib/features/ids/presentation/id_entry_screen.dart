import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../shared/prompt_flow/prompt_flow_controller.dart';
import '../../../shared/prompt_flow/prompt_flow_screen.dart';
import '../../../shared/prompt_flow/prompt_step.dart';
import '../../../shared/prompt_flow/widgets/prompt_inputs.dart';
import '../../../shared/prompt_flow/widgets/prompt_review.dart';
import '../../../shared/prompt_flow/widgets/prompt_slot_input.dart';
import '../../../shared/widgets/completion_celebration.dart';
import '../../dashboard/application/wallet_order_provider.dart';
import '../application/id_draft_controller.dart';
import '../application/id_list_provider.dart';
import '../application/id_scanner_service.dart';
import '../domain/attachment_limits.dart';
import '../domain/id_document.dart';
import '../domain/id_document_catalog.dart';
import 'flow/id_prompt_flow.dart';
import 'id_scanner_screen.dart';

class IdEntryScreen extends ConsumerStatefulWidget {
  const IdEntryScreen({super.key, required this.type});

  final IdDocumentType type;

  @override
  ConsumerState<IdEntryScreen> createState() => _IdEntryScreenState();
}

class _IdEntryScreenState extends ConsumerState<IdEntryScreen> {
  late final PromptFlowController _flow;

  /// Path of the photo the scanner captured, kept so the original can be
  /// attached to the saved record.
  ///
  /// The card face renders a base64 copy of this image, but that field is a
  /// thumbnail for the card, not the document copy the user came for. The file
  /// itself lives in a temp directory the OS may reap, so it is only good until
  /// save, which is when the attachment store copies it.
  String? _scanCapturedPath;

  bool get _isPan => widget.type == IdDocumentType.pan;

  String get _docLabel => IdDocumentCatalog.titleFor(widget.type);

  @override
  void initState() {
    super.initState();
    _flow = PromptFlowController(
      steps: buildIdFlow(widget.type),
      initialFlags: <String, bool>{IdFlag.isPan: _isPan},
      onCommit: (_) => _mirrorDraft(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(idDraftProvider.notifier).reset(widget.type);
    });
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  void _mirrorDraft() {
    final PromptFlowState s = _flow.state;
    final IdDocument current = ref.read(idDraftProvider);
    ref
        .read(idDraftProvider.notifier)
        .replaceWith(
          current.copyWith(
            holderName: s.value(IdField.name),
            documentNumber: s.value(IdField.number),
            dateOfBirth: s.value(IdField.dateOfBirth),
            fatherName: s.value(IdField.fatherName),
            address: s.value(IdField.address),
            gender: s.value(IdField.gender),
          ),
        );
  }

  void _advanceWhenFilled(String stepId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_flow.current.id != stepId) return;
      if (_flow.next()) HapticService.select();
    });
  }

  Future<void> _openScanner() async {
    final IdScanResult? result = await Navigator.of(context).push<IdScanResult>(
      MaterialPageRoute<IdScanResult>(
        builder: (_) => IdScannerScreen(type: widget.type),
      ),
    );
    if (result == null || !mounted) return;

    void put(String id, String value) {
      if (value.trim().isEmpty) return;
      _flow.setValue(id, value, source: FieldSource.scanned);
    }

    put(IdField.name, result.holderName);
    put(IdField.number, result.documentNumber);
    put(IdField.dateOfBirth, result.dateOfBirth);
    put(IdField.fatherName, result.fatherName);
    put(IdField.address, result.address);
    put(IdField.gender, result.gender);
    _mirrorDraft();

    ref.read(idDraftProvider.notifier).updateQrImageBase64(result.qrCodeData);
    _scanCapturedPath = result.capturedImagePath.isEmpty
        ? null
        : result.capturedImagePath;
    if (result.capturedImagePath.isNotEmpty) {
      try {
        final List<int> bytes = await File(
          result.capturedImagePath,
        ).readAsBytes();
        ref.read(idDraftProvider.notifier).updateImagePath(base64Encode(bytes));
      } catch (_) {
        ref
            .read(idDraftProvider.notifier)
            .updateImagePath(result.capturedImagePath);
      }
    }

    if (!mounted) return;
    _flow.setPath(PromptPath.scan);
    _flow.jumpTo(IdField.review, returnTo: IdField.method);
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

  void _onPrimary() {
    if (_flow.current.id == IdField.review) {
      _save();
      return;
    }
    if (_flow.current.id == IdField.method) return;
    _flow.next();
  }

  void _save() {
    _mirrorDraft();
    final PromptFlowState s = _flow.state;
    if (s.value(IdField.name).trim().isEmpty &&
        s.value(IdField.number).trim().isEmpty) {
      _flow.jumpTo(IdField.name, returnTo: IdField.review);
      return;
    }

    final IdDocument doc = ref.read(idDraftProvider);
    HapticService.success();
    SoundService.success();
    ref.read(idListProvider.notifier).addDocument(doc);
    ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(doc.id);
    _attachScanOriginal(doc.id);
    showWalletSaveCelebration(context);
  }

  /// Keeps the scanned original as the record's first attachment.
  ///
  /// Deliberately not awaited: the ID is already saved and the celebration
  /// should not wait on an encrypt-and-copy. A failure here is silent by
  /// design -- the card saved fine, and there is nothing the user could
  /// usefully do about a copy that did not stick. They can still add it by
  /// hand from the tray.
  void _attachScanOriginal(String docId) {
    final String? path = _scanCapturedPath;
    if (path == null) return;
    _scanCapturedPath = null;

    unawaited(
      ref
          .read(idListProvider.notifier)
          .addAttachment(docId, File(path), source: 'scan')
          .catchError(
            (_) => const AttachFailure(
              AttachRejection.ioError,
              'Could not attach the scanned copy.',
            ),
          ),
    );
  }

  Widget _buildStep(BuildContext context, PromptStep step) {
    if (step.id == IdField.method) return _methodStep();
    if (step.id == IdField.review) return _reviewStep();

    if (step.id == IdField.number || step.kind == PromptStepKind.date) {
      final String stepId = step.id;
      final bool aadhaarNumber = stepId == IdField.number && !_isPan;
      return PromptSlotInput(
        key: ValueKey<String>(stepId),
        value: _flow.state.value(stepId),
        label: step.label ?? stepId,
        isDate: step.kind == PromptStepKind.date,
        length: stepId == IdField.number ? (_isPan ? 10 : 12) : null,
        digitsOnly: aadhaarNumber || step.kind == PromptStepKind.date,
        keyboardType: aadhaarNumber || step.kind == PromptStepKind.date
            ? TextInputType.number
            : TextInputType.text,
        hasError: _flow.currentError != null,
        onChanged: (String value) => _flow.setValue(stepId, value),
        onSubmitted: _onPrimary,
        onComplete: () => _advanceWhenFilled(stepId),
      );
    }

    if (step.kind == PromptStepKind.choice) {
      return PromptChoiceList(
        choices: step.choices,
        value: _flow.state.value(step.id),
        onChanged: (String v) {
          _flow.setValue(step.id, v);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_flow.current.id == step.id) _flow.next();
          });
        },
      );
    }

    return PromptTextInput(
      step: step,
      value: _flow.state.value(step.id),
      hasError: _flow.currentError != null,
      onChanged: (String v) => _flow.setValue(step.id, v),
      onSubmitted: _onPrimary,
    );
  }

  Widget _methodStep() {
    return Column(
      children: <Widget>[
        PromptOptionTile(
          title: 'Scan $_docLabel',
          subtitle: 'Camera — auto-fill fields',
          icon: Icons.document_scanner_rounded,
          emphasis: true,
          onTap: () => _choosePath(PromptPath.scan),
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
      onEdit: (String stepId) => _flow.jumpTo(stepId, returnTo: IdField.review),
      rows: <PromptReviewRow>[
        row(IdField.name, 'Name'),
        row(IdField.number, _isPan ? 'PAN' : 'Aadhaar'),
        row(IdField.dateOfBirth, 'Date of birth'),
        if (_isPan) row(IdField.fatherName, "Father's name"),
        if (!_isPan) ...<PromptReviewRow>[
          row(IdField.gender, 'Gender'),
          row(IdField.address, 'Address'),
        ],
      ],
    );
  }

  String get _primaryLabel {
    if (_flow.current.id == IdField.review) return 'Save to wallet';
    return 'Next';
  }

  String? get _secondaryLabel {
    final PromptStep step = _flow.current;
    if (step.skippable) return 'Skip for now';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flow,
      builder: (BuildContext context, Widget? _) {
        final String id = _flow.current.id;
        final bool isMethod = id == IdField.method;
        final bool isReview = id == IdField.review;

        return PromptFlowScreen(
          controller: _flow,
          minimal: !isMethod && !isReview,
          stepBuilder: _buildStep,
          primaryLabel: _primaryLabel,
          onPrimary: _onPrimary,
          showPrimary: !isMethod,
          secondaryLabel: _secondaryLabel,
          onSecondary: _flow.skip,
          onExit: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
