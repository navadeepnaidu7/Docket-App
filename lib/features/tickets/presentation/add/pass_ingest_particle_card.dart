import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../application/pass_ingest_controller.dart';
import '../../application/pass_ingest_service.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_ingest.dart';
import '../../domain/pass_status.dart';

class PassIngestParticleCard extends StatefulWidget {
  const PassIngestParticleCard({
    super.key,
    required this.state,
    required this.isActive,
    required this.onFinished,
  });

  final PassIngestUiState state;
  final bool isActive;
  final VoidCallback onFinished;

  @override
  State<PassIngestParticleCard> createState() => _PassIngestParticleCardState();
}

class _PassIngestParticleCardState extends State<PassIngestParticleCard>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _flow;
  late final AnimationController _outcome;
  late final AnimationController _stage;
  bool _reduceMotion = false;
  String? _handledSuccessId;
  PassIngestException? _handledError;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    );
    _outcome = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _stage = AnimationController(
      vsync: this,
      value: _loadingStageFor(widget.state),
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion != reduce) _reduceMotion = reduce;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant PassIngestParticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.runtimeType != widget.state.runtimeType) {
      _clearTimer?.cancel();
      _outcome.value = 0;
    }
    _syncMotion();
  }

  void _syncMotion() {
    final PassIngestUiState state = widget.state;
    if (state is PassIngestRunning) {
      _handledError = null;
      final double target = _loadingStageFor(state);
      if (_reduceMotion || !widget.isActive) {
        _stage.value = target;
      } else if (_stage.value != target) {
        _stage.animateTo(target, curve: Curves.easeInOutCubic);
      }
    } else {
      // Freeze the live field before resolving it; switching to stage 1 here
      // would move every particle on the first completion frame.
      _stage.stop();
    }
    final bool shouldFlow =
        widget.isActive && !_reduceMotion && state is PassIngestRunning;
    if (shouldFlow && !_flow.isAnimating) {
      _flow.repeat();
    } else if (!shouldFlow && _flow.isAnimating) {
      _flow.stop(canceled: false);
    }

    if (!widget.isActive) return;
    if (state is PassIngestSucceeded) {
      if (_handledSuccessId == state.item.id) return;
      _handledSuccessId = state.item.id;
      HapticService.success();
      _outcome.duration = _reduceMotion
          ? const Duration(milliseconds: 200)
          : const Duration(milliseconds: 520);
      _outcome.forward(from: 0).then((_) {
        if (!mounted) return;
        if (state.item.status == TicketStatus.active) {
          widget.onFinished();
        } else {
          _scheduleClear(const Duration(milliseconds: 1800));
        }
      });
    } else if (state is PassIngestFailed) {
      if (identical(_handledError, state.error)) return;
      _handledError = state.error;
      HapticService.error();
      _outcome.duration = _reduceMotion
          ? const Duration(milliseconds: 200)
          : const Duration(milliseconds: 360);
      _outcome.forward(from: 0).then((_) {
        if (mounted) _scheduleClear(const Duration(milliseconds: 2400));
      });
    }
  }

  void _scheduleClear(Duration delay) {
    _clearTimer?.cancel();
    _clearTimer = Timer(delay, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _entrance.dispose();
    _flow.dispose();
    _outcome.dispose();
    _stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PassIngestUiState state = widget.state;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark
        ? const Color(0xFFF5F5F7)
        : const Color(0xFF171719);
    final Color muted = ink.withValues(alpha: 0.58);

    final String semanticsLabel = _semanticsLabel(state);
    final Animation<double> fade = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );
    final bool revealsActivePass =
        state is PassIngestSucceeded &&
        state.item.status == TicketStatus.active;
    final Animation<double> revealOpacity = revealsActivePass
        ? Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(
              parent: _outcome,
              curve: const Interval(0.38, 1, curve: Curves.easeOutCubic),
            ),
          )
        : const AlwaysStoppedAnimation<double>(1);

    return FadeTransition(
      opacity: fade,
      child: FadeTransition(
        opacity: revealOpacity,
        child: Semantics(
          liveRegion: true,
          label: semanticsLabel,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _PassParticlePainter(
                      flow: _flow,
                      outcome: _outcome,
                      mode: _modeFor(state),
                      loadingStage: _stage,
                      isDark: isDark,
                      reduceMotion: _reduceMotion,
                    ),
                  ),
                ),
              ),
              _Content(state: state, outcome: _outcome, ink: ink, muted: muted),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ParticleMode { loading, success, archive, failure }

