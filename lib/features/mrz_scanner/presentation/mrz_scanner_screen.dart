import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../shared/widgets/scanner/scanner_chrome.dart';
import '../application/mrz_scanner_service.dart';
import '../domain/mrz_result.dart';

/// The screen returns a raw [MrzResult]; confirming it is the flow's job,
/// so there is no review state here any more.
enum _ScanState { permission, scanning, processing, error }

class MrzScannerScreen extends StatefulWidget {
  const MrzScannerScreen({super.key});

  @override
  State<MrzScannerScreen> createState() => _MrzScannerScreenState();
}

class _MrzScannerScreenState extends State<MrzScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCapturing = false;

  /// Drives the automatic capture loop. The MRZ is a fixed target on a
  /// flat page, so there is nothing for a shutter button to time better
  /// than the phone can -- asking the user to press one just meant holding
  /// the passport steady with one hand and tapping with the other.
  Timer? _autoScan;
  int _attempts = 0;
  _ScanState _state = _ScanState.scanning;
  String? _capturedImagePath;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _requestPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoScan();
    _controller?.dispose();
    // MrzScannerService owns an app-lifetime recogniser; nothing to close.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Stop the loop too, or it keeps calling takePicture on a paused
      // preview and burns the attempt budget while the app is in the
      // background.
      _stopAutoScan();
      controller.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      controller.resumePreview();
      if (_state == _ScanState.scanning) _startAutoScan();
    }
  }
  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await _initCamera();
    } else {
      setState(() => _state = _ScanState.permission);
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (!mounted) return;
    if (cameras.isEmpty) {
      setState(() {
        _state = _ScanState.error;
        _errorMessage = 'No camera found on this device.';
      });
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _state = _ScanState.scanning);
        _startAutoScan();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Camera failed to initialise: $e';
        });
      }
    }
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  /// Polls the camera until the MRZ parses.
  ///
  /// Deliberately a timer over takePicture rather than an image stream: the
  /// existing pipeline reads from a file path, and converting CameraImage
  /// planes to an ML Kit InputImage is a per-device format problem. This reuses
  /// the path that already works.
  void _startAutoScan() {
    _autoScan?.cancel();
    _attempts = 0;
    _autoScan = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted || _state != _ScanState.scanning || _isCapturing) return;
      _capture(auto: true);
    });
  }

  void _stopAutoScan() {
    _autoScan?.cancel();
    _autoScan = null;
  }

  Future<void> _capture({bool auto = false}) async {
    if (_isCapturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    _isCapturing = true;
    // An automatic attempt stays silent and stays on the viewfinder: a
    // failed read just means the page was not in frame yet.
    if (!auto) {
      HapticService.impact();
      setState(() => _state = _ScanState.processing);
    }
    try {
      final xFile = await _controller!.takePicture();
      _capturedImagePath = xFile.path;
      final result = await MrzScannerService.processImage(xFile.path);
      if (!mounted) return;
      if (result != null) {
        // Return the raw result and let the flow confirm it field by field.
        // The preview state below is no longer reachable: it was a second
        // review of the same values, in a hardcoded light-mode layout that
        // rendered a black title on a black scaffold, and the flow re-asked
        // everything anyway. Removed wholesale in the cleanup stage.
        _stopAutoScan();
        HapticService.success();
        Navigator.of(context).pop(
          result.copyWith(capturedImagePath: _capturedImagePath ?? ''),
        );
      } else if (auto) {
        _attempts++;
        // Give up guiding silently after a while and say something.
        if (_attempts >= 8) {
          _stopAutoScan();
          setState(() {
            _state = _ScanState.error;
            _errorMessage =
                'Could not read the passport.\nLay it flat in good light, '
                'with the two lines of code at the bottom inside the frame.';
          });
        }
      } else {
        setState(() {
          _state = _ScanState.error;
          _errorMessage =
              'Could not detect passport data.\nEnsure the passport is flat, well-lit, and fully visible.';
        });
      }
    } catch (_) {
      if (mounted && !auto) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Capture failed. Please try again.';
        });
      }
    } finally {
      _isCapturing = false;
    }
  }

  void _retake() {
    _startAutoScan();
    setState(() {
      _state = _ScanState.scanning;
      _capturedImagePath = null;
      _errorMessage = '';
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_state) {
        _ScanState.permission => _buildPermissionDenied(),
        _ScanState.scanning => _buildScanning(),
        _ScanState.processing => _buildProcessing(),
        _ScanState.error => _buildError(),
      },
    );
  }

  // ── SCANNING STATE ─────────────────────────────────────────────────────────

  Widget _buildScanning() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        // Scrim overlay with cutout drawn via CustomPaint
        CustomPaint(painter: const _ScanOverlayPainter()),
        // Top back button
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ScannerGlassButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        // Hint + shutter at bottom
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Hold the photo page inside the frame',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // No shutter: the scan runs itself.
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Looking for the code strip',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PROCESSING STATE ───────────────────────────────────────────────────────

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 24),
          Text(
            'Reading passport…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── ERROR STATE ────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFFF3B30),
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ScannerOutlineButton(label: 'Try Again', onTap: _retake),
            const SizedBox(height: 12),
            ScannerOutlineButton(
              label: 'Enter Manually',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ── PERMISSION DENIED STATE ────────────────────────────────────────────────

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Permission Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please grant camera access to scan your passport.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 32),
            ScannerOutlineButton(label: 'Open Settings', onTap: openAppSettings),
            const SizedBox(height: 12),
            ScannerOutlineButton(
              label: 'Enter Manually',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay Painter ────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const hPad = 24.0;
    final frameW = size.width - hPad * 2;
    // Passport aspect ratio ≈ 1.42:1
    final frameH = frameW / 1.42;
    final frameTop = (size.height - frameH) / 2;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(hPad, frameTop, frameW, frameH),
      const Radius.circular(16),
    );

    // Scrim
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.60);
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrimPath, scrim);

    // Simple minimal border — just the rounded rectangle
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(frame, borderPaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => false;
}
