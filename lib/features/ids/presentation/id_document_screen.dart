import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../application/attachment_providers.dart';
import '../application/id_list_provider.dart';
import '../domain/id_attachment.dart';
import '../domain/id_document.dart';
import '../domain/id_document_catalog.dart';
import 'id_document_ui.dart';
import 'id_entry_screen.dart';
import 'id_share_screen.dart';

Map<String, String> idDocumentFields(IdDocument document) => {
  'Name': document.holderName,
  document.type == IdDocumentType.pan ? 'PAN number' : 'Aadhaar number':
      document.documentNumber,
  'Date of birth': document.dateOfBirth,
  if (document.type == IdDocumentType.pan) "Father's name": document.fatherName,
  if (document.type == IdDocumentType.aadhaar) ...{
    'Gender': document.gender,
    'Address': document.address,
  },
};

String idOriginalLabel(IdAttachment attachment, int index) =>
    attachment.label.isNotEmpty
    ? attachment.label
    : attachment.kind == IdAttachmentKind.pdf
    ? 'PDF'
    : 'Image ${index + 1}';

class IdDocumentScreen extends ConsumerStatefulWidget {
  const IdDocumentScreen({super.key, required this.documentId});
  final String documentId;
  @override
  ConsumerState<IdDocumentScreen> createState() => _IdDocumentScreenState();
}

class _IdDocumentScreenState extends ConsumerState<IdDocumentScreen> {
  bool _picking = false;
  String? _copied;
  int _page = 0;