_ParticleMode _modeFor(PassIngestUiState state) {
  if (state is PassIngestFailed) return _ParticleMode.failure;
  if (state is PassIngestSucceeded) {
    return state.item.status == TicketStatus.expired
        ? _ParticleMode.archive
        : _ParticleMode.success;
  }
  return _ParticleMode.loading;
}

double _loadingStageFor(PassIngestUiState state) {
  if (state is! PassIngestRunning) return 1;
  return switch (state.phase) {
    PassIngestPhase.readingSource => 0,
    PassIngestPhase.submitting => 0.5,
    PassIngestPhase.syncingWallet => 1,
  };
}

String _semanticsLabel(PassIngestUiState state) {
  return switch (state) {
    PassIngestRunning() =>
      '${_loadingTitle(state)}. ${_loadingDescription(state)}',
    PassIngestSucceeded(:final item) when item.status == TicketStatus.expired =>
      'Pass archived. ${_subjectFor(item)}.',
    PassIngestSucceeded(:final item) => 'Pass added. ${_subjectFor(item)}.',
    PassIngestFailed(:final error) =>
      '${_errorTitle(error.code)}. ${error.message}',
    _ => '',
  };
}

String _loadingTitle(PassIngestRunning state) {
  return switch (state.phase) {
    PassIngestPhase.readingSource => 'Reading your ticket',
    PassIngestPhase.submitting when state.request is PnrPassIngestRequest =>
      'Finding your booking',
    PassIngestPhase.submitting => 'Building your pass',
    PassIngestPhase.syncingWallet => 'Syncing your wallet',
  };
}

String _loadingDescription(PassIngestRunning state) {
  return switch (state.phase) {
    PassIngestPhase.readingSource =>
      'Checking the file and looking for its gate code.',
    PassIngestPhase.submitting when state.request is PnrPassIngestRequest =>
      'Checking the PNR and preparing your train pass.',
    PassIngestPhase.submitting =>
      'Extracting the details and preparing your pass.',
    PassIngestPhase.syncingWallet =>
      'Fetching the finished pass and refreshing your wallet.',
  };
}

String _subjectFor(WalletPassItem item) {
  final String label = switch (item) {
    TrainPassItem(:final ticket) => ticket.trainName,
    MoviePassItem(:final pass) => pass.movieTitle,
    BusPassItem(:final pass) => pass.operator,
  };
  return label.trim().isEmpty ? 'Your pass' : label.trim();
}

String _errorTitle(PassIngestCode code) {
  return switch (code) {
    PassIngestCode.needsRemote => 'Connect a server',
    PassIngestCode.needsAuth => 'Sign in required',
    PassIngestCode.invalidPnr => 'Check the PNR',
    PassIngestCode.fileTooLarge => 'File too large',
    PassIngestCode.unsupportedFile => 'Unsupported file',
    PassIngestCode.rateLimited => 'Scan limit reached',
    PassIngestCode.unreadable => 'Could not read pass',
    PassIngestCode.failed => 'Could not add pass',
  };
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.outcome,
    required this.ink,
    required this.muted,
  });

  final PassIngestUiState state;
  final Animation<double> outcome;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    if (state is PassIngestRunning) return const SizedBox.shrink();

    if (state is PassIngestSucceeded &&
        (state as PassIngestSucceeded).item.status == TicketStatus.active) {
      return const SizedBox.shrink();
    }

    final String title;
    final String description;
    if (state case PassIngestSucceeded(:final item)) {
      title = 'Pass archived';
      description =
          '${_subjectFor(item)} was saved to Archive because its date has passed.';
    } else if (state case PassIngestFailed(:final error)) {
      title = _errorTitle(error.code);
      description = error.message;
    } else {
      return const SizedBox.shrink();
    }

    final Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );

    return FadeTransition(
      opacity: CurvedAnimation(parent: outcome, curve: Curves.easeOutCubic),
      child: content,
    );
  }
}

class _PassParticlePainter extends CustomPainter {
  _PassParticlePainter({
    required this.flow,
    required this.outcome,
    required this.mode,
    required this.loadingStage,
    required this.isDark,
    required this.reduceMotion,
  }) : super(
         repaint: Listenable.merge(<Listenable>[flow, outcome, loadingStage]),
       );

