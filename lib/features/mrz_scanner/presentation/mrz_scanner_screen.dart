import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../shared/widgets/scanner_capture_button.dart';
import '../../../core/validation/document_validators.dart';
import '../application/mrz_scanner_service.dart';
import '../domain/mrz_result.dart';

enum _ScanState { permission, scanning, processing, preview, error }

class MrzScannerScreen extends StatefulWidget {
  const MrzScannerScreen({super.key});

  @override
  State<MrzScannerScreen> createState() => _MrzScannerScreenState();
}

class _MrzScannerScreenState extends State<MrzScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCapturing = false;
  _ScanState _state = _ScanState.scanning;
  MrzResult? _result;
  String? _capturedImagePath;
  String _errorMessage = '';

  // Editable controllers for the preview state
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passportNumCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _expiryCtrl;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _genderCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _nameCtrl = TextEditingController();
    _passportNumCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _expiryCtrl = TextEditingController();
    _nationalityCtrl = TextEditingController();
    _genderCtrl = TextEditingController();

    _requestPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _nameCtrl.dispose();
    _passportNumCtrl.dispose();
    _dobCtrl.dispose();
    _expiryCtrl.dispose();
    _nationalityCtrl.dispose();
    _genderCtrl.dispose();
    MrzScannerService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.pausePreview();
    } else if (state == AppLifecycleState.resumed) {
      controller.resumePreview();
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
    _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
    try {
      await _controller!.initialize();
      if (mounted) setState(() => _state = _ScanState.scanning);
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

  Future<void> _capture() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    _isCapturing = true;
    HapticService.impact();
    setState(() => _state = _ScanState.processing);
    try {
      final xFile = await _controller!.takePicture();
      _capturedImagePath = xFile.path;
      final result = await MrzScannerService.processImage(xFile.path);
      if (!mounted) return;
      if (result != null) {
        _populateControllers(result);
        setState(() {
          _result = result;
          _state = _ScanState.preview;
        });
      } else {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Could not detect passport data.\nEnsure the passport is flat, well-lit, and fully visible.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Capture failed. Please try again.';
        });
      }
    } finally {
      _isCapturing = false;
    }
  }
  void _populateControllers(MrzResult r) {
    _nameCtrl.text = r.displayName;
    _passportNumCtrl.text = r.passportNumber;
    _dobCtrl.text = r.dateOfBirth;
    _expiryCtrl.text = r.expiryDate;
    _nationalityCtrl.text = r.nationality;
    _genderCtrl.text = r.gender;
  }

  MrzResult _buildResultFromControllers() {
    return (_result ?? const MrzResult(
      passportNumber: '', dateOfBirth: '', expiryDate: '',
      surname: '', givenNames: '', nationality: '', gender: '',
      checksumValid: false, rawLine1: '', rawLine2: '',
    )).copyWith(
      fullName: _nameCtrl.text,
      passportNumber: _passportNumCtrl.text,
      dateOfBirth: _dobCtrl.text,
      expiryDate: _expiryCtrl.text,
      nationality: _nationalityCtrl.text,
      gender: _genderCtrl.text,
      capturedImagePath: _capturedImagePath ?? '',
    );
  }

  void _retake() {
    setState(() {
      _state = _ScanState.scanning;
      _result = null;
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
        _ScanState.scanning   => _buildScanning(),
        _ScanState.processing => _buildProcessing(),
        _ScanState.preview    => _buildPreview(),
        _ScanState.error      => _buildError(),
      },
    );
  }

  // ── SCANNING STATE ─────────────────────────────────────────────────────────

  Widget _buildScanning() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        // Scrim overlay with cutout drawn via CustomPaint
        CustomPaint(
          painter: const _ScanOverlayPainter(),
        ),
        // Top back button
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _GlassButton(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Align passport data page inside the frame',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ScannerCaptureButton(onTap: _capture),
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
          Text('Reading passport…', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('This may take a few seconds', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  // ── PREVIEW STATE ──────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _GlassButton(icon: Icons.arrow_back_rounded, onTap: _retake, dark: true),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Review Details', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Captured image thumbnail
                if (_capturedImagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(File(_capturedImagePath!), height: 180, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 12),
                // Checksum badge
                if (_result != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_result!.checksumValid ? const Color(0xFF34C759) : Colors.orange).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _result!.checksumValid ? Icons.verified_rounded : Icons.warning_rounded,
                            size: 14,
                            color: _result!.checksumValid ? const Color(0xFF34C759) : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _result!.checksumValid ? 'MRZ Verified' : 'MRZ checksum mismatch — please verify',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _result!.checksumValid ? const Color(0xFF34C759) : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('Extracted Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                const SizedBox(height: 12),
                _PreviewField(label: 'Full Name', controller: _nameCtrl, icon: Icons.person_rounded),
                _PreviewField(label: 'Passport Number', controller: _passportNumCtrl, icon: Icons.confirmation_number_rounded),
                _PreviewField(label: 'Date of Birth', controller: _dobCtrl, icon: Icons.cake_rounded),
                _PreviewField(label: 'Expiry Date', controller: _expiryCtrl, icon: Icons.event_available_rounded),
                _PreviewField(label: 'Nationality', controller: _nationalityCtrl, icon: Icons.flag_rounded),
                _PreviewField(label: 'Gender', controller: _genderCtrl, icon: Icons.person_outline_rounded),
                const SizedBox(height: 24),
                // Confirm
                GestureDetector(
                  onTap: () {
                    final result = _buildResultFromControllers();
                    final err = DocumentValidators.validatePassportDates(
                      dateOfBirth: result.dateOfBirth,
                      expiryDate: result.expiryDate,
                    );
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.warning_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(err)),
                        ]),
                        backgroundColor: const Color(0xFFFF3B30),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        duration: const Duration(seconds: 4),
                      ));
                      return;
                    }
                    Navigator.of(context).pop(result);
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF07111F),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Confirm & Use', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Retake
                GestureDetector(
                  onTap: _retake,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E5EA), width: 1.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: Color(0xFF1C1C1E)),
                        SizedBox(width: 10),
                        Text('Retake', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
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
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Color(0xFFFF3B30), size: 44),
            ),
            const SizedBox(height: 24),
            const Text('Scan Failed', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 15, height: 1.5)),
            const SizedBox(height: 32),
            _OutlineButton(label: 'Try Again', onTap: _retake),
            const SizedBox(height: 12),
            _OutlineButton(label: 'Enter Manually', onTap: () => Navigator.of(context).pop()),
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
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
            const SizedBox(height: 24),
            const Text('Camera Permission Required', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Please grant camera access to scan your passport.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 15)),
            const SizedBox(height: 32),
            _OutlineButton(label: 'Open Settings', onTap: openAppSettings),
            const SizedBox(height: 12),
            _OutlineButton(label: 'Enter Manually', onTap: () => Navigator.of(context).pop()),
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

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap, this.dark = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: dark ? Colors.black12 : Colors.white24,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? Colors.black12 : Colors.white30),
        ),
        child: Icon(icon, color: dark ? Colors.black : Colors.white, size: 22),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.label, required this.controller, required this.icon});
  final String label;
  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
