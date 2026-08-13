import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'features/tickets/presentation/train/train_pass_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only. The wallet is a vertical card carousel with portrait
  // passport faces — there is no landscape design, and the manifests used to
  // advertise one anyway. Runtime lock covers both platforms; the native
  // manifests are aligned alongside it.
  final Future<void> orientationFuture = SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  // Parallel: prefs + one-shot theme build (resolves Inter via google_fonts).
  final Future<SharedPreferences> prefsFuture = SharedPreferences.getInstance();
  // Touch cached getters so MaterialApp does not pay GoogleFonts cost mid-build.
  AppTheme.lightTheme;
  AppTheme.darkTheme;

  // The train pass face sets its type in Geist and Instrument Serif, neither of
  // which the theme touches. Requesting them here puts them in the same
  // pendingFonts() wait below, so the card is not the one surface that renders
  // in the fallback face and reflows a frame later.
  TrainPassType.warmUp();

  final SharedPreferences prefs = await prefsFuture;
  await orientationFuture;

  // Finish any in-flight font loads before first frame (capped so offline is fine).
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(milliseconds: 900));
  } catch (_) {
    // Continue with pending/fallback faces.
  }

  final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  runApp(ProviderScope(child: DocketApp(hasSeenOnboarding: hasSeenOnboarding)));
}
