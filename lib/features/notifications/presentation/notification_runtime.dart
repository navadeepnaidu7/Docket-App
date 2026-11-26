import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../tickets/application/api_providers.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../../tickets/data/remote_pass_repository.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/presentation/ticket_detail_screen.dart';
import '../../tickets/presentation/movie_pass_detail_screen.dart';
import '../../tickets/presentation/bus/bus_pass_detail_screen.dart';
import '../../tickets/presentation/flight/flight_pass_detail_screen.dart';
import '../application/notification_service.dart';
import '../application/notification_preferences_provider.dart';
import '../domain/reminder_planner.dart';

/// Read by Settings to refresh system permission and Firebase availability.
final notificationStatusProvider = StateProvider<int>((ref) => 0);

class NotificationRuntime extends ConsumerStatefulWidget {
  const NotificationRuntime({
    super.key,
    required this.navigatorKey,
    required this.child,
    required this.walletReady,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool walletReady;
  @override
  ConsumerState<NotificationRuntime> createState() =>
      _NotificationRuntimeState();
}

class _NotificationRuntimeState extends ConsumerState<NotificationRuntime>
    with WidgetsBindingObserver {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _retry;
  bool _active = false, _queued = false, _prompting = false, _routing = false;
  final _pendingTaps = <String>[];
  bool _walletReady = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!Platform.isAndroid) return;
    final service = ref.read(notificationServiceProvider);
    // Subscribe before initialization so cold-start launch details are retained.
    _subscriptions.add(
      service.gateway.taps.listen((id) {
        _pendingTaps.add(id);
        unawaited(_route());
      }),
    );
    _subscriptions.add(
      service.gateway.tokenChanges.listen((token) {
        service.tokenRefreshed(token);
        _queue();
      }),
    );
    _subscriptions.add(
      service.gateway.foreground.listen((notice) async {
        final prefs = ref.read(notificationPreferencesProvider);
        final account = ref.read(authControllerProvider);
        if (!account.realAccount ||
            !account.session.isSignedIn ||
            account.busy) {
          return;
        }
        if (notice.channel == 'booking_updates'
            ? !prefs.bookingUpdates
            : !prefs.journeyLive) {
          return;
        }
        try {
          await service.gateway.show(notice);
        } catch (_) {}
      }),
    );
    try {
      await service.initialize();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _active = true;
    _retry = Timer.periodic(const Duration(minutes: 1), (_) => _queue());
    _queue();
  }

  void _queue() {
    if (!_active || !mounted || _queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) unawaited(_reconcile());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _reconcile() async {
    final service = ref.read(notificationServiceProvider);
    final passes = ref.read(passListProvider).valueOrNull;
    if (passes == null) return;
    final account = ref.read(authControllerProvider);
    if (account.busy) return;
    _walletReady =
        widget.walletReady ||
        (await SharedPreferences.getInstance()).getBool(
              'has_seen_onboarding',
            ) ==
            true;
    if (!mounted) return;
    final preferences = ref.read(notificationPreferencesProvider.notifier);
    try {
      await service.reconcile(
        passes: passes,
        preferences: preferences,
        account: account.realAccount && !account.busy
            ? account.session.id
            : null,
        api: ref.read(docketApiClientProvider),
        serverPasses: ref.read(passRepositoryProvider) is RemotePassRepository,
      );
    } catch (_) {
      /* Retry on resume, changes, and the next periodic attempt. */
    }
    if (!mounted) return;
    ref.read(notificationStatusProvider.notifier).state++;
    unawaited(_route());
    await preferences.ready;
    if (!mounted ||
        !_walletReady ||
        _prompting ||
        service.permitted ||
        preferences.value.promptDismissed) {
      return;
    }
    final now = DateTime.now();
    if (!passes.any(
      (p) =>
          reminderEligible(p) && (reminderStart(p, now)?.isAfter(now) ?? false),
    )) {
      return;
    }
    final nav = widget.navigatorKey.currentState;
    final context = nav?.overlay?.context;
    if (context == null || !context.mounted) return;
    _prompting = true;
    final enabled = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const NotificationPermissionSheet(),
    );
    if (mounted) {
      await preferences.set(preferences.value.copyWith(promptDismissed: true));
      if (enabled == true) {
        try {
          await service.gateway.requestPermission();
        } catch (_) {}
      }
      _queue();
    }
    _prompting = false;
  }

  Future<void> _route() async {
    if (_routing || !mounted || !_walletReady) return;
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    _routing = true;
    try {
      while (_pendingTaps.isNotEmpty && mounted) {
        final id = _pendingTaps.first;
        final passes = ref.read(passListProvider).valueOrNull;
        if (passes == null) break;
        WalletPassItem? item;
        for (final p in passes) {
          if (p.id == id) item = p;
        }
        final account = ref.read(authControllerProvider);
        if (account.busy) break;
        if (item == null && !account.realAccount) {
          // Cold-start taps can arrive before secure-session hydration. Keep
          // them queued until the wallet/account is ready rather than dropping.
          break;
        }
        if (item == null && account.realAccount) {
          try {
            item = await ref.read(docketApiClientProvider)?.fetchPassById(id);
          } catch (_) {
            break;
          }
        }
        if (!mounted) break;
        _pendingTaps.removeAt(0);
        if (item == null) continue;
        final page = switch (item) {
          TrainPassItem(:final ticket) => TicketDetailScreen(ticket: ticket),
          MoviePassItem(:final pass) => MoviePassDetailScreen(pass: pass),
          BusPassItem(:final pass) => BusPassDetailScreen(pass: pass),
          FlightPassItem(:final pass) => FlightPassDetailScreen(pass: pass),
        };
        await nav.push(MaterialPageRoute<void>(builder: (_) => page));
      }
    } finally {
      _routing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passListProvider, (_, _) => _queue());
    ref.listen(notificationPreferencesProvider, (_, _) => _queue());
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.session.id != next.session.id ||
          previous?.session.isSignedIn != next.session.isSignedIn) {
        ref.read(notificationServiceProvider).enterAccount(next.session.id);
      }
      _queue();
    });
    return widget.child;
  }
}

class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A reminder before you go',
            style: AppFonts.ui(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'Docket can remind you before a trip or show, even offline. You choose what to receive in Settings.',
            style: AppFonts.ui(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Turn on'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
}
