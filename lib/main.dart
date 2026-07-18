import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parallel: prefs + one-shot theme build (resolves Inter via google_fonts).
  final Future<SharedPreferences> prefsFuture = SharedPreferences.getInstance();
  // Touch cached getters so MaterialApp does not pay GoogleFonts cost mid-build.
  AppTheme.lightTheme;
  AppTheme.darkTheme;

  final SharedPreferences prefs = await prefsFuture;

  // Finish any in-flight font loads before first frame (capped so offline is fine).
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(milliseconds: 900));
  } catch (_) {
    // Continue with pending/fallback faces.
  }

  final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  runApp(ProviderScope(child: DocketApp(hasSeenOnboarding: hasSeenOnboarding)));
}
