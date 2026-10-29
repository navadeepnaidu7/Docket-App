import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_theme.dart';
import '../application/id_media_service.dart';
import 'id_document_ui.dart';

class IdImageEditor extends StatefulWidget {
  const IdImageEditor({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<IdImageEditor> createState() => _IdImageEditorState();
}

class _IdImageEditorState extends State<IdImageEditor> {
  late Uint8List _bytes = widget.bytes;
  late Future<String> _quality = compute(idImageQuality, _bytes);
  late Future<double> _ratio = _readRatio(_bytes);
  List<Offset> _corners = [
    Offset.zero,
    const Offset(1, 0),
    const Offset(1, 1),
    const Offset(0, 1),
  ];
  int? _dragging;
  bool _busy = false;

  Future<double> _readRatio(Uint8List bytes) async {
    final image = await decodeImageFromList(bytes);
    try {
      return image.width / image.height;
    } finally {
      image.dispose();
    }
  }

  bool _valid(List<Offset> points) {
    for (var i = 0; i < 4; i++) {
      final a = points[(i + 1) % 4] - points[i];
      final b = points[(i + 2) % 4] - points[(i + 1) % 4];
      if (a.dx * b.dy - a.dy * b.dx < .025) return false;
    }
    return true;
  }

  Future<void> _rotate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await compute(_rotateImage, _bytes);
      if (!mounted) return;
      setState(() {
        _bytes = next;
        _ratio = _readRatio(next);
        _quality = compute(idImageQuality, next);
        _corners = [
          Offset.zero,
          const Offset(1, 0),
          const Offset(1, 1),
          const Offset(0, 1),
        ];
      });
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not rotate',
          'Please choose another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await compute(rectifyIdImage, (_bytes, _corners));
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        await showIdMessage(
          context,
          'Could not adjust image',
          'Try resetting the corners.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Adjust scan'),
        actions: [
          IconButton(
            tooltip: 'Rotate image',
            onPressed: _busy ? null : _rotate,
            icon: const Icon(CupertinoIcons.rotate_right),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                'Drag the four corners to the document edges. Your original stays unchanged.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: FutureBuilder<double>(
                  future: _ratio,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    return Center(
                      child: AspectRatio(
                        aspectRatio: snapshot.data!,
                        child: LayoutBuilder(
                          builder: (context, box) => GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            onPanStart: _busy
                                ? null
                                : (details) {
                                    var closest = 0;
                                    var distance = double.infinity;
                                    for (var i = 0; i < 4; i++) {
                                      final d =
                                          (Offset(
                                                    _corners[i].dx *
                                                        box.maxWidth,
                                                    _corners[i].dy *
                                                        box.maxHeight,
                                                  ) -
                                                  details.localPosition)
                                              .distance;
                                      if (d < distance) {
                                        distance = d;
                                        closest = i;
                                      }
                                    }
                                    _dragging = distance < 60 ? closest : null;
                                  },
                            onPanUpdate: (details) {
                              final index = _dragging;
                              if (_busy || index == null) return;
                              final next = [..._corners];
                              next[index] = Offset(
                                (details.localPosition.dx / box.maxWidth).clamp(
                                  0,
                                  1,
                                ),
                                (details.localPosition.dy / box.maxHeight)
                                    .clamp(0, 1),
                              );
                              if (_valid(next)) setState(() => _corners = next);
                            },
                            onPanEnd: (_) => _dragging = null,
                            child: CustomPaint(
                              foregroundPainter: _CropGuide(
                                _corners,
                                AppTheme.accentOf(Theme.of(context).brightness),
                              ),
                              child: Image.memory(
                                _bytes,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            FutureBuilder<String>(
              future: _quality,
              builder: (context, snapshot) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  snapshot.data ?? 'Checking readability…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _use,
                  child: Text(_busy ? 'Preparing…' : 'Use for scanning'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Uint8List _rotateImage(Uint8List bytes) =>
    img.encodePng(img.copyRotate(img.decodeImage(bytes)!, angle: 90));

class _CropGuide extends CustomPainter {
  _CropGuide(this.corners, this.color);
  final List<Offset> corners;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final points = corners
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final outline = Path()..addPolygon(points, true);
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPolygon(points, true);
    canvas.drawPath(scrim, Paint()..color = const Color(0x66000000));
    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final point in points) {
      canvas.drawCircle(point, 10, Paint()..color = color);
      canvas.drawCircle(point, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_CropGuide old) =>
      old.corners != corners || old.color != color;
}
