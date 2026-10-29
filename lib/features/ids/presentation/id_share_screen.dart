import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/app_theme.dart';
import '../application/attachment_providers.dart';
import '../application/id_list_provider.dart';
import '../application/id_share_service.dart';
import '../domain/id_attachment.dart';
import '../domain/id_document.dart';
import 'id_document_screen.dart';
import 'id_document_ui.dart';
import 'id_redaction_screen.dart';

enum _ShareMode { details, original, redacted }

class IdShareScreen extends ConsumerStatefulWidget {
  const IdShareScreen({super.key, required this.documentId});
  final String documentId;
  @override
  ConsumerState<IdShareScreen> createState() => _IdShareScreenState();
}

class _IdShareScreenState extends ConsumerState<IdShareScreen> {
  _ShareMode _mode = _ShareMode.details;
  final Set<String> _selected = {};
  bool _initialised = false;
  bool _maskNumber = true;
  int _original = 0;
  bool _busy = false;

  String _text(IdDocument document) {
    final fields = idDocumentFields(document);
    return fields.entries
        .where((e) => _selected.contains(e.key) && e.value.isNotEmpty)
        .map((e) {
          var value = e.value;
          if (_maskNumber &&
              document.type == IdDocumentType.aadhaar &&
              e.key == 'Aadhaar number') {
            final compact = value.replaceAll(RegExp(r'\s'), '');
            if (compact.length > 4) {
              value = 'XXXX XXXX ${compact.substring(compact.length - 4)}';
            }
          }
          return '${e.key}: $value';
        })
        .join('\n');
  }

  Future<void> _preview(IdDocument document) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_mode == _ShareMode.details) {
        final text = _text(document);
        if (text.isEmpty) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                IdExportPreview(artifact: IdShareArtifact.text(text)),
          ),
        );
      } else {
        final attachment = document
            .attachments[_original.clamp(0, document.attachments.length - 1)];
        final bytes = await ref
            .read(attachmentStoreProvider)
            .resolveBytes(document.id, attachment);
        if (!mounted) return;
        if (_mode == _ShareMode.redacted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IdRedactionScreen(
                bytes: bytes,
                isPdf: attachment.kind == IdAttachmentKind.pdf,
              ),
            ),
          );
        } else {
          final extension = attachment.kind == IdAttachmentKind.pdf
              ? 'pdf'
              : await _imageExtension(bytes);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IdExportPreview(
                artifact: IdShareArtifact.file(
                  bytes,
                  extension: extension,
                  mimeType: extension == 'pdf'
                      ? 'application/pdf'
                      : 'image/${extension == 'jpg' ? 'jpeg' : extension}',
                ),
                original: true,
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not prepare share',
          'Your saved original is unchanged. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _imageExtension(Uint8List bytes) async {
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    return 'heic';
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
        body: const Center(child: Text('This ID is no longer available.')),
      );
    }
    final fields = idDocumentFields(document);
    if (!_initialised) {
      _initialised = true;
      _selected.addAll(
        fields.entries
            .where((e) => e.value.isNotEmpty)
            .take(2)
            .map((e) => e.key),
      );
    }
    final text = _text(document);
    return Scaffold(
      appBar: AppBar(title: const Text('Share ID')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose what leaves your wallet.',
            style: AppFonts.ui(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<_ShareMode>(
              groupValue: _mode,
              children: const {
                _ShareMode.details: Text('Details'),
                _ShareMode.original: Text('Original'),
                _ShareMode.redacted: Text('Redact'),
              },
              onValueChanged: (value) {
                if (_busy) return;
                if (value != null) setState(() => _mode = value);
              },
            ),
          ),
          const SizedBox(height: 24),
          if (_mode == _ShareMode.details) ...[
            IdSection(
              children: [
                for (final entry in fields.entries.where(
                  (e) => e.value.isNotEmpty,
                ))
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(entry.key),
                    value: _selected.contains(entry.key),
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _selected.add(entry.key);
                      } else {
                        _selected.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
            if (document.type == IdDocumentType.aadhaar &&
                _selected.contains('Aadhaar number'))
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show only the last 4 digits'),
                value: _maskNumber,
                onChanged: (value) => setState(() => _maskNumber = value),
              ),
            const SizedBox(height: 20),
            const Text('Text to be shared'),
            const SizedBox(height: 10),
            IdSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    text.isEmpty
                        ? 'Select the details you want to include.'
                        : text,
                    style: AppFonts.ui(fontSize: 16, height: 1.5),
                  ),
                ),
              ],
            ),
          ] else if (document.attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Add an original photo or PDF from the document screen first.',
              ),
            )
          else ...[
            Text(
              _mode == _ShareMode.original
                  ? 'The file is shared exactly as saved, including all PDF pages.'
                  : 'Draw over private information, including QR codes. You can add a purpose watermark to the copy.',
            ),
            const SizedBox(height: 16),
            IdSection(
              children: [
                for (var i = 0; i < document.attachments.length; i++)
                  ListTile(
                    title: Text(idOriginalLabel(document.attachments[i], i)),
                    trailing: _original == i
                        ? const Icon(CupertinoIcons.checkmark, size: 18)
                        : null,
                    onTap: () => setState(() => _original = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _mode == _ShareMode.original
                  ? 'Original PDF passwords and signatures are preserved.'
                  : 'Redaction creates a flattened copy. Your original stays unchanged.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed:
                _busy ||
                    (_mode == _ShareMode.details
                        ? text.isEmpty
                        : document.attachments.isEmpty)
                ? null
                : () => _preview(document),
            child: Text(
              _busy
                  ? 'Preparing…'
                  : _mode == _ShareMode.redacted
                  ? 'Edit sharing copy'
                  : 'Preview share',
            ),
          ),
        ],
      ),
    );
  }
}

