import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/motion/studio_page_route.dart';
import '../../../../shared/widgets/morph_sheet.dart';
import '../../../../shared/widgets/squircle_tile.dart';
import '../../application/pass_ingest_service.dart';
import '../../domain/pass_ingest.dart';
import 'pass_ingest_feedback.dart';
import 'pnr_entry_screen.dart';

/// Opens the Passes-tab add flow: category → method → PNR screen or picker.
///
/// Category and method are steps of one morphing sheet, so choosing "Trains"
/// grows the sheet in place instead of dismissing it and opening another.
///
/// [context] belongs to the caller, not the sheet: the terminal actions close
/// the sheet first and then push or open a picker, which has to happen on the
/// navigator that outlives it.
Future<void> showAddPassFlow(BuildContext context, WidgetRef ref) {
  return showMorphSheet(
    context: context,
    root: MorphStep(
      id: 'passes',
      title: 'Passes',
      subtitle: 'Add your everyday passes in one place',
      builder: (BuildContext sheetContext, MorphSheetController controller) {
        return SquircleTileGrid(
          columns: 3,
          tiles: <Widget>[
            SquircleTile(
              label: 'Trains',
              iconAsset: AppAssets.passIconTrain,
              onTap: () => controller.push(
                _methodStep(context, ref, PassInputCategory.train),
              ),
            ),
            // Mockup said "Bus / Public Transport", but that wraps to four
            // lines at the real tile width, and `bus` is the only transit
            // category the server actually classifies.
            SquircleTile(
              label: 'Bus',
              iconAsset: AppAssets.passIconBus,
              onTap: () => controller.push(
                _methodStep(context, ref, PassInputCategory.bus),
              ),
            ),
            // Flights, Events and More have no PassInputCategory and no server
            // route. They are shown so the grid reads as the finished shape,
            // but a tap would post an unclassifiable upload.
            const SquircleTile(
              label: 'Flights',
              iconAsset: AppAssets.passIconPlane,
              soon: true,
            ),
            SquircleTile(
              label: 'Movies',
              iconAsset: AppAssets.passIconTicket,
              onTap: () => controller.push(
                _methodStep(context, ref, PassInputCategory.movie),
              ),
            ),
            const SquircleTile(
              label: 'Events',
              iconAsset: AppAssets.passIconEvents,
              soon: true,
            ),
            const SquircleTile(
              label: 'More',
              iconAsset: AppAssets.passIconMore,
              soon: true,
            ),
          ],
        );
      },
    ),
  );
}

/// How the ticket gets in: PNR (train only), photo, or PDF.
MorphStep _methodStep(
  BuildContext context,
  WidgetRef ref,
  PassInputCategory category,
) {
  final bool train = category == PassInputCategory.train;
  return MorphStep(
    id: 'method-${category.name}',
    title: switch (category) {
      PassInputCategory.train => 'Add a train pass',
      PassInputCategory.bus => 'Add a bus pass',
      PassInputCategory.movie => 'Add a movie pass',
    },
    subtitle: train
        ? 'IRCTC PNR, or a photo / PDF of the ticket'
        : 'Photo or PDF — we read the details on the server',
    builder: (BuildContext sheetContext, MorphSheetController controller) {
      void choose(PassInputSource source) {
        controller.close();
        _handleSource(context, ref, category, source);
      }

      return SquircleTileGrid(
        columns: 3,
        tiles: <Widget>[
          if (train)
            SquircleTile(
              label: 'Enter PNR',
              iconAsset: AppAssets.passIconPnr,
              onTap: () => choose(PassInputSource.pnr),
            ),
          SquircleTile(
            label: 'Photo',
            iconAsset: AppAssets.passIconCamera,
            onTap: () => choose(PassInputSource.photo),
          ),
          SquircleTile(
            label: 'PDF',
            iconAsset: AppAssets.passIconFile,
            onTap: () => choose(PassInputSource.pdf),
          ),
        ],
      );
    },
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
    barrierDismissible: true,
    builder: (BuildContext ctx) => const Center(
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
