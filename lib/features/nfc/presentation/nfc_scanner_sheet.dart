import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 40),
          
          // Icon
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Transform.scale(
                scale: _isSuccess || _isError ? 1.0 : 1.0 + (_pulseCtrl.value * 0.1),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFF34C759).withValues(alpha: 0.1)
                        : _isError
                            ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                            : const Color(0xFF007AFF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSuccess
                        ? Icons.check_circle_rounded
                        : _isError
                            ? Icons.error_rounded
                            : Icons.nfc_rounded,
                    size: 40,
                    color: _isSuccess
                        ? const Color(0xFF34C759)
                        : _isError
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF007AFF),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            _isSuccess ? "Verified" : _isError ? "Error" : "Ready to Scan",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Status Message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 40),
          
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
                  backgroundColor: const Color(0xFF007AFF),
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
            
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
