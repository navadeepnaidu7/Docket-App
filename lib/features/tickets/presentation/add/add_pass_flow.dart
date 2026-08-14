import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/motion/studio_page_route.dart';
import '../../application/pass_ingest_service.dart';
import '../../domain/pass_ingest.dart';
import 'add_pass_sheet.dart';
import 'pass_ingest_feedback.dart';
import 'pnr_entry_screen.dart';

/// Opens the Passes-tab add flow: category → method → PNR screen or picker.
Future<void> showAddPassFlow(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => AddPassSheet(
      onSelect: (PassInputCategory category) {
        Navigator.of(sheetContext).pop();
        _showMethodSheet(context, ref, category);
      },
    ),
  );
}

void _showMethodSheet(
  BuildContext context,
  WidgetRef ref,
  PassInputCategory category,
) {
  HapticService.confirm();
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => AddPassMethodSheet(
      category: category,
      onSelect: (PassInputSource source) {
        Navigator.of(sheetContext).pop();
        _handleSource(context, ref, category, source);
      },
    ),
  );
}

Future<void> _handleSource(
  BuildContext context,
  WidgetRef ref,
  PassInputCategory category,
  PassInputSource source,
) async {
  switch (source) {
    case PassInputSource.pnr:
      await Navigator.of(context).push(
        studioPageRoute<void>(builder: (_) => const PnrEntryScreen()),
      );
    case PassInputSource.photo:
      await _pickPhoto(context, ref, category);
    case PassInputSource.pdf:
      await _pickFile(context, ref, category, pdfOnly: true);
  }
}

Future<void> _pickPhoto(
  BuildContext context,
  WidgetRef ref,
  PassInputCategory category,
) async {
  final ImageSource? origin = await showCupertinoModalPopup<ImageSource>(
    context: context,
    builder: (BuildContext ctx) => CupertinoActionSheet(
      title: const Text('Photo of the ticket'),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          child: const Text('Take photo'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          child: const Text('Choose from library'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (origin == null || !context.mounted) return;

  final XFile? picked = await ImagePicker().pickImage(
    source: origin,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return;
  await _submitFile(context, ref, File(picked.path), category);
}

Future<void> _pickFile(
  BuildContext context,
  WidgetRef ref,
  PassInputCategory category, {
  required bool pdfOnly,
}) async {
  final FilePickerResult? picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: pdfOnly
        ? const <String>['pdf']
        : PassUpload.fileExtensions,
    withData: false,
  );
  final List<PlatformFile> files = picked?.files ?? const <PlatformFile>[];
  if (files.isEmpty) return;
  final String? path = files.first.path;
  if (path == null || path.isEmpty || !context.mounted) return;
  await _submitFile(context, ref, File(path), category);
}

Future<void> _submitFile(
  BuildContext context,
  WidgetRef ref,
  File file,
  PassInputCategory category,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CupertinoActivityIndicator(),
                SizedBox(height: 14),
                Text('Reading ticket…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  try {
    await ref.read(passIngestServiceProvider).submitFile(
          file: file,
          category: category,
        );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    HapticService.success();
  } on PassIngestException catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    HapticService.error();
    await showPassIngestError(context, e);
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    HapticService.error();
    await showPassIngestError(
      context,
      const PassIngestException(
        PassIngestCode.failed,
        'Could not read that ticket.',
      ),
    );
  }
}
