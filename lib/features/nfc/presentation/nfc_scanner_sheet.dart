import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/apple_sheet.dart';
import '../application/nfc_service.dart';

class NfcScannerSheet extends StatefulWidget {
  const NfcScannerSheet({
    super.key,
    required this.passportNumber,
    required this.dateOfBirth,
    required this.expiryDate,
  });

  final String passportNumber;
  final String dateOfBirth;
  final String expiryDate;

  @override
  State<NfcScannerSheet> createState() => _NfcScannerSheetState();
}

class _NfcScannerSheetState extends State<NfcScannerSheet> with SingleTickerProviderStateMixin {
  final NfcService _nfcService = NfcService();
  String _statusMessage = "Hold your phone near the biometric chip (usually the back cover).";
  bool _isError = false;
  bool _isSuccess = false;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startScanning();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nfcService.stopNfcRead();
    super.dispose();
  }

  Future<void> _startScanning() async {
    try {
      final result = await _nfcService.startNfcRead(
        passportNumber: widget.passportNumber,
        dateOfBirth: widget.dateOfBirth,
        expiryDate: widget.expiryDate,
      );

      if (result != null && mounted) {
        setState(() {
          _isSuccess = true;
          _statusMessage = "Verification Successful!";
        });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _statusMessage = "Failed to read NFC chip. Please try again.\n\nError: $e";
        });
        HapticFeedback.vibrate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppleSheet(
      title: _isSuccess ? "Verified successfully" : _isError ? "Scan failed" : "Ready to Scan",
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInBack,
            child: _isSuccess
                ? _buildSuccessIcon()
                : _isError
                    ? _buildErrorIcon()
                    : _buildScanningAnimation(),
          ),
          
          const SizedBox(height: 24),
          
          // Status Message
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _statusMessage,
              key: ValueKey(_statusMessage),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (_isError)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isError = false;
                    _statusMessage = "Hold your phone near the biometric chip (usually the back cover).";
                  });
                  _startScanning();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return AnimatedBuilder(
      key: const ValueKey('scanning'),
      animation: _pulseCtrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse
            Container(
              width: 140 + (_pulseCtrl.value * 40),
              height: 140 + (_pulseCtrl.value * 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF007AFF).withValues(alpha: 0.1 * (1 - _pulseCtrl.value)),
              ),
            ),
            // Inner pulse
            Container(
              width: 110 + (_pulseCtrl.value * 20),
              height: 110 + (_pulseCtrl.value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF007AFF).withValues(alpha: 0.15 * (1 - _pulseCtrl.value)),
              ),
            ),
            // Core circle
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.contactless_rounded,
                    size: 38,
                    color: const Color(0xFF007AFF).withValues(alpha: 0.5),
                  ),
                  Transform.translate(
                    offset: Offset(0, 10 - (_pulseCtrl.value * 20)),
                    child: const Icon(
                      Icons.smartphone_rounded,
                      size: 38,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      key: const ValueKey('success'),
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.check_rounded,
          size: 54,
          color: Color(0xFF34C759),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      key: const ValueKey('error'),
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.close_rounded,
          size: 54,
          color: Color(0xFFFF3B30),
        ),
      ),
    );
  }
}
