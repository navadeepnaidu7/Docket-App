import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import 'settings_screen.dart';

/// Opens Settings from anywhere the profile avatar is shown.
///
/// Same modal transition as pass/ticket card detail (slide up / dismiss down).
void openSettingsRoute(BuildContext context) {
  HapticService.confirm();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const SettingsScreen(),
    ),
  );
}