  final Animation<double> flow;
  final Animation<double> outcome;
  final _ParticleMode mode;
  final Animation<double> loadingStage;
  final bool isDark;
  final bool reduceMotion;

  static final List<_ParticleSeed> _seeds = _makeSeeds();
  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.48);
    final double radius = math.min(size.width * 0.44, size.height * 0.34);
    final Color particleBright = isDark
        ? const Color(0xFFF9FAFF)
        : const Color(0xFF292D36);
    final Color particleCool = isDark
        ? const Color(0xFFA9C8E8)
        : const Color(0xFF637A94);
    final double time = reduceMotion ? 0 : flow.value * _tau;
    final double settle = outcome.value;
    final double motionSettle = _smoothstep(settle);

    final Paint particle = Paint()..style = PaintingStyle.fill;
    final Paint trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint halo = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    // One restrained pool of light ties the sharp grains together. No layer
    // blur per particle: just a radial wash and a few soft foreground glints.
    final double atmosphere = (isDark ? 0.055 : 0.022) * (1 - settle);
    canvas.drawCircle(
      center,
      radius * 1.1,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius * 1.1,
          <Color>[
            particleCool.withValues(alpha: atmosphere),
            particleCool.withValues(alpha: atmosphere * 0.4),
            particleCool.withValues(alpha: 0),
          ],
          <double>[0, 0.48, 1],
        ),
    );

    for (int i = 0; i < _seeds.length; i++) {
      final _ParticleSeed seed = _seeds[i];
      final Offset roaming = _flowPosition(
        seed,
        center: center,
        radius: radius,
        time: time,
        stage: loadingStage.value,
      );

      Offset position = roaming;
      if (!reduceMotion && mode == _ParticleMode.archive) {
        position = Offset.lerp(
          roaming,
          _archiveTarget(seed, center, radius),
          motionSettle,
        )!;
      } else if (!reduceMotion && mode == _ParticleMode.failure) {
        position = Offset.lerp(
          roaming,
          _failureTarget(seed, center, radius),
          motionSettle,
        )!;
      } else if (!reduceMotion && mode == _ParticleMode.success) {
        position = _successPosition(
          roaming,
          seed,
          center: center,
          radius: radius,
          settle: motionSettle,
        );
      }

      final double cycle = _fallCycle(seed, time);
      final double depth = _depthFor(seed);
      final double edge = 1 - _smoothstep((seed.radial - 0.8) / 0.2);
      final double shimmer = reduceMotion
          ? 0.82
          : 0.84 + 0.16 * math.sin(time + seed.phase * _tau);
      final double life =
          _smoothstep(cycle / 0.14) * _smoothstep((1 - cycle) / 0.16);
      double alpha = seed.alpha * (0.38 + depth * 0.62) * edge * shimmer * life;
      if (mode == _ParticleMode.success) {
        alpha *= 1 - _smoothstep((settle - 0.18) / 0.82);
      } else if (mode != _ParticleMode.loading) {
        alpha *= 1 - _smoothstep(settle);
      }

      final Color baseColor = Color.lerp(
        particleBright,
        particleCool,
        seed.coolness * 0.5,
      )!;
      final Color color = mode == _ParticleMode.failure
          ? Color.lerp(baseColor, const Color(0xFFCE756C), motionSettle * 0.65)!
          : baseColor;
      if (!reduceMotion &&
          i % 7 == 0 &&
          mode == _ParticleMode.loading &&
          cycle > 0.15 &&
          cycle < 0.85) {
        final Offset previous = _flowPosition(
          seed,
          center: center,
          radius: radius,
          time: time - 0.055,
          stage: loadingStage.value,
        );
        final Offset tail = Offset.lerp(previous, position, 0.28)!;
        trail
          ..color = color.withValues(alpha: alpha * 0.18)
          ..strokeWidth = 0.35 + seed.size * 0.3;
        canvas.drawLine(tail, position, trail);
      }
      final double grainRadius = 0.24 + seed.size * 0.48 + depth * depth * 0.48;
      if (i % 17 == 0 && depth > 0.55) {
        halo.color = color.withValues(alpha: alpha * (isDark ? 0.32 : 0.12));
        canvas.drawCircle(position, grainRadius * 2, halo);
      }
      particle.color = color.withValues(alpha: alpha);
      canvas.drawCircle(position, grainRadius, particle);
    }
  }

  static Offset _flowPosition(
    _ParticleSeed seed, {
    required Offset center,
    required double radius,
    required double time,
    required double stage,
  }) {
    final double cycle = _fallCycle(seed, time);
    final double gravity = math.pow(cycle, 1.8 + seed.speed * 0.4).toDouble();
    final double distance =
        radius *
        (0.2 + seed.radial * 0.8) *
        (1 - gravity * (0.9 + stage * 0.06));
    final double angle =
        seed.angle +
        (1 - distance / radius) * (2.6 + stage * 0.35) +
        seed.drift * 0.14 * math.sin(cycle * math.pi);
    final double depth = _depthFor(seed);
    final double perspective = 0.78 + depth * 0.26;
    final double x = math.cos(angle) * distance * perspective;
    final double y = math.sin(angle) * distance * (0.7 + depth * 0.2);
    // A slight tilt and depth separation give the field volume without a
    // literal ring or a hard silhouette. All motion is periodic at loop wrap.
    return center +
        Offset(
          x + y * 0.16,
          y - x * 0.12 + seed.depth * radius * 0.08 * (1 - gravity),
        );
  }

  static double _fallCycle(_ParticleSeed seed, double time) {
    final int fallsPerLoop = seed.speed > 0.68 ? 2 : 1;
    return (seed.phase + (time / _tau) * fallsPerLoop) % 1;
  }

  static double _depthFor(_ParticleSeed seed) => (seed.depth + 1) * 0.5;

  static Offset _successPosition(
    Offset roaming,
    _ParticleSeed seed, {
    required Offset center,
    required double radius,
    required double settle,
  }) {
    final Offset delta = roaming - center;
    final double angle =
        math.atan2(delta.dy, delta.dx) + settle * (0.38 + seed.speed * 0.24);
    final double distance = _lerp(
      delta.distance,
      radius * (0.035 + seed.radial * 0.045),
      settle,
    );
    return center + Offset.fromDirection(angle, distance);
  }

  static Offset _archiveTarget(
    _ParticleSeed seed,
    Offset center,
    double radius,
  ) {
    final double distance = radius * (0.23 + seed.radial * 0.075);
    return center + Offset.fromDirection(seed.angle, distance);
  }

  static Offset _failureTarget(
    _ParticleSeed seed,
    Offset center,
    double radius,
  ) {
    final double split = seed.phase > 0.5 ? 1 : -1;
    final double angle = seed.angle + split * 0.22;
    final double distance = radius * (0.3 + seed.radial * 0.24);
    return center +
        Offset.fromDirection(angle, distance) +
        Offset(split * radius * 0.075, split * seed.depth * radius * 0.025);
  }

  static List<_ParticleSeed> _makeSeeds() {
    final math.Random random = math.Random(0xD0C7E7);
    final List<_ParticleSeed> seeds = List<_ParticleSeed>.generate(
      840,
      (index) => _ParticleSeed(
        // Loose overlapping streams, with a fifth of the grains left free
        // around them so the silhouette never becomes a rigid spiral icon.
        angle: index % 5 == 0
            ? random.nextDouble() * _tau
            : (index % 3) * _tau / 3 + (random.nextDouble() - 0.5) * 0.48,
        radial: 0.035 + math.sqrt(random.nextDouble()) * 0.965,
        phase: random.nextDouble(),
        depth: random.nextDouble() * 2 - 1,
        drift: random.nextDouble() * 2 - 1,
        size: 0.28 + random.nextDouble() * 0.9,
        alpha: 0.34 + random.nextDouble() * 0.6,
        speed: 0.12 + random.nextDouble() * 0.88,
        coolness: random.nextDouble(),
      ),
      growable: false,
    );
    // Paint the faint distant grains first, sharp foreground grains last.
    seeds.sort((a, b) => a.depth.compareTo(b.depth));
    return seeds;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _smoothstep(double value) {
    final double t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(covariant _PassParticlePainter oldDelegate) =>
      oldDelegate.mode != mode ||
      oldDelegate.loadingStage != loadingStage ||
      oldDelegate.isDark != isDark ||
      oldDelegate.reduceMotion != reduceMotion;
}

class _ParticleSeed {
  const _ParticleSeed({
    required this.angle,
    required this.radial,
    required this.phase,
    required this.depth,
    required this.drift,
    required this.size,
    required this.alpha,
    required this.speed,
    required this.coolness,
  });

  final double angle;
  final double radial;
  final double phase;
  final double depth;
  final double drift;
  final double size;
  final double alpha;
  final double speed;
  final double coolness;
}
