import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_theme.dart';
import '../application/id_media_service.dart';
import '../application/id_share_service.dart';
import 'id_document_ui.dart';
import 'id_share_screen.dart';

class IdRedactionScreen extends StatefulWidget {
  const IdRedactionScreen({
    super.key,
    required this.bytes,
    required this.isPdf,
  });
  final Uint8List bytes;
  final bool isPdf;
  @override
  State<IdRedactionScreen> createState() => _IdRedactionScreenState();
}

class _IdRedactionScreenState extends State<IdRedactionScreen> {
  final _purpose = TextEditingController();
  final _transform = TransformationController();
  final Map<int, List<Rect>> _redactions = {};
  final List<Uint8List> _pages = [];
  final List<double> _ratios = [];
  int _page = 0;
  bool _loading = true;
  bool _working = false;
  bool _zoom = false;
  bool _watermark = false;
  Offset? _start;
  Rect? _draft;
  String? _failure;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _purpose.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _addPage(Uint8List bytes) async {
    final image = await decodeImageFromList(bytes);
    try {
      _pages.add(bytes);
      _ratios.add(image.width / image.height);
    } finally {
      image.dispose();
    }
  }

  Future<void> _load() async {
    try {
      if (widget.isPdf) {
        var retry = false;
        final document = await openIdPdf(
          widget.bytes,
          passwordProvider: () async {
            if (!mounted) return null;
            final result = await requestIdPdfPassword(context, retry: retry);
            retry = true;
            return result;
          },
        );
        try {
          if (document.pages.isEmpty || document.pages.length > 20) {
            throw const FormatException(
              'Redaction supports PDFs with 1–20 pages. You can still share the unchanged original.',
            );
          }
          var total = 0;
          for (final page in document.pages) {
            if (!mounted) return;
            final bytes = await compute(
              _jpeg,
              await rasterIdPage(page, longEdge: 1600),
            );
            total += bytes.length;
            if (total > 35 * 1024 * 1024) {
              throw const FormatException(
                'This PDF is too large to edit on this device.',
              );
            }
            await _addPage(bytes);
          }
        } finally {
          await document.dispose();
        }
      } else {
        await _addPage(await normaliseIdImage(widget.bytes, longEdge: 2000));
      }
    } catch (error) {
      _failure = error is FormatException
          ? error.message.toString()
          : 'Could not open this copy. Check the PDF password and try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _flatten(int page, String watermark) async {
    final codec = await ui.instantiateImageCodec(_pages[page]);
    final frame = await codec.getNextFrame();
    try {
      final width = frame.image.width;
      final height = frame.image.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      canvas.drawImage(frame.image, Offset.zero, Paint());
      for (final rect in _redactions[page] ?? <Rect>[]) {
        // Round outwards to ensure no edge pixels of the hidden content survive.
        final left = (rect.left * width).floorToDouble();
        final top = (rect.top * height).floorToDouble();
        final right = (rect.right * width).ceilToDouble();
        final bottom = (rect.bottom * height).ceilToDouble();
        canvas.drawRect(
          Rect.fromLTRB(left, top, right, bottom),
          Paint()..color = Colors.black,
        );
      }
      if (watermark.isNotEmpty) {
        final text = TextPainter(
          text: TextSpan(
            text: watermark,
            style: AppFonts.ui(
              fontSize: math.max(16, width * .033),
              fontWeight: FontWeight.w600,
              color: const Color(0x60000000),
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        text.layout(maxWidth: width * .85);
        for (final position in [.28, .55, .82]) {
          canvas.save();
          canvas.translate(width / 2, height * position);
          canvas.rotate(-.25);
          text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
          canvas.restore();
        }
        text.dispose();
      }
      final picture = recorder.endRecording();
      final flattened = await picture.toImage(width, height);
      picture.dispose();
      try {
        return (await flattened.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        flattened.dispose();
      }
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  Future<void> _preview() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final now = DateTime.now();
      final date =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final watermark = _watermark
          ? '${_purpose.text.trim()}${_purpose.text.trim().isEmpty ? '' : ' · '}$date'
          : '';
      final rendered = <Uint8List>[];
      var outputSize = 0;
      for (var i = 0; i < _pages.length; i++) {
        if (!mounted) return;
        final flattened = await _flatten(i, watermark);
        final page = widget.isPdf ? await compute(_jpeg, flattened) : flattened;
        outputSize += page.length;
        if (outputSize > 35 * 1024 * 1024) {
          throw const FormatException('The sharing copy is too large.');
        }
        rendered.add(page);
      }
      final bytes = widget.isPdf
          ? await buildRedactedPdf(rendered)
          : rendered.single;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IdExportPreview(
            artifact: IdShareArtifact.file(
              bytes,
              extension: widget.isPdf ? 'pdf' : 'png',
              mimeType: widget.isPdf ? 'application/pdf' : 'image/png',
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not create copy',
          'Your original is unchanged. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prepare copy')),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_failure != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prepare copy')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_failure!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final boxes = _redactions.putIfAbsent(_page, () => []);
    return PopScope(
      canPop: !_working,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Redact copy'),
          actions: [
            TextButton(
              onPressed: _working || boxes.isEmpty
                  ? null
                  : () => setState(() => boxes.removeLast()),
              child: const Text('Undo'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  _zoom
                      ? 'Pinch to inspect. Switch to Draw to hide information.'
                      : 'Drag over information to hide it. Cover QR codes too if they contain private details.',
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: _zoom,
                children: const {false: Text('Draw'), true: Text('Zoom')},
                onValueChanged: (value) {
                  if (_working) return;
                  setState(() {
                    _zoom = value ?? false;
                    _draft = null;
                    _transform.value = Matrix4.identity();
                  });
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: InteractiveViewer(
                    transformationController: _transform,
                    panEnabled: _zoom,
                    scaleEnabled: _zoom,
                    minScale: 1,
                    maxScale: 6,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _ratios[_page],
                        child: LayoutBuilder(
                          builder: (context, box) {
                            Offset normalise(Offset p) => Offset(
                              (p.dx / box.maxWidth).clamp(0, 1),
                              (p.dy / box.maxHeight).clamp(0, 1),
                            );
                            return GestureDetector(
                              dragStartBehavior: DragStartBehavior.down,
                              onPanStart: _zoom || _working
                                  ? null
                                  : (details) => setState(
                                      () => _start = normalise(
                                        details.localPosition,
                                      ),
                                    ),
                              onPanUpdate: _zoom || _working
                                  ? null
                                  : (details) => setState(() {
                                      if (_start != null) {
                                        _draft = Rect.fromPoints(
                                          _start!,
                                          normalise(details.localPosition),
                                        );
                                      }
                                    }),
                              onPanCancel: () => setState(() {
                                _draft = null;
                                _start = null;
                              }),
                              onPanEnd: _zoom || _working
                                  ? null
                                  : (_) => setState(() {
                                      if (_draft != null &&
                                          _draft!.width > .006 &&
                                          _draft!.height > .006) {
                                        boxes.add(_draft!);
                                      }
                                      _draft = null;
                                      _start = null;
                                    }),
                              child: CustomPaint(
                                foregroundPainter: _RedactionPainter([
                                  ...boxes,
                                  ?_draft,
                                ]),
                                child: Image.memory(
                                  _pages[_page],
                                  key: ValueKey(_page),
                                  fit: BoxFit.fill,
                                  gaplessPlayback: false,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_pages.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: _working || _page == 0
                          ? null
                          : () => setState(() {
                              _page--;
                              _draft = null;
                              _transform.value = Matrix4.identity();
                            }),
                      icon: const Icon(CupertinoIcons.chevron_left),
                    ),
                    Text('Page ${_page + 1} of ${_pages.length}'),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: _working || _page == _pages.length - 1
                          ? null
                          : () => setState(() {
                              _page++;
                              _draft = null;
                              _transform.value = Matrix4.identity();
                            }),
                      icon: const Icon(CupertinoIcons.chevron_right),
                    ),
                  ],
                ),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: const Text('Purpose and date watermark'),
                value: _watermark,
                onChanged: _working
                    ? null
                    : (value) => setState(() => _watermark = value),
              ),
              if (_watermark)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _purpose,
                    maxLength: 60,
                    enabled: !_working,
                    decoration: const InputDecoration(
                      hintText: 'For hotel check-in',
                      counterText: '',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _working ? null : _preview,
                    child: Text(
                      _working ? 'Creating copy…' : 'Preview sharing copy',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Uint8List _jpeg(Uint8List bytes) =>
    img.encodeJpg(img.decodeImage(bytes)!, quality: 92);

class _RedactionPainter extends CustomPainter {
  _RedactionPainter(this.rectangles);
  final List<Rect> rectangles;
  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in rectangles) {
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left * size.width,
          rect.top * size.height,
          rect.right * size.width,
          rect.bottom * size.height,
        ),
        Paint()..color = Colors.black,
      );
    }
  }

  @override
  bool shouldRepaint(_RedactionPainter old) => true;
}
