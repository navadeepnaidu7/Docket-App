import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

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
import '../application/id_list_provider.dart';
import '../application/id_scanner_service.dart';
import '../application/id_media_service.dart';
import '../../../core/validation/document_validators.dart';
import '../domain/id_attachment.dart';
import 'id_image_editor.dart';
import 'id_document_ui.dart';
import 'id_document_screen.dart';
import '../domain/attachment_limits.dart';
import '../domain/id_document.dart';
import '../domain/id_document_catalog.dart';
import 'flow/id_prompt_flow.dart';
import 'id_scanner_screen.dart';

class IdEntryScreen extends ConsumerStatefulWidget {
  const IdEntryScreen({
    super.key,
    required this.type,
    this.existingDocument,
    this.initialFiles = const [],
  });

  final IdDocumentType type;
  final IdDocument? existingDocument;
  final List<String> initialFiles;

  @override
  ConsumerState<IdEntryScreen> createState() => _IdEntryScreenState();
}

class _IdEntryScreenState extends ConsumerState<IdEntryScreen> {
  late final PromptFlowController _flow;
  late IdDocument _draft;

  /// Path of the photo the scanner captured, kept so the original can be
  /// attached to the saved record.
  ///
  /// The card face renders a base64 copy of this image, but that field is a
  /// thumbnail for the card, not the document copy the user came for. The file
  /// itself lives in a temp directory the OS may reap, so it is only good until
  /// save, which is when the attachment store copies it.
  final _session = IdImportSession();
  final List<IdOriginalInput> _originals = [];
  bool _busy = false;
  bool _choosing = false;

  bool get _isPan => widget.type == IdDocumentType.pan;

  String get _docLabel => IdDocumentCatalog.titleFor(widget.type);

  @override
  void initState() {
    super.initState();
    _draft = widget.existingDocument ?? IdDocument.empty(widget.type);
    _flow = PromptFlowController(
      steps: buildIdFlow(widget.type),
      initialFlags: <String, bool>{IdFlag.isPan: _isPan},
      onCommit: (_) => _mirrorDraft(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing = widget.existingDocument;
      if (existing != null) {
        _putResult(
          IdScanResult(
            type: existing.type,
            holderName: existing.holderName,
            documentNumber: existing.documentNumber,
            dateOfBirth: existing.dateOfBirth,
            fatherName: existing.fatherName,
            address: existing.address,
            gender: existing.gender,
          ),
          scanned: false,
        );
        _flow.jumpTo(IdField.review, returnTo: IdField.method);
      }
      if (widget.initialFiles.isNotEmpty) _importInitialFiles();
    });
  }

  @override
  void dispose() {
    unawaited(_session.close());
    _flow.dispose();
    super.dispose();
  }