  Future<void> _copy(String label, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      HapticService.select();
      setState(() => _copied = label);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted && _copied == label) setState(() => _copied = null);
    } catch (_) {
      if (mounted) {
        await showIdMessage(context, 'Could not copy', 'Please try again.');
      }
    }
  }

  Future<void> _add(IdDocument document) async {
    if (_picking) return;
    setState(() => _picking = true);
    File? cameraFile;
    try {
      final choice = await showCupertinoModalPopup<int>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Add an original'),
          actions: [
            for (final (i, label) in [
              (0, 'Take a photo'),
              (1, 'Choose from Photos'),
              (2, 'Choose from Files'),
            ])
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(i),
                child: Text(label),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      if (choice == null || !mounted) return;
      String? path;
      if (choice == 2) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
        );
        path = result?.files.firstOrNull?.path;
      } else {
        path = (await ImagePicker().pickImage(
          source: choice == 0 ? ImageSource.camera : ImageSource.gallery,
        ))?.path;
        if (choice == 0 && path != null) cameraFile = File(path);
      }
      if (path != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IdEntryScreen(
              type: document.type,
              existingDocument: document,
              initialFiles: [path!],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not add copy',
          'Please try another photo or file.',
        );
      }
    } finally {
      if (cameraFile != null) {
        try {
          await cameraFile.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _remove(IdDocument document, IdAttachment attachment) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Remove this copy?'),
        message: const Text('The ID and its other copies stay in your wallet.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove copy'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(idListProvider.notifier)
          .removeAttachment(document.id, attachment.id);
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Copy kept',
          'The change could not be saved. Please retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = ref
        .watch(idListProvider)
        .where((d) => d.id == widget.documentId)
        .firstOrNull;
    if (document == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This ID is no longer in your wallet.')),
      );
    }
    final originals = document.attachments;
    final fields = idDocumentFields(document);
    final scheme = Theme.of(context).colorScheme;
    final index = originals.isEmpty ? 0 : _page.clamp(0, originals.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(IdDocumentCatalog.titleFor(document.type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IdEntryScreen(
                  type: document.type,
                  existingDocument: document,
                ),
              ),
            ),
            child: const Text('Edit'),
          ),
          IconButton(
            tooltip: 'Share ID',
            icon: const Icon(CupertinoIcons.share),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IdShareScreen(documentId: document.id),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            document.holderName.isEmpty ? 'Your document' : document.holderName,
            style: AppFonts.ui(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stored on this device',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Originals',
                  style: AppFonts.ui(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _picking ? null : () => _add(document),
                child: Text(_picking ? 'Opening…' : 'Add a copy'),
              ),
            ],
          ),
          if (originals.isEmpty)
            IdSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Keep the front, back or original PDF here. Copies stay encrypted on your device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          else ...[
            AspectRatio(
              aspectRatio: 1.5,
              child: PageView.builder(
                itemCount: originals.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: AppTheme.surface(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IdOriginalViewer(
                            documentId: document.id,
                            attachments: originals,
                            initialIndex: i,
                          ),
                        ),
                      ),
                      child: _OriginalThumbnail(
                        key: ValueKey(originals[i].id),
                        documentId: document.id,
                        attachment: originals[i],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${idOriginalLabel(originals[index], index)} · ${index + 1} of ${originals.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _remove(document, originals[index]),
                  child: const Text('Remove copy'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Details',
              style: AppFonts.ui(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IdSection(
            children: [
              for (final entry in fields.entries)
                InkWell(
                  onTap: entry.value.isEmpty
                      ? null
                      : () => _copy(entry.key, entry.value),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                entry.value.isEmpty ? 'Not added' : entry.value,
                                style: AppFonts.ui(
                                  fontSize: 17,
                                  height: 1.35,
                                  color: entry.value.isEmpty
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (entry.value.isNotEmpty)
                          ExcludeSemantics(
                            child: Icon(
                              _copied == entry.key
                                  ? CupertinoIcons.checkmark
                                  : CupertinoIcons.doc_on_doc,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _copied == null ? 'Tap a detail to copy it.' : 'Copied $_copied',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OriginalThumbnail extends ConsumerStatefulWidget {
  const _OriginalThumbnail({
    super.key,
    required this.documentId,
    required this.attachment,
  });
  final String documentId;
  final IdAttachment attachment;
  @override
  ConsumerState<_OriginalThumbnail> createState() => _OriginalThumbnailState();
}

class _OriginalThumbnailState extends ConsumerState<_OriginalThumbnail> {
  late final _bytes = ref
      .read(attachmentStoreProvider)
      .resolveBytes(widget.documentId, widget.attachment);
  @override
  Widget build(BuildContext context) {
    if (widget.attachment.kind == IdAttachmentKind.pdf) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.doc_text, size: 38),
            SizedBox(height: 12),
            Text('Open original PDF'),
            SizedBox(height: 4),
            Text('All pages · zoom and read'),
          ],
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not read copy'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.contain,
          cacheWidth: 1000,
          errorBuilder: (_, _, _) =>
              const Center(child: Text('Tap to open original')),
        );
      },
    );
  }
}

class IdOriginalViewer extends ConsumerStatefulWidget {
  const IdOriginalViewer({
    super.key,
    required this.documentId,
    required this.attachments,
    this.initialIndex = 0,
  });
  final String documentId;
  final List<IdAttachment> attachments;
  final int initialIndex;
  @override
  ConsumerState<IdOriginalViewer> createState() => _IdOriginalViewerState();
}

class _IdOriginalViewerState extends ConsumerState<IdOriginalViewer> {
  late int _index = widget.initialIndex;
  late final _controller = PageController(initialPage: _index);
  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${idOriginalLabel(widget.attachments[_index], _index)} · copy ${_index + 1} of ${widget.attachments.length}',
      ),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.attachments.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) => _OriginalPage(
        key: ValueKey(widget.attachments[i].id),
        documentId: widget.documentId,
        attachment: widget.attachments[i],
      ),
    ),
    bottomNavigationBar: widget.attachments.length < 2
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                    child: const Text('Previous copy'),
                  ),
                  TextButton(
                    onPressed: _index == widget.attachments.length - 1
                        ? null
                        : () => _goTo(_index + 1),
                    child: const Text('Next copy'),
                  ),
                ],
              ),
            ),
          ),
  );
}

class _OriginalPage extends ConsumerStatefulWidget {
  const _OriginalPage({
    super.key,
    required this.documentId,
    required this.attachment,
  });
  final String documentId;
  final IdAttachment attachment;
  @override
  ConsumerState<_OriginalPage> createState() => _OriginalPageState();
}

class _OriginalPageState extends ConsumerState<_OriginalPage> {
  late final _bytes = ref
      .read(attachmentStoreProvider)
      .resolveBytes(widget.documentId, widget.attachment);
  late final _passwordProvider = () {
    var retry = false;
    return () async {
      if (!mounted) return null;
      final password = await requestIdPdfPassword(context, retry: retry);
      retry = true;
      return password;
    };
  }();
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('Could not open this copy. Please try again.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CupertinoActivityIndicator());
      }
      if (widget.attachment.kind == IdAttachmentKind.pdf) {
        return PdfViewer.data(
          snapshot.data!,
          sourceName: 'private-original-${widget.attachment.id}',
          passwordProvider: _passwordProvider,
        );
      }
      return InteractiveViewer(
        minScale: 1,
        maxScale: 8,
        child: Center(
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('This image format could not be displayed.'),
          ),
        ),
      );
    },
  );
}
