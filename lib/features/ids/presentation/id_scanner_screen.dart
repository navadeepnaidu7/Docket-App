import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/haptics/haptic_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/widgets/scanner_capture_button.dart';
import '../../../core/validation/document_validators.dart';
import '../application/id_scanner_service.dart';
import '../domain/id_document.dart';

enum _ScanState { permission, scanning, processing, preview, error }

class IdScannerScreen extends StatefulWidget {
  const IdScannerScreen({super.key, required this.type});

  final IdDocumentType type;

  @override
  State<IdScannerScreen> createState() => _IdScannerScreenState();
}

class _IdScannerScreenState extends State<IdScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCapturing = false;
  _ScanState _state = _ScanState.scanning;
  String? _capturedImagePath;
  String _errorMessage = '';

  // Preview editable controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _fatherCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _genderCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _nameCtrl = TextEditingController();
    _numberCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _fatherCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _genderCtrl = TextEditingController();

    _requestPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _dobCtrl.dispose();
    _fatherCtrl.dispose();
    _addressCtrl.dispose();
    _genderCtrl.dispose();
    IdScannerService.dispose();
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
    _controller =
        CameraController(back, ResolutionPreset.high, enableAudio: false);
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

  Future<void> _capture() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    _isCapturing = true;
    HapticService.impact();
    setState(() => _state = _ScanState.processing);
    try {
      final xFile = await _controller!.takePicture();
      _capturedImagePath = xFile.path;
      final result = await IdScannerService.processImage(xFile.path, widget.type);
      if (!mounted) return;
      if (result != null) {
        _populateControllers(result);
        setState(() => _state = _ScanState.preview);
      } else {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Could not detect ${_docLabel(widget.type)} data.\nEnsure the card is flat, well-lit, and fully visible.';
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
  void _populateControllers(IdScanResult r) {
    _nameCtrl.text = r.holderName;
    _numberCtrl.text = r.documentNumber;
    _dobCtrl.text = r.dateOfBirth;
    _fatherCtrl.text = r.fatherName;
    _addressCtrl.text = r.address;
    _genderCtrl.text = r.gender;
  }

  IdScanResult _buildResultFromControllers() => IdScanResult(
        type: widget.type,
        holderName: _nameCtrl.text,
        documentNumber: _numberCtrl.text,
        dateOfBirth: _dobCtrl.text,
        fatherName: _fatherCtrl.text,
        address: _addressCtrl.text,
        gender: _genderCtrl.text,
        capturedImagePath: _capturedImagePath ?? '',
      );

  void _retake() => setState(() {
        _state = _ScanState.scanning;
        _capturedImagePath = null;
        _errorMessage = '';
      });

  String _docLabel(IdDocumentType t) =>
      t == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_state) {
        _ScanState.permission => _buildPermissionDenied(),
        _ScanState.scanning => _buildScanning(),
        _ScanState.processing => _buildProcessing(),
        _ScanState.preview => _buildPreview(),
        _ScanState.error => _buildError(),
      },
    );
  }

  Widget _buildScanning() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        const CustomPaint(
          painter: _CardOverlayPainter(),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _GlassButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop()),
            ),
          ),
        ),
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
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'Align ${_docLabel(widget.type)} inside the frame',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          const SizedBox(height: 24),
          Text('Reading ${_docLabel(widget.type)}…',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('This may take a few seconds',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final isPan = widget.type == IdDocumentType.pan;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _retake,
                    dark: true),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Review Details',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_capturedImagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(File(_capturedImagePath!),
                        height: 160, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 20),
                const Text('Extracted Details',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 12),
                _PreviewField(
                    label: 'Full Name',
                    controller: _nameCtrl,
                    icon: Icons.person_rounded),
                _PreviewField(
                    label: isPan ? 'PAN Number' : 'Aadhaar Number',
                    controller: _numberCtrl,
                    icon: Icons.badge_rounded),
                _PreviewField(
                    label: 'Date of Birth',
                    controller: _dobCtrl,
                    icon: Icons.cake_rounded),
                if (isPan)
                  _PreviewField(
                      label: "Father's Name",
                      controller: _fatherCtrl,
                      icon: Icons.people_rounded),
                if (!isPan) ...[
                  _PreviewField(
                      label: 'Gender',
                      controller: _genderCtrl,
                      icon: Icons.person_outline_rounded),
                  _PreviewField(
                      label: 'Address',
                      controller: _addressCtrl,
                      icon: Icons.location_on_rounded,
                      maxLines: 3),
                ],
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    final result = _buildResultFromControllers();
                    final typeForVal = widget.type == IdDocumentType.pan
                        ? IdDocumentTypeForValidation.pan
                        : IdDocumentTypeForValidation.aadhaar;

                    final err = DocumentValidators.validateIdForSave(
                      dateOfBirth: result.dateOfBirth,
                      documentNumber: result.documentNumber,
                      type: typeForVal,
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
                        borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Confirm & Use',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _retake,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFE5E5EA), width: 1.5),
                        borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            color: Color(0xFF1C1C1E)),
                        SizedBox(width: 10),
                        Text('Retake',
                            style: TextStyle(
                                color: Color(0xFF1C1C1E),
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                  shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFFFF3B30), size: 44),
            ),
            const SizedBox(height: 24),
            const Text('Scan Failed',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 15, height: 1.5)),
            const SizedBox(height: 32),
            _OutlineButton(label: 'Try Again', onTap: _retake),
            const SizedBox(height: 12),
            _OutlineButton(
                label: 'Enter Manually',
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 24),
            const Text('Camera Permission Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Please grant camera access to scan your ID.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 15)),
            const SizedBox(height: 32),
            _OutlineButton(label: 'Open Settings', onTap: openAppSettings),
            const SizedBox(height: 12),
            _OutlineButton(
                label: 'Enter Manually',
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

// ── Overlay: landscape credit-card aspect ratio ───────────────────────────────

class _CardOverlayPainter extends CustomPainter {
  const _CardOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const hPad = 24.0;
    final frameW = size.width - hPad * 2;
    // Credit-card ratio 85.6 × 54 mm ≈ 1.586
    final frameH = frameW / 1.586;
    final frameTop = (size.height - frameH) / 2;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(hPad, frameTop, frameW, frameH),
      const Radius.circular(16),
    );

    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.60);
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(frame)
        ..fillType = PathFillType.evenOdd,
      scrim,
    );

    // Simple minimal border — just the rounded rectangle
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_CardOverlayPainter old) => false;
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton(
      {required this.icon, required this.onTap, this.dark = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white30),
            borderRadius: BorderRadius.circular(18)),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16))),
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField(
      {required this.label,
      required this.controller,
      required this.icon,
      this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Icon(icon, color: const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                  labelText: label,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}
