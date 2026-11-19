import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// One preview frame, ready for ML Kit.
class LiveFrame {
  const LiveFrame({required this.image, required this.uprightSize});

  final InputImage image;

  /// The frame's size once rotated to the way the phone is held. ML Kit's
  /// bounding boxes are in this space.
  final Size uprightSize;
}

/// The stream format ML Kit reads without a conversion step.
ImageFormatGroup get liveFrameFormat =>
    Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

const Map<DeviceOrientation, int> _orientationDegrees =
    <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

/// Feeds preview frames to [onFrame], one at a time.
///
/// A frame that arrives while the previous one is still being read is
/// dropped, so OCR never queues up behind the camera. Frames are held in
/// memory only and never written to disk.
class LiveFrameReader {
  LiveFrameReader({
    required this.controller,
    required this.onFrame,
    this.minInterval = const Duration(milliseconds: 220),
  });

  final CameraController controller;
  final Future<void> Function(LiveFrame frame) onFrame;
  final Duration minInterval;

  bool _busy = false;
  Completer<void>? _inFlight;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  bool get running => controller.value.isStreamingImages;

  Future<void> start() async {
    if (!controller.value.isInitialized || running) return;
    try {
      await controller.startImageStream(_handle);
    } catch (e) {
      debugPrint('[LiveFrameReader] Live frames unavailable.');
    }
  }

  /// Stops the stream and waits for the frame being read, so a still
  /// capture that follows does not race the analysis use case.
  Future<void> stop() async {
    if (running) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    await _inFlight?.future;
  }

  void _handle(CameraImage image) {
    if (_busy) return;
    final DateTime now = DateTime.now();
    if (now.difference(_last) < minInterval) return;
    final LiveFrame? frame = _toFrame(image);
    if (frame == null) return;
    _busy = true;
    _last = now;
    final Completer<void> done = Completer<void>();
    _inFlight = done;
    onFrame(frame).catchError((Object _) {}).whenComplete(() {
      _busy = false;
      done.complete();
    });
  }

  LiveFrame? _toFrame(CameraImage image) {
    final CameraDescription camera = controller.description;
    final int sensor = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      final int device =
          _orientationDegrees[controller.value.deviceOrientation] ?? 0;
      final int compensated = camera.lensDirection == CameraLensDirection.front
          ? (sensor + device) % 360
          : (sensor - device + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensated);
    }
    if (rotation == null) return null;

    final InputImageFormat? format = InputImageFormatValue.fromRawValue(
      image.format.raw as int,
    );
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final Plane plane = image.planes.first;

    final Size size = Size(image.width.toDouble(), image.height.toDouble());
    final bool sideways =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return LiveFrame(
      image: InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
      uprightSize: sideways ? Size(size.height, size.width) : size,
    );
  }
}

/// The guide frame drawn over a full-screen preview, as fractions of the
/// screen. Every scanner draws a card-shaped guide with the same inset.
Rect cardGuideRegion(Size screen, {double inset = 24, double aspect = 1.586}) {
  if (screen.isEmpty) return const Rect.fromLTRB(0, 0, 1, 1);
  final double width = screen.width - inset * 2;
  final double height = width / aspect;
  final double top = (screen.height - height) / 2;
  return Rect.fromLTWH(
    inset / screen.width,
    top / screen.height,
    width / screen.width,
    height / screen.height,
  );
}

/// The recognised lines whose centres sit inside [region], in reading order.
///
/// [region] is in fractions of the upright frame, and is widened by
/// [slack] on every side because the preview is not cropped exactly as the
/// frame is. When nothing falls inside, every line is returned: a card held
/// a little off the guide still reads, it is just noisier.
String textInRegion(
  RecognizedText recognized,
  Size uprightSize,
  Rect region, {
  double slack = 0.06,
}) {
  if (uprightSize.isEmpty) return recognized.text;
  final Rect wide = Rect.fromLTRB(
    region.left - slack,
    region.top - slack,
    region.right + slack,
    region.bottom + slack,
  );
  final List<String> kept = <String>[];
  for (final TextBlock block in recognized.blocks) {
    for (final TextLine line in block.lines) {
      final Offset centre = line.boundingBox.center;
      final Offset unit = Offset(
        centre.dx / uprightSize.width,
        centre.dy / uprightSize.height,
      );
      if (wide.contains(unit)) kept.add(line.text);
    }
  }
  return kept.isEmpty ? recognized.text : kept.join('\n');
}
