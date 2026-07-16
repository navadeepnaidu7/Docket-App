import 'package:flutter/material.dart';

/// Minimal static camera shutter button: outer ring circle + filled inner circle.
/// No animations, no icon. Used in MRZ and ID scanner live views.
class ScannerCaptureButton extends StatelessWidget {
  const ScannerCaptureButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture document',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: const Center(
            child: SizedBox(
              width: 54,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
