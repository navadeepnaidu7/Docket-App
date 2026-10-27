import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_theme.dart';

/// A personal hello with a bundled animated emoji, played once on entry.
class AccountGreeting extends StatefulWidget {
  const AccountGreeting({super.key, required this.displayName});

  final String displayName;

  @override
  State<AccountGreeting> createState() => _AccountGreetingState();
}

class _AccountGreetingState extends State<AccountGreeting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this)
    ..addStatusListener((status) {
      // The asset's first frame is its authored resting pose.
      if (status == AnimationStatus.completed) _wave.value = 0;
    });
  bool _loaded = false;
  bool _played = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncWave();
  }

  void _syncWave() {
    if (_reduceMotion) {
      _wave.stop();
      _wave.value = 0;
    } else if (_loaded && !_played) {
      _played = true;
      _wave.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName.trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? 'Hey there' : 'Hey $firstName';
    return Semantics(
      label: greeting,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.ui(
                fontSize: 24,
                height: 1.3,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
                color: AppTheme.ink(Theme.of(context).brightness),
              ),
            ),
          ),
          const SizedBox(width: 8),
          RepaintBoundary(
            child: Lottie.asset(
              'assets/emoji/waving_hand.json',
              controller: _wave,
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              repeat: false,
              onLoaded: (composition) {
                if (!mounted) return;
                _wave.duration = composition.duration;
                _loaded = true;
                _syncWave();
              },
            ),
          ),
        ],
      ),
    );
  }
}
