import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/assets/asset_licenses.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every font used by the app ships as an asset. Launch and later screens
  // must not depend on a font download or on a previous run's disk cache.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Attribution for bundled CC BY-SA artwork. Registers a collector only; the
  // text is not built until a licence page asks for it.
  registerAssetLicenses();

  // Portrait only. The wallet is a vertical card carousel with portrait
  // passport faces — there is no landscape design, and the manifests used to
  // advertise one anyway. Runtime lock covers both platforms; the native
  // manifests are aligned alongside it.
  final Future<void> chromeFuture = Future.wait<void>(<Future<void>>[
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    // Draw behind the gesture pill so each page color shows through,
    // instead of a separate system strip (black or cream).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemOverlayStyleFor(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
    ),
  );

  // Only routing preferences and system chrome gate the first frame. Themes
  // are cached lazily by DocketApp; hidden screens load their bundled fonts
  // when they are first needed.
  final Future<SharedPreferences> prefsFuture = SharedPreferences.getInstance();

  final SharedPreferences prefs = await prefsFuture;
  await chromeFuture;

  // A malformed preference must not throw before runApp. Only an explicitly
  // persisted true skips onboarding; document storage is independent of this.
  final bool hasSeenOnboarding = prefs.get('has_seen_onboarding') == true;

  runApp(ProviderScope(child: DocketApp(hasSeenOnboarding: hasSeenOnboarding)));
}
