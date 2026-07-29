import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class DocketApp extends ConsumerStatefulWidget {
  final bool hasSeenOnboarding;
  const DocketApp({super.key, required this.hasSeenOnboarding});

  @override
  ConsumerState<DocketApp> createState() => _DocketAppState();
}

class _DocketAppState extends ConsumerState<DocketApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Long enough that the mid-transition brightness flip is soft, not a flash.
  static const Duration _kThemeAnimDuration = Duration(milliseconds: 620);

  late final AnimationController _anim;
  late final CurvedAnimation _curve;

  late ThemeData _fromTheme;
  late ThemeData _toTheme;
  late Brightness _targetBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Default = device: start from current platform brightness.
    final Brightness platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _targetBrightness = platform;
    _fromTheme = _themeFor(platform);
    _toTheme = _fromTheme;

    _anim = AnimationController(vsync: this, duration: _kThemeAnimDuration);
    _curve = CurvedAnimation(
      parent: _anim,
      // Emphasized ease softens the middle (where ThemeData brightness flips).
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubicEmphasized,
    );
    // Settled at end so the first frame is not mid-animation.
    _anim.value = 1.0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _curve.dispose();
    _anim.dispose();
    super.dispose();
  }

  ThemeData _themeFor(Brightness brightness) =>
      brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

  Brightness _brightnessForMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  void _animateToBrightness(Brightness next) {
    if (next == _targetBrightness) return;

    // Resume from whatever is currently on screen (supports mid-switch interrupt).
    final ThemeData visual = ThemeData.lerp(_fromTheme, _toTheme, _curve.value);
    _fromTheme = visual;
    _toTheme = _themeFor(next);
    _targetBrightness = next;
    _anim.forward(from: 0);
  }

  void _syncToMode(ThemeMode mode) {
    _animateToBrightness(_brightnessForMode(mode));
  }

  @override
  void didChangePlatformBrightness() {
    final ThemeMode mode = ref.read(resolvedThemeModeProvider);
    if (mode == ThemeMode.system) {
      _animateToBrightness(
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );
    }
  }

  SystemUiOverlayStyle _overlayFor(ThemeData theme) {
    final bool dark = theme.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode mode = ref.watch(resolvedThemeModeProvider);

    // Drive animation when the user changes Light / Dark / Device / Schedule.
    ref.listen<ThemeMode>(resolvedThemeModeProvider, (ThemeMode? prev, ThemeMode next) {
      _syncToMode(next);
    });

    // Catch first frame / load completion if mode brightness differs from start.
    final Brightness desired = _brightnessForMode(mode);
    if (desired != _targetBrightness && !_anim.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncToMode(mode);
      });
    }

    return AnimatedBuilder(
      animation: _curve,
      builder: (BuildContext context, Widget? _) {
        final double t = _curve.value;
        final ThemeData theme = ThemeData.lerp(_fromTheme, _toTheme, t);

        // Soft veil that peaks at mid-transition to hide the brightness snap.
        final double veil = (t < 0.5 ? t : 1.0 - t) * 2.0; // 0 → 1 → 0
        final Color veilColor = Color.lerp(
              _fromTheme.scaffoldBackgroundColor,
              _toTheme.scaffoldBackgroundColor,
              0.5,
            ) ??
            Colors.black;
        final double veilOpacity = veil * 0.22;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _overlayFor(theme),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Docket',
            // Single driven theme — avoids MaterialApp's binary themeMode snap.
            theme: theme,
            darkTheme: theme,
            themeMode: ThemeMode.light,
            themeAnimationDuration: Duration.zero,
            builder: (BuildContext context, Widget? child) {
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ?child,
                  if (veilOpacity > 0.004)
                    IgnorePointer(
                      child: ColoredBox(
                        color: veilColor.withValues(alpha: veilOpacity),
                      ),
                    ),
                ],
              );
            },
            home: widget.hasSeenOnboarding
                ? const DashboardScreen()
                : const OnboardingScreen(),
          ),
        );
      },
    );
  }
}