  void _mirrorDraft() {
    final PromptFlowState s = _flow.state;
    _draft = _draft.copyWith(
      holderName: s.value(IdField.name),
      documentNumber: s.value(IdField.number),
      dateOfBirth: s.value(IdField.dateOfBirth),
      fatherName: s.value(IdField.fatherName),
      address: s.value(IdField.address),
      gender: s.value(IdField.gender),
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
    if (_busy || _choosing) return;
    _choosing = true;
    try {
      final IdScanResult? result = await Navigator.of(context)
          .push<IdScanResult>(
            MaterialPageRoute<IdScanResult>(
              builder: (_) => IdScannerScreen(type: widget.type),
            ),
          );
      if (result == null || !mounted) return;

      await _importFile(
        File(result.capturedImagePath),
        scanned: result,
        source: 'scan',
      );
      try {
        await File(result.capturedImagePath).delete();
      } catch (_) {
        /* Camera cache cleanup. */
      }
    } finally {
      _choosing = false;
    }
  }

  void _putResult(IdScanResult result, {bool scanned = true}) {
    void put(String id, String value) {
      if (value.trim().isEmpty) return;
      if (scanned && _flow.state.value(id).trim().isNotEmpty) return;
      _flow.setValue(
        id,
        value,
        source: scanned ? FieldSource.scanned : FieldSource.typed,
      );
    }

    put(IdField.name, result.holderName);
    put(IdField.number, result.documentNumber);
    put(IdField.dateOfBirth, result.dateOfBirth);
    put(IdField.fatherName, result.fatherName);
    put(IdField.address, result.address);
    put(IdField.gender, result.gender);
    _mirrorDraft();

    if (result.qrCodeData.isNotEmpty) {
      _draft = _draft.copyWith(qrImageBase64: result.qrCodeData);
    }
  }

  Future<void> _importInitialFiles() async {
    for (final path in widget.initialFiles) {
      if (!mounted) break;
      await _importFile(File(path), source: 'shared');
    }
  }

  Future<void> _pickFile({bool gallery = false}) async {
    if (_busy || _choosing) return;
    _choosing = true;
    try {
      String? path;
      if (gallery) {
        path = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
        ))?.path;
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
        );
        path = picked?.files.firstOrNull?.path;
      }
      if (path != null && mounted) await _importFile(File(path));
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not open file',
          'Please try again from Photos or Files.',
        );
      }
    } finally {
      _choosing = false;
    }
  }

  Future<void> _importFile(
    File file, {
    IdScanResult? scanned,
    String source = 'import',
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final original = await _session.keepOriginal(file);
      final kind = kindForExtension(original.path)!;
      final existing = widget.existingDocument?.attachments ?? <IdAttachment>[];
      final imageCount =
          existing.where((a) => a.kind == IdAttachmentKind.image).length +
          _originals
              .where(
                (a) => kindForExtension(a.file.path) == IdAttachmentKind.image,
              )
              .length;
      final pdfCount =
          existing.where((a) => a.kind == IdAttachmentKind.pdf).length +
          _originals
              .where(
                (a) => kindForExtension(a.file.path) == IdAttachmentKind.pdf,
              )
              .length;
      if ((kind == IdAttachmentKind.image &&
              imageCount >= kMaxImageAttachments) ||
          (kind == IdAttachmentKind.pdf && pdfCount >= kMaxPdfAttachments)) {
        throw const FormatException('Each ID can hold 3 images and 1 PDF.');
      }
      IdScanResult? result = scanned;
      if (result == null && kind == IdAttachmentKind.pdf) {
        var retry = false;
        final pdf = await openIdPdf(
          await original.readAsBytes(),
          passwordProvider: () async {
            if (!mounted) return null;
            final password = await requestIdPdfPassword(context, retry: retry);
            retry = true;
            return password;
          },
        );
        try {
          if (pdf.pages.isEmpty) {
            throw const FormatException('This PDF has no pages.');
          }
          final text = (await pdf.pages.first.loadText())?.fullText ?? '';
          result = IdScannerService.extractText(text, widget.type);
          if (result == null || result.documentNumber.isEmpty) {
            final working = await _session.workingImage(
              await rasterIdPage(pdf.pages.first),
            );
            result = await IdScannerService.processImage(
              working.path,
              widget.type,
            );
          }
        } finally {
          await pdf.dispose();
        }
      } else if (result == null) {
        final bytes = await normaliseIdImage(await original.readAsBytes());
        if (!mounted) return;
        final edited = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(builder: (_) => IdImageEditor(bytes: bytes)),
        );
        if (edited == null) return;
        final working = await _session.workingImage(edited);
        result = await IdScannerService.processImage(working.path, widget.type);
      }
      if (!mounted) return;
      if (result != null) {
        final currentNumber = normaliseIdNumber(_draft.documentNumber);
        final scannedNumber = normaliseIdNumber(result.documentNumber);
        if (currentNumber.isNotEmpty &&
            scannedNumber.isNotEmpty &&
            currentNumber != scannedNumber) {
          final keep = await showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Check this copy'),
              content: const Text(
                'The number read from this copy differs from this ID. Does the copy belong here?',
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Keep copy'),
                ),
              ],
            ),
          );
          if (keep != true || !mounted) return;
        }
        _putResult(result);
      }
      _originals.add(
        IdOriginalInput(
          original,
          source: source,
          label: kind == IdAttachmentKind.pdf
              ? 'PDF'
              : imageCount == 0
              ? 'Front'
              : imageCount == 1
              ? 'Back'
              : 'Supporting image',
        ),
      );
      // Card thumbnails stay small; the encrypted attachment retains the full original.
      if (kind == IdAttachmentKind.image && _draft.imagePath.isEmpty) {
        try {
          final thumb = await normaliseIdImage(
            await original.readAsBytes(),
            longEdge: 384,
          );
          if (mounted) _draft = _draft.copyWith(imagePath: base64Encode(thumb));
        } catch (_) {
          /* The original is still available in the document view. */
        }
      }
      if (!mounted) return;
      _flow.setPath(PromptPath.scan);
      _flow.jumpTo(IdField.review, returnTo: IdField.method);
    } catch (error) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not import',
          error is FormatException
              ? error.message.toString()
              : 'The file could not be opened. If it is a locked PDF, check the password and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  Future<void> _save() async {
    if (_busy) return;
    _mirrorDraft();
    final PromptFlowState s = _flow.state;
    if (s.value(IdField.name).trim().isEmpty &&
        s.value(IdField.number).trim().isEmpty) {
      _flow.jumpTo(IdField.name, returnTo: IdField.review);
      return;
    }

    final IdDocument doc = _draft;
    final numberError = _isPan
        ? DocumentValidators.validatePanNumber(doc.documentNumber)
        : DocumentValidators.validateAadhaarNumber(doc.documentNumber);
    final birthYear = int.tryParse(doc.dateOfBirth);
    final birthError = doc.dateOfBirth.length == 4
        ? (birthYear == null ||
                  birthYear < 1000 ||
                  birthYear > DateTime.now().year
              ? 'Enter a valid birth year.'
              : null)
        : DocumentValidators.validateDateOfBirth(doc.dateOfBirth);
    if (numberError != null || birthError != null) {
      await showIdMessage(
        context,
        'Check the details',
        numberError ?? birthError!,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(idListProvider.notifier)
          .saveDocumentDurably(
            doc,
            originals: _originals,
            isEditing: widget.existingDocument != null,
          );
      if (!mounted) return;
      HapticService.success();
      if (widget.existingDocument != null) {
        Navigator.of(context).pop();
        return;
      }
      SoundService.success();
      ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(doc.id);
      showWalletSaveCelebration(
        context,
        successTitle: switch (doc.type) {
          IdDocumentType.pan => 'Your PAN card is added',
          IdDocumentType.aadhaar => 'Your Aadhaar card is added',
        },
        successDescription: "It's stored on this device.",
      );
    } on DuplicateIdException catch (error) {
      if (!mounted) return;
      final open = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Already in your wallet'),
          content: const Text(
            'An ID with this number is already saved. Open it to add copies or edit its details.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open existing'),
            ),
          ],
        ),
      );
      if (open == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IdDocumentScreen(documentId: error.document.id),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Not saved yet',
          'Your draft is still here. Free some storage if needed, then try saving again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          title: 'Choose from Photos',
          subtitle: 'Import a photo of your ID',
          icon: CupertinoIcons.photo,
          onTap: () => _pickFile(gallery: true),
        ),
        PromptOptionTile(
          title: 'Import a file',
          subtitle: 'Image or PDF, including locked PDFs',
          icon: CupertinoIcons.folder,
          onTap: _pickFile,
        ),
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
        needsReview: s.sourceOf(id) == FieldSource.scanned,
        missing: value.trim().isEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_flow.state.path == PromptPath.scan)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Check every scanned field against your original before saving.',
            ),
          ),
        PromptReviewCard(
          onEdit: (String stepId) =>
              _flow.jumpTo(stepId, returnTo: IdField.review),
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
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _originals.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_originals[i].label),
            subtitle: const Text('Original will be stored encrypted'),
            trailing: IconButton(
              tooltip: 'Remove from draft',
              onPressed: _busy
                  ? null
                  : () => setState(() => _originals.removeAt(i)),
              icon: const Icon(CupertinoIcons.minus_circle),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => _pickFile(),
          child: const Text('Add front, back or PDF'),
        ),
      ],
    );
  }

  String get _primaryLabel {
    if (_busy) return 'Saving…';
    if (_flow.current.id == IdField.review) {
      return widget.existingDocument == null
          ? 'Save to wallet'
          : 'Save changes';
    }
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

        return PopScope(
          canPop: !_busy,
          child: AbsorbPointer(
            absorbing: _busy,
            child: Stack(
              children: [
                PromptFlowScreen(
                  controller: _flow,
                  minimal: !isMethod && !isReview,
                  stepBuilder: _buildStep,
                  primaryLabel: _primaryLabel,
                  primaryEnabled: !_busy,
                  onPrimary: _onPrimary,
                  showPrimary: !isMethod,
                  secondaryLabel: _secondaryLabel,
                  onSecondary: _flow.skip,
                  onExit: () => Navigator.of(context).pop(),
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55000000),
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