class IdExportPreview extends StatefulWidget {
  const IdExportPreview({
    super.key,
    required this.artifact,
    this.original = false,
  });
  final IdShareArtifact artifact;
  final bool original;
  @override
  State<IdExportPreview> createState() => _IdExportPreviewState();
}

class _IdExportPreviewState extends State<IdExportPreview> {
  bool _sharing = false;
  late final _pdfSource =
      'sharing-preview-${DateTime.now().microsecondsSinceEpoch}';
  late final PdfPasswordProvider _passwordProvider = () {
    var retry = false;
    return () async {
      if (!mounted) return null;
      final value = await requestIdPdfPassword(context, retry: retry);
      retry = true;
      return value;
    };
  }();
  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await IdShareService.share(widget.artifact, origin);
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not share',
          'The preview is still here. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artifact = widget.artifact;
    return Scaffold(
      appBar: AppBar(title: const Text('Sharing preview')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                widget.original
                    ? 'This exact original file will be shared.'
                    : 'Only the content shown here will be shared.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: artifact.text != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        artifact.text!,
                        style: AppFonts.ui(fontSize: 18, height: 1.6),
                      ),
                    )
                  : artifact.extension == 'pdf'
                  ? PdfViewer.data(
                      artifact.bytes!,
                      sourceName: _pdfSource,
                      passwordProvider: _passwordProvider,
                    )
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 8,
                      child: Center(
                        child: Image.memory(
                          artifact.bytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (artifact.text != null)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: artifact.text!),
                        );
                        if (context.mounted) {
                          await showIdMessage(
                            context,
                            'Copied',
                            'The preview text is on your clipboard.',
                          );
                        }
                      },
                      child: const Text('Copy text'),
                    ),
                  Builder(
                    builder: (buttonContext) => FilledButton(
                      onPressed: _sharing ? null : () => _share(buttonContext),
                      child: Text(_sharing ? 'Opening share sheet…' : 'Share'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
