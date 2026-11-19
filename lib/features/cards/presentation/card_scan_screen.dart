import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/motion/studio_page_route.dart';
import '../../../core/scanning/live_frame_reader.dart';
import '../../../shared/widgets/scanner/scanner_chrome.dart';
import '../../../shared/widgets/scanner_capture_button.dart';
import '../application/card_scan_service.dart';
import '../domain/card_scan_text.dart';
import 'card_review_screen.dart';

enum _Side { front, back }

enum _ScanState { permission, scanning, processing, error }

/// Two photos, then the review. Nothing is saved from the shutter.
///
/// The front comes first. The back is next, with a way out when that side
/// is blank. "Type it instead" stays on the front step.
///
/// Preview frames are read the whole time the camera is up. Each side's
/// readings are pooled, and the shutter fires by itself once they agree, so
/// the proposed fields come from many frames rather than one lucky photo.
/// The shutter button still works for a side the frames never settle on.
class CardScanScreen extends StatefulWidget {
  const CardScanScreen({super.key});

  @override
  State<CardScanScreen> createState() => _CardScanScreenState();
}

class _CardScanScreenState extends State<CardScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _ScanState _state = _ScanState.scanning;
  _Side _side = _Side.front;
  bool _capturing = false;
  String _errorMessage = '';
  String? _frontPath;
  String? _backPath;
  CardScanFields _frontFields = CardScanFields.empty;
  CardScanFields _backFields = CardScanFields.empty;
  LiveFrameReader? _reader;
  final CardScanConsensus _frontVotes = CardScanConsensus();
  final CardScanConsensus _backVotes = CardScanConsensus();
  Rect _region = const Rect.fromLTRB(0, 0, 1, 1);
  DateTime _sideStartedAt = DateTime.now();
  bool _locked = false;

  /// Time to turn the card over before the back's frames count, so the
  /// front still in view is not read as the back.
  static const Duration _flipGrace = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_requestPermissionAndInit());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_reader?.stop());
    _controller?.dispose();
    unawaited(_deleteQuiet(_frontPath));
    unawaited(_deleteQuiet(_backPath));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_reader?.stop());
      controller.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      controller.resumePreview();
      if (_state == _ScanState.scanning) unawaited(_startReading());
    }
  }

  Future<void> _requestPermissionAndInit() async {
    final PermissionStatus status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await _initCamera();
    } else {
      setState(() => _state = _ScanState.permission);
    }
  }

  Future<void> _initCamera() async {
    final List<CameraDescription> cameras = await availableCameras();
    if (!mounted) return;
    if (cameras.isEmpty) {
      setState(() {
        _state = _ScanState.error;
        _errorMessage = 'No camera found on this device.';
      });
      return;
    }
    final CameraDescription back = cameras.firstWhere(
      (CameraDescription camera) =>
          camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final CameraController controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: liveFrameFormat,
    );
    _controller = controller;
    _reader = LiveFrameReader(controller: controller, onFrame: _readFrame);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _state = _ScanState.scanning);
      await _startReading();
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'The camera could not start.';
        });
      }
    }
  }

  CardScanConsensus get _votes =>
      _side == _Side.front ? _frontVotes : _backVotes;

  Future<void> _startReading() async {
    _sideStartedAt = DateTime.now();
    await _reader?.start();
  }

  Future<void> _readFrame(LiveFrame frame) async {
    if (_state != _ScanState.scanning || _capturing) return;
    final _Side side = _side;
    final CardScanFields fields = await CardScanService.readFrame(
      frame,
      _region,
    );
    if (!mounted || side != _side || _capturing) return;
    if (side == _Side.back) {
      if (DateTime.now().difference(_sideStartedAt) < _flipGrace) return;
      // The front's own number seen again means the card has not been
      // turned over yet.
      if (fields.number.isNotEmpty && fields.number == _frontFields.number) {
        return;
      }
    }
    _votes.add(fields);
    final bool ready = side == _Side.front
        ? _frontVotes.frontReady
        : _backVotes.backReady;
    if (ready != _locked) setState(() => _locked = ready);
    if (ready) unawaited(_capture());
  }

  Future<void> _capture() async {
    final CameraController? controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return;
    }
    _capturing = true;
    HapticService.impact();
    setState(() => _state = _ScanState.processing);
    String? path;
    try {
      await _reader?.stop();
      final XFile shot = await controller.takePicture();
      path = shot.path;
      final CardScanFields still = await CardScanService.readFile(path);
      _votes.add(still, weight: 2);
      final CardScanFields fields = preferCardFields(_votes.fields, still);
      if (!mounted) {
        await _deleteQuiet(path);
        return;
      }
      if (_side == _Side.front) {
        final String? previous = _frontPath;
        _frontPath = path;
        _frontFields = fields;
        path = null;
        await _deleteQuiet(previous);
        if (!mounted) return;
        setState(() {
          _side = _Side.back;
          _state = _ScanState.scanning;
          _locked = false;
        });
        await _startReading();
      } else {
        final String? previous = _backPath;
        _backPath = path;
        _backFields = fields;
        path = null;
        await _deleteQuiet(previous);
        if (!mounted) return;
        await _openReview();
      }
    } catch (_) {
      await _deleteQuiet(path);
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'The photo did not take. Try again.';
          _locked = false;
        });
      }
    } finally {
      _capturing = false;
    }
  }

  Future<void> _openReview({bool includeBack = true}) async {
    await _reader?.stop();
    final CardScanFields merged = mergeCardScans(
      _frontFields,
      includeBack ? _backFields : CardScanFields.empty,
    );
    try {
      await _controller?.pausePreview();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(
      studioPageRoute<void>(
        builder: (_) => CardReviewScreen(
          number: merged.number,
          holderName: merged.holderName,
          expiryMonth: merged.expiryMonth,
          expiryYear: merged.expiryYear,
          cvv: merged.cvv,
          frontPath: _frontPath,
          backPath: includeBack ? _backPath : null,
          fromScan: true,
        ),
      ),
    );
    if (!mounted) return;
    try {
      await _controller?.resumePreview();
    } catch (_) {}
    if (mounted && _state == _ScanState.processing) {
      setState(() {
        _state = _ScanState.scanning;
        _locked = false;
      });
    }
    if (mounted && _state == _ScanState.scanning) {
      // Back from the review: read this side afresh rather than firing
      // again on the votes that just opened it.
      _votes.clear();
      await _startReading();
    }
  }

  void _toFront() {
    _backVotes.clear();
    _frontVotes.clear();
    setState(() {
      _side = _Side.front;
      _locked = false;
    });
    _sideStartedAt = DateTime.now();
  }

  void _back() {
    if (_state == _ScanState.processing) return;
    if (_side == _Side.back) {
      _toFront();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _deleteQuiet(String? path) async {
    if (path == null) return;
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _side == _Side.front && _state != _ScanState.processing,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop || _state == _ScanState.processing) return;
        if (_side == _Side.back) _toFront();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (_state) {
          _ScanState.permission => _permission(),
          _ScanState.scanning => _scanning(),
          _ScanState.processing => _processing(),
          _ScanState.error => _error(),
        },
      ),
    );
  }

  Widget _scanning() {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final bool front = _side == _Side.front;
    _region = cardGuideRegion(MediaQuery.sizeOf(context));
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CameraPreview(controller),
        CustomPaint(painter: _CardFramePainter(locked: _locked)),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ScannerGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: _back,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _locked
                          ? 'Got it. Hold still.'
                          : front
                          ? 'Front of the card. It reads on its own.'
                          : 'Back of the card. The number or the code is often here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ScannerCaptureButton(onTap: _capture),
                  const SizedBox(height: 16),
                  if (front)
                    _TextAction(
                      label: 'Type it instead',
                      onTap: () => unawaited(_openReview(includeBack: false)),
                    )
                  else
                    _TextAction(
                      label: 'This side is blank',
                      onTap: () => unawaited(_openReview(includeBack: false)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _processing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 24),
          Text(
            'Reading the card',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _permission() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: ScannerGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera access is needed to scan a card.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ScannerOutlineButton(
              label: 'Open Settings',
              onTap: openAppSettings,
            ),
            const SizedBox(height: 12),
            ScannerOutlineButton(
              label: 'Type it instead',
              onTap: () => unawaited(_openReview(includeBack: false)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _error() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: ScannerGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: _back,
              ),
            ),
            const Spacer(),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ScannerOutlineButton(
              label: 'Try again',
              onTap: () {
                setState(() => _state = _ScanState.scanning);
                if (_controller == null || !_controller!.value.isInitialized) {
                  unawaited(_initCamera());
                } else {
                  unawaited(_startReading());
                }
              },
            ),
            const SizedBox(height: 12),
            ScannerOutlineButton(
              label: 'Type it instead',
              onTap: () => unawaited(_openReview(includeBack: false)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CardFramePainter extends CustomPainter {
  const _CardFramePainter({required this.locked});

  /// Turns the outline green once the frames agree.
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    const double hPad = 24;
    final double frameW = size.width - hPad * 2;
    final double frameH = frameW / 1.586;
    final double frameTop = (size.height - frameH) / 2;
    final RRect frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(hPad, frameTop, frameW, frameH),
      const Radius.circular(16),
    );
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(frame)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withValues(alpha: 0.60),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = locked
            ? const Color(0xFF4ADE80)
            : Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_CardFramePainter oldDelegate) =>
      oldDelegate.locked != locked;
}
