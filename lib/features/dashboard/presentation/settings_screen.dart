import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/dev/dev_config.dart';
import '../../../core/dev/dev_flags.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/haptics/haptics_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/theme_time_picker.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../application/auth_session_provider.dart';
import '../application/card_shine_border_provider.dart';
import '../application/profile_avatar_shape_provider.dart';
import '../application/wallet_filter_provider.dart';
import '../application/nav_icon_style_provider.dart';
import '../application/nav_labels_provider.dart';
import 'user_card_detail_screen.dart';
import 'widgets/membership_mesh.dart';

/// Apple Card–like hero dimensions (scrolls with the settings list).
const double kSettingsHeroHeight = 226.0;
const double kSettingsHeroRadius = 22.0;

/// Credits shown under Settings → About (edit freely).
const String kDeveloperDisplayName = 'Navadeep Naidu';
const String kDeveloperEmail = 'hello@docket.app';
const String kDeveloperGithubUrl = 'https://github.com/navadeepnaidu7';
const String kDeveloperWebsiteUrl = 'https://navadeepnaidu.com';
const String kDeveloperBlogUrl = 'https://blog.navadeepnaidu.com';
const String kDeveloperXUrl = 'https://x.com/navadeep_naidu7';

/// App version label (keep in sync with `pubspec.yaml` `version:`).
const String kAppVersion = '1.0.0';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// While true, pause continuous effects so scroll isn't fighting paint work.
  bool _isScrolling = false;
  Timer? _scrollIdleTimer;

  @override
  void dispose() {
    _scrollIdleTimer?.cancel();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Any scroll activity → pause; resume shortly after motion settles.
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _scrollIdleTimer?.cancel();
      if (!_isScrolling) {
        setState(() => _isScrolling = true);
      }
      _scrollIdleTimer = Timer(const Duration(milliseconds: 140), () {
        if (mounted && _isScrolling) {
          setState(() => _isScrolling = false);
        }
      });
    } else if (notification is ScrollEndNotification) {
      _scrollIdleTimer?.cancel();
      _scrollIdleTimer = Timer(const Duration(milliseconds: 80), () {
        if (mounted && _isScrolling) {
          setState(() => _isScrolling = false);
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color scaffoldBg =
        isDark ? const Color(0xFF0A0A0D) : const Color(0xFFF8F8FA);
    final Color surface =
        isDark ? const Color(0xFF16161A) : const Color(0xFFFFFFFF);
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.05);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);
    final AuthSession session = ref.watch(authSessionProvider);

    final bool effectsOn = !_isScrolling;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              // Single scroll: card is a normal list item (not sticky).
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  cacheExtent: 480,
                  // Avoid keep-alive overhead for a short settings list.
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  children: [
                  RepaintBoundary(
                    child: _AnimatedPressScale(
                      onTap: () {
                        HapticService.select();
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const UserCardDetailScreen(),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: kSettingsHeroHeight,
                        child: WalletMembershipCard(
                          passports: passports,
                          idDocs: idDocs,
                          isDark: isDark,
                          enableMotion: effectsOn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: RepaintBoundary(
                      child: _TapToOpenShineLabel(
                        isDark: isDark,
                        ink: ink,
                        enabled: effectsOn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsSection(
                    title: 'Appearance',
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      const _ThemeAppearanceBlock(),
                      const _SettingsDivider(),
                      _SettingsToggleRow(
                        icon: Icons.vibration_rounded,
                        iconColor: const Color(0xFFE07A2F),
                        title: 'Haptics',
                        value: ref.watch(hapticsEnabledProvider),
                        onChanged: (_) {
                          final bool enabled =
                              ref.read(hapticsEnabledProvider);
                          if (enabled) HapticService.select();
                          ref.read(hapticsEnabledProvider.notifier).toggle();
                        },
                      ),
                      const _SettingsDivider(),
                      _ProfileAvatarShapeRow(
                        shape: ref.watch(profileAvatarShapeProvider),
                        onTap: () {
                          HapticService.select();
                          ref.read(profileAvatarShapeProvider.notifier).toggle();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Navigation',
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _SettingsToggleRow(
                        icon: CupertinoIcons.textformat_abc,
                        iconColor: const Color(0xFF2F6FED),
                        title: 'Labels',
                        value: ref.watch(showNavLabelsProvider),
                        onChanged: (_) {
                          HapticService.select();
                          ref.read(showNavLabelsProvider.notifier).toggle();
                        },
                      ),
                      const _SettingsDivider(),
                      _NavIconStyleRow(
                        icon: CupertinoIcons.creditcard_fill,
                        iconColor: const Color(0xFF2A9D6B),
                        title: 'IDs icons',
                        style: ref.watch(navIconStylesProvider).ids,
                        onTap: () {
                          HapticService.select();
                          final NavIconStyle current =
                              ref.read(navIconStylesProvider).ids;
                          ref.read(navIconStylesProvider.notifier).setIdsStyle(
                                current == NavIconStyle.classic
                                    ? NavIconStyle.vertical
                                    : NavIconStyle.classic,
                              );
                        },
                      ),
                      const _SettingsDivider(),
                      _NavIconStyleRow(
                        icon: CupertinoIcons.ticket_fill,
                        iconColor: const Color(0xFF1A9BB5),
                        title: 'Passes icons',
                        style: ref.watch(navIconStylesProvider).passes,
                        onTap: () {
                          HapticService.select();
                          final NavIconStyle current =
                              ref.read(navIconStylesProvider).passes;
                          ref
                              .read(navIconStylesProvider.notifier)
                              .setPassesStyle(
                                current == NavIconStyle.classic
                                    ? NavIconStyle.vertical
                                    : NavIconStyle.classic,
                              );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Experimental',
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _SettingsToggleRow(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: const Color(0xFF5E5CE6),
                        title: 'Card shine border',
                        subtitle:
                            'After 3.5s on ID cards, a soft iridescent border appears',
                        value: ref.watch(cardShineBorderProvider),
                        onChanged: (_) {
                          HapticService.select();
                          ref.read(cardShineBorderProvider.notifier).toggle();
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsToggleRow(
                        icon: Icons.filter_list_rounded,
                        iconColor: const Color(0xFF2F6FED),
                        title: 'Card category filter',
                        subtitle:
                            'Filter menu on Home — pick a type or clear with ×',
                        value: ref.watch(walletFilterEnabledProvider),
                        onChanged: (_) {
                          HapticService.select();
                          ref
                              .read(walletFilterEnabledProvider.notifier)
                              .toggle();
                        },
                      ),
                    ],
                  ),
                  if (session.isSignedIn) ...[
                    const SizedBox(height: 20),
                    _SettingsSection(
                      title: 'Account',
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                      children: [
                        _SettingsLinkRow(
                          icon: Icons.manage_accounts_rounded,
                          iconColor: const Color(0xFF2F6FED),
                          title: 'Manage account',
                          subtitle: session.email,
                          onTap: () => _showAccountComingSoon(context),
                        ),
                        const _SettingsDivider(),
                        _SettingsLinkRow(
                          icon: Icons.logout_rounded,
                          iconColor: const Color(0xFFFF3B30),
                          title: 'Sign out',
                          onTap: () => _confirmSignOut(context, ref),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'About',
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _SettingsLinkRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF8E8E93),
                        title: 'About Docket',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AboutDocketScreen(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsLinkRow(
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFF8E8E93),
                        title: 'About developer',
                        subtitle: kDeveloperDisplayName,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AboutDeveloperScreen(),
                            ),
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _SettingsLinkRow(
                        icon: Icons.mail_outline_rounded,
                        iconColor: const Color(0xFF8E8E93),
                        title: 'Mail to developer',
                        subtitle: kDeveloperEmail,
                        onTap: () => _mailToDeveloper(context),
                      ),
                    ],
                  ),
                  if (DevConfig.showDevMenu) ...[
                    const SizedBox(height: 20),
                    _DeveloperSection(
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                    ),
                  ],
                  _DocketSettingsWatermark(isDark: isDark, ink: ink),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _mailToDeveloper(BuildContext context) async {
  HapticService.tap();
  final Uri uri = Uri(
    scheme: 'mailto',
    path: kDeveloperEmail,
    queryParameters: <String, String>{
      'subject': 'Docket feedback',
    },
  );

  try {
    final bool launched = await launchUrl(uri);
    if (launched || !context.mounted) return;
  } catch (_) {
    // Fall through to clipboard fallback.
  }

  if (!context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: kDeveloperEmail));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Email copied — no mail app available'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> _openDeveloperLink(BuildContext context, String url) async {
  HapticService.tap();
  final Uri uri = Uri.parse(url);
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !context.mounted) return;
  } catch (_) {
    // Fall through to clipboard fallback.
  }

  if (!context.mounted) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Link copied — couldn’t open the browser'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> _showAccountComingSoon(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Coming soon'),
        content: const Text(
          'Account management will connect to your Google account in a '
          'future update.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Got it',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final bool? confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (BuildContext ctx) => CupertinoActionSheet(
      title: const Text('Sign out of Docket?'),
      message: const Text('You can sign back in anytime from the wallet card.'),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sign out'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (confirmed != true) return;
  await setMockSignedIn(ref, false);
}

Future<void> _handleGoogleSignInTap(BuildContext context, WidgetRef ref) async {
  HapticService.confirm();
  if (!DevConfig.allowRuntimeOverrides) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Google sign-in coming soon'),
          content: const Text(
            'Account sign-in is not available yet. This will connect to your '
            'Google account in a future update.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Got it',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
    return;
  }
  // Placeholder mock: flips signed-in UI (same as Developer → Mock signed in).
  await setMockSignedIn(ref, true);
}

// ── Apple Card–inspired wallet membership surface ────────────────────────────
// Wash palette + painter live in membership_mesh.dart (shared with profile).

class WalletMembershipCard extends ConsumerStatefulWidget {
  const WalletMembershipCard({
    super.key,
    required this.passports,
    required this.idDocs,
    required this.isDark,
    this.enableMotion = true,
  });

  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final bool isDark;

  /// When false (e.g. parent list is scrolling), freeze the fluid wash.
  final bool enableMotion;

  @override
  ConsumerState<WalletMembershipCard> createState() => _WalletMembershipCardState();
}

class _WalletMembershipCardState extends ConsumerState<WalletMembershipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryAnimation;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..addListener(_onMotionTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);

    final Animation<double>? nextPrimary = route?.animation;
    if (!identical(nextPrimary, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteChanged);
      _routeAnimation = nextPrimary;
      _routeAnimation?.addStatusListener(_onRouteChanged);
    }

    final Animation<double>? nextSecondary = route?.secondaryAnimation;
    if (!identical(nextSecondary, _secondaryAnimation)) {
      _secondaryAnimation?.removeListener(_onSecondaryTick);
      _secondaryAnimation = nextSecondary;
      _secondaryAnimation?.addListener(_onSecondaryTick);
    }

    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant WalletMembershipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableMotion != widget.enableMotion) {
      _syncMotion();
    }
  }

  void _onRouteChanged(AnimationStatus status) => _syncMotion();

  void _onSecondaryTick() => _syncMotion();

  void _onMotionTick() {
    // ~12 unique frames per controller cycle — not 60/120.
    final double next = (_motion.value * 12).floorToDouble() / 12.0;
    if (next != _phase.value) {
      _phase.value = next;
    }
  }

  void _syncMotion() {
    if (!mounted) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final bool routeVisible = route == null ||
        (route.isCurrent && (route.secondaryAnimation?.value ?? 0) == 0);
    final bool shouldRun = widget.enableMotion &&
        routeVisible &&
        TickerMode.valuesOf(context).enabled;
    if (shouldRun) {
      if (!_motion.isAnimating) _motion.repeat();
    } else if (_motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteChanged);
    _secondaryAnimation?.removeListener(_onSecondaryTick);
    _motion
      ..removeListener(_onMotionTick)
      ..dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DevFlags devFlags = ref.watch(devFlagsProvider);
    final AuthSession session = ref.watch(authSessionProvider);
    final PassportProfile? primaryPassport =
        widget.passports.isNotEmpty ? widget.passports.first : null;
    final IdDocument? primaryId =
        widget.idDocs.isNotEmpty ? widget.idDocs.first : null;

    final String name = _resolveName(session, primaryPassport, primaryId);
    final List<Color> washes = walletWashColors(
      passports: widget.passports,
      idDocs: widget.idDocs,
      scheme: devFlags.cardFluidScheme,
    );

    // Crisp Light Titanium Apple Card styling (dark charcoal text for maximum contrast on white titanium)
    const Color ink = Color(0xFF1C1C1E);
    const Color inkMuted = Color(0xFF636366);
    final Color border = Colors.black.withValues(alpha: 0.08);
    final bool hasDocs =
        widget.passports.isNotEmpty || widget.idDocs.isNotEmpty;
    final bool signedIn = session.isSignedIn;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kSettingsHeroRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSettingsHeroRadius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Animated wash layer only — face text stays static.
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _phase,
                builder: (BuildContext context, double phase, _) {
                  return MembershipMeshBackground(
                    washes: washes,
                    phase: phase,
                    empty: !hasDocs,
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kSettingsHeroRadius),
                border: Border.all(color: border, width: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'July 2026',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      color: inkMuted,
                    ),
                  ),
                  const Spacer(),
                  if (signedIn)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.12,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '#4377',
                          style: GoogleFonts.robotoMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: inkMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            // Own detector so this does not open card detail.
                            child: _GoogleSignInOnCardButton(
                              onTap: () =>
                                  _handleGoogleSignInTap(context, ref),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '#4377',
                            style: GoogleFonts.robotoMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: inkMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveName(
    AuthSession session,
    PassportProfile? passport,
    IdDocument? id,
  ) {
    final String? accountName = session.displayName?.trim();
    if (accountName != null && accountName.isNotEmpty) {
      return accountName;
    }
    if (passport != null && passport.name.trim().isNotEmpty) {
      return passport.name.trim();
    }
    if (id != null && id.holderName.trim().isNotEmpty) {
      return id.holderName.trim();
    }
    return 'Your wallet';
  }
}

/// Official Google button sized for the membership card face.
class _GoogleSignInOnCardButton extends StatelessWidget {
  const _GoogleSignInOnCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AnimatedPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: SvgPicture.asset(
          AppAssets.googleSignInButton,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

/// Debug / profile only — mock vs consumer data sources.
class _DeveloperSection extends ConsumerWidget {
  const _DeveloperSection({
    required this.surface,
    required this.borderColor,
    required this.isDark,
  });

  final Color surface;
  final Color borderColor;
  final bool isDark;

  Future<void> _editApiBaseUrl(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final TextEditingController controller =
        TextEditingController(text: flags.apiBaseUrl);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('API base URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com',
              helperText: 'No trailing slash. Empty forces mock.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    HapticService.select();
    await ref.read(devFlagsProvider.notifier).setApiBaseUrl(result);
  }

  Future<void> _selectFluidScheme(BuildContext context, WidgetRef ref) async {
    final DevFlags flags = ref.read(devFlagsProvider);
    final CardFluidScheme? selected = await showDialog<CardFluidScheme>(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Card Fluidic Gradient Scheme'),
          children: CardFluidScheme.values.map((CardFluidScheme scheme) {
            final bool isCurrent = scheme == flags.cardFluidScheme;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, scheme),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isCurrent
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isCurrent ? const Color(0xFF5E5CE6) : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scheme.label,
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
    if (selected != null) {
      HapticService.select();
      await ref.read(devFlagsProvider.notifier).setCardFluidScheme(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DevFlags flags = ref.watch(devFlagsProvider);
    final String urlLabel = flags.apiBaseUrl.isEmpty
        ? 'Not set'
        : flags.apiBaseUrl;

    return _SettingsSection(
      title: 'Developer',
      surface: surface,
      borderColor: borderColor,
      isDark: isDark,
      children: <Widget>[
        _SettingsToggleRow(
          icon: Icons.science_rounded,
          iconColor: const Color(0xFFAF52DE),
          title: 'Use mock passes',
          subtitle: flags.isMockPassesActive
              ? 'Fixtures · demo train & movie cards'
              : 'Remote repository (consumer path)',
          value: flags.useMockPasses,
          onChanged: (bool v) async {
            HapticService.select();
            await ref.read(devFlagsProvider.notifier).setUseMockPasses(v);
          },
        ),
        const _SettingsDivider(),
        _SettingsToggleRow(
          icon: Icons.account_circle_rounded,
          iconColor: const Color(0xFF2F6FED),
          title: 'Mock signed in',
          subtitle: flags.mockSignedIn
              ? 'Card shows name · Account section on'
              : 'Card shows Google button · signed out',
          value: flags.mockSignedIn,
          onChanged: (bool v) async {
            HapticService.select();
            await ref.read(devFlagsProvider.notifier).setMockSignedIn(v);
          },
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.palette_rounded,
          iconColor: const Color(0xFF5E5CE6),
          title: 'Card fluid gradient scheme',
          subtitle: flags.cardFluidScheme.label,
          onTap: () => _selectFluidScheme(context, ref),
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.link_rounded,
          iconColor: const Color(0xFF2F6FED),
          title: 'API base URL',
          subtitle: urlLabel,
          onTap: () => _editApiBaseUrl(context, ref),
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.refresh_rounded,
          iconColor: const Color(0xFF30D158),
          title: 'Reload passes',
          onTap: () {
            HapticService.select();
            ref.read(passListProvider.notifier).refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing passes…'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const _SettingsDivider(),
        _SettingsLinkRow(
          icon: Icons.restart_alt_rounded,
          iconColor: const Color(0xFF8E8E93),
          title: 'Reset dev flags',
          subtitle: 'Compile-time defaults',
          onTap: () async {
            HapticService.select();
            await ref
                .read(devFlagsProvider.notifier)
                .resetToCompileTimeDefaults();
          },
        ),
      ],
    );
  }
}

// ── "Tap to open" shimmer ───────────────────────────────────────────────────

/// Soft left→right shine across the membership-card affordance (~2.5s loop).
class _TapToOpenShineLabel extends StatefulWidget {
  const _TapToOpenShineLabel({
    required this.isDark,
    required this.ink,
    this.enabled = true,
  });

  final bool isDark;
  final Color ink;
  final bool enabled;

  @override
  State<_TapToOpenShineLabel> createState() => _TapToOpenShineLabelState();
}

class _TapToOpenShineLabelState extends State<_TapToOpenShineLabel>
    with SingleTickerProviderStateMixin {
  /// Slow glint across the affordance.
  static const Duration _period = Duration(milliseconds: 2500);

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _period);
    _syncShine();
  }

  @override
  void didUpdateWidget(covariant _TapToOpenShineLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _syncShine();
    }
  }

  void _syncShine() {
    if (widget.enabled) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else if (_ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = widget.ink.withValues(
      alpha: widget.isDark ? 0.40 : 0.48,
    );
    // Soft peak — hard pure-white edges read as letter-by-letter strobing.
    final Color mid = widget.isDark
        ? Colors.white.withValues(alpha: 0.72)
        : widget.ink.withValues(alpha: 0.72);
    final Color peak = widget.isDark
        ? Colors.white.withValues(alpha: 0.92)
        : widget.ink.withValues(alpha: 0.90);

    final TextStyle labelStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      // Solid for ShaderMask; gradient supplies the visible color.
      color: Colors.white,
    );

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, Widget? child) {
        // Ease the travel so it doesn't feel linear/mechanical.
        final double t = Curves.easeInOutCubic.transform(_ctrl.value);

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            // Wide band (~55% of label width) slides in pixel space so the
            // highlight covers multiple glyphs at once instead of snapping
            // letter-to-letter.
            final double w = bounds.width;
            final double band = w * 0.55;
            // Travel fully off-screen left → fully off-screen right.
            final double x = (w + band) * t - band;

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                base,
                base,
                mid,
                peak,
                mid,
                base,
                base,
              ],
              stops: const <double>[
                0.0,
                0.28,
                0.42,
                0.50,
                0.58,
                0.72,
                1.0,
              ],
              tileMode: TileMode.clamp,
              transform: _ShimmerSlide(x / w),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Tap to open', style: labelStyle),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 10,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Translates a gradient along X in units of the shader bounds width.
class _ShimmerSlide extends GradientTransform {
  const _ShimmerSlide(this.dxInWidths);

  final double dxInWidths;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * dxInWidths, 0, 0);
  }
}

// ── Appearance: theme preference + schedule ────────────────────────────────

class _ThemeAppearanceBlock extends ConsumerWidget {
  const _ThemeAppearanceBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeControllerState themeState = ref.watch(themeControllerProvider);
    final ThemeSettings settings = themeState.settings;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    // Stronger secondary labels in dark mode so the block reads clearly.
    final Color muted = ink.withValues(alpha: isDark ? 0.62 : 0.55);
    final Color titleColor = isDark ? const Color(0xFFF2F2F7) : ink;

    final String? statusSubtitle = _themeStatusSubtitle(themeState);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const _SettingsRowIcon(
                    icon: Icons.brightness_6_rounded,
                    color: Color(0xFF6E40C9),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Theme',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (statusSubtitle != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    statusSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      color: muted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _ThemeSegmentedControl(
                value: settings.preference,
                onChanged: (AppThemePreference next) {
                  HapticService.select();
                  ref.read(themeControllerProvider.notifier).setPreference(next);
                },
              ),
            ],
          ),
        ),
        if (settings.preference == AppThemePreference.schedule) ...[
          const _SettingsDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Schedule',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 10),
                _ScheduleKindSegmented(
                  value: settings.scheduleKind,
                  onChanged: (ScheduleKind kind) {
                    HapticService.select();
                    ref
                        .read(themeControllerProvider.notifier)
                        .setScheduleKind(kind);
                  },
                ),
              ],
            ),
          ),
          if (settings.scheduleKind == ScheduleKind.custom) ...[
            const _SettingsDivider(),
            _ThemeTimeRow(
              title: 'Light from',
              minutes: settings.lightStartMinutes,
              onTap: () async {
                final int? picked = await showThemeTimePicker(
                  context: context,
                  title: 'Light from',
                  initialMinutes: settings.lightStartMinutes,
                );
                if (picked == null) return;
                HapticService.select();
                await ref
                    .read(themeControllerProvider.notifier)
                    .setLightStartMinutes(picked);
              },
            ),
            const _SettingsDivider(),
            _ThemeTimeRow(
              title: 'Dark from',
              minutes: settings.lightEndMinutes,
              onTap: () async {
                final int? picked = await showThemeTimePicker(
                  context: context,
                  title: 'Dark from',
                  initialMinutes: settings.lightEndMinutes,
                );
                if (picked == null) return;
                HapticService.select();
                await ref
                    .read(themeControllerProvider.notifier)
                    .setLightEndMinutes(picked);
              },
            ),
          ],
        ],
      ],
    );
  }
}

String? _themeStatusSubtitle(ThemeControllerState state) {
  final ThemeSettings s = state.settings;
  if (s.preference == AppThemePreference.light) return 'Always light';
  if (s.preference == AppThemePreference.dark) return 'Always dark';
  if (s.preference == AppThemePreference.system) {
    final Brightness platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final String side = platform == Brightness.dark ? 'Dark' : 'Light';
    return 'Matches device · $side now';
  }

  final int start = s.effectiveLightStartMinutes;
  final int end = s.effectiveLightEndMinutes;
  final String range =
      '${formatMinutesOfDay(start)} – ${formatMinutesOfDay(end)}';

  if (s.scheduleKind == ScheduleKind.custom) {
    return 'Light $range';
  }

  // Sunrise–sunset uses fixed local day window (device clock).
  if (state.resolvedMode == ThemeMode.light) {
    return 'Light until ${formatMinutesOfDay(end)} · $range';
  }
  return 'Dark until ${formatMinutesOfDay(start)} · $range';
}

class _ThemeSegmentedControl extends StatelessWidget {
  const _ThemeSegmentedControl({
    required this.value,
    required this.onChanged,
  });

  final AppThemePreference value;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PillSegmented<AppThemePreference>(
      value: value,
      segments: const <(AppThemePreference, String)>[
        (AppThemePreference.light, 'Light'),
        (AppThemePreference.dark, 'Dark'),
        (AppThemePreference.system, 'Device'),
        (AppThemePreference.schedule, 'Schedule'),
      ],
      onChanged: onChanged,
    );
  }
}

class _ScheduleKindSegmented extends StatelessWidget {
  const _ScheduleKindSegmented({
    required this.value,
    required this.onChanged,
  });

  final ScheduleKind value;
  final ValueChanged<ScheduleKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PillSegmented<ScheduleKind>(
      value: value,
      segments: const <(ScheduleKind, String)>[
        (ScheduleKind.sunriseSunset, 'Sunrise–sunset'),
        (ScheduleKind.custom, 'Custom'),
      ],
      onChanged: onChanged,
    );
  }
}

/// iOS-style sliding segmented control with press scale + thumb motion.
class _PillSegmented<T> extends StatefulWidget {
  const _PillSegmented({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;

  @override
  State<_PillSegmented<T>> createState() => _PillSegmentedState<T>();
}

class _PillSegmentedState<T> extends State<_PillSegmented<T>> {
  static const double _height = 40;
  static const double _pad = 3;
  static const Duration _slideDuration = Duration(milliseconds: 280);
  static const Curve _slideCurve = Curves.easeOutCubic;

  int? _pressedIndex;

  int get _selectedIndex {
    final int i = widget.segments.indexWhere((e) => e.$1 == widget.value);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    // Dark: deeper track + brighter elevated thumb for clear contrast.
    final Color track = isDark
        ? const Color(0xFF0C0C10)
        : ink.withValues(alpha: 0.07);
    final Color trackBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.04);
    final Color thumbBg = isDark
        ? const Color(0xFF3A3A44)
        : const Color(0xFFFFFFFF);
    final Color thumbBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.04);
    final Color selectedFg =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
    final Color unselectedFg = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : ink.withValues(alpha: 0.48);

    final int count = widget.segments.length;
    final int selected = _selectedIndex;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double innerW = constraints.maxWidth - _pad * 2;
        final double segmentW = innerW / count;
        final double thumbLeft = _pad + selected * segmentW;

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: trackBorder, width: 0.5),
          ),
          child: Stack(
            children: <Widget>[
              // Sliding thumb
              AnimatedPositioned(
                duration: _slideDuration,
                curve: _slideCurve,
                left: thumbLeft,
                width: segmentW,
                top: _pad,
                bottom: _pad,
                child: AnimatedScale(
                  scale: _pressedIndex == selected ? 0.96 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: thumbBg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: thumbBorder, width: 0.5),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.45 : 0.08,
                          ),
                          blurRadius: isDark ? 10 : 8,
                          offset: const Offset(0, 2),
                        ),
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Labels + hit targets
              Row(
                children: <Widget>[
                  for (int i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => setState(() => _pressedIndex = i),
                        onTapUp: (_) => setState(() => _pressedIndex = null),
                        onTapCancel: () => setState(() => _pressedIndex = null),
                        onTap: () {
                          final T key = widget.segments[i].$1;
                          if (key != widget.value) {
                            widget.onChanged(key);
                          }
                        },
                        child: AnimatedScale(
                          scale: _pressedIndex == i ? 0.94 : 1.0,
                          duration: const Duration(milliseconds: 110),
                          curve: Curves.easeOutCubic,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: _slideDuration,
                              curve: _slideCurve,
                              style: GoogleFonts.inter(
                                // Slightly tighter type when 4 segments (theme row).
                                fontSize: count >= 4 ? 11.5 : 13,
                                fontWeight: i == selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                letterSpacing: count >= 4 ? -0.25 : -0.2,
                                color: i == selected
                                    ? selectedFg
                                    : unselectedFg,
                                height: 1.1,
                              ),
                              child: Text(
                                widget.segments[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeTimeRow extends StatelessWidget {
  const _ThemeTimeRow({
    required this.title,
    required this.minutes,
    required this.onTap,
  });

  final String title;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color titleColor = isDark ? const Color(0xFFF2F2F7) : ink;
    final Color muted = ink.withValues(alpha: isDark ? 0.62 : 0.55);

    return _AnimatedPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: titleColor,
                  ),
                ),
              ),
              Text(
                formatMinutesOfDay(minutes),
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: isDark ? 0.55 : 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.surface,
    required this.borderColor,
    required this.isDark,
    required this.children,
  });

  final String title;
  final Color surface;
  final Color borderColor;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.42 : 0.50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: muted,
            ),
          ),
        ),
        _SettingsCard(
          surface: surface,
          borderColor: borderColor,
          isDark: isDark,
          children: children,
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.surface,
    required this.borderColor,
    required this.isDark,
    this.padding,
    this.child,
    this.children,
  });

  final Color surface;
  final Color borderColor;
  final bool isDark;
  final EdgeInsetsGeometry? padding;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final Widget content = child ??
        (children != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: children!,
              )
            : const SizedBox.shrink());

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(22.0),
          ),
          child: padding != null
              ? Padding(padding: padding!, child: content)
              : content,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final Color dividerColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.06,
        );

    // Align under text after bare icon (14 pad + 24 icon + 12 gap).
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Divider(height: 1, thickness: 0.5, color: dividerColor),
    );
  }
}

class _SettingsRowIcon extends StatelessWidget {
  const _SettingsRowIcon({
    required this.icon,
    // Kept for call-site compatibility; all row icons use a neutral tint.
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Same default ink for every row in both modes (no accent colors).
    final Color iconTint =
        isDark ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C);

    // Bare glyph only — no squircle / plate behind the icon.
    return SizedBox(
      width: 24,
      height: 24,
      child: Icon(icon, size: 22, color: iconTint),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return SizedBox(
      height: subtitle == null ? 58 : 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            _SettingsRowIcon(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: CupertinoSwitch(
                value: value,
                // System green — avoids electric-blue chrome in dark mode.
                activeTrackColor: const Color(0xFF34C759),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedPressScale extends StatefulWidget {
  const _AnimatedPressScale({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<_AnimatedPressScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Cycles profile mesh shape: Rounded (squircle) ↔ Circle.
class _ProfileAvatarShapeRow extends StatelessWidget {
  const _ProfileAvatarShapeRow({
    required this.shape,
    required this.onTap,
  });

  final ProfileAvatarShape shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return _AnimatedPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              _SettingsRowIcon(
                icon: shape == ProfileAvatarShape.circle
                    ? Icons.circle_outlined
                    : Icons.rounded_corner_rounded,
                color: const Color(0xFFAF52DE),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profile icon shape',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                    Text(
                      'Top bar account control',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                shape.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconStyleRow extends StatelessWidget {
  const _NavIconStyleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final NavIconStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final String value =
        style == NavIconStyle.classic ? 'Classic' : 'Vertical';

    return _AnimatedPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              _SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsLinkRow extends StatelessWidget {
  const _SettingsLinkRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return _AnimatedPressScale(
      onTap: () {
        HapticService.tap();
        onTap();
      },
      child: SizedBox(
        height: subtitle == null ? 58 : 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              _SettingsRowIcon(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: subtitle == null
                    ? Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: ink,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big translucent wordmark at the foot of Settings.
class _DocketSettingsWatermark extends StatelessWidget {
  const _DocketSettingsWatermark({
    required this.isDark,
    required this.ink,
  });

  final bool isDark;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final Color wash = ink.withValues(alpha: isDark ? 0.075 : 0.055);
    final Color versionWash = ink.withValues(alpha: isDark ? 0.10 : 0.08);

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 48, 4, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Docket',
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -3.2,
                    height: 1.0,
                    color: wash,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'v$kAppVersion',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: versionWash,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutDocketScreen extends StatelessWidget {
  const AboutDocketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final Color surface =
        isDark ? const Color(0xFF16161A) : theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final Color bg =
        isDark ? const Color(0xFF0A0A0D) : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Docket',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $kAppVersion',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 20),
                  _SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'A local-first wallet for passports, IDs, and passes.\n\n'
                      'Built with Flutter and Riverpod.\n\n'
                      'ID card icon by haritselarif on the Noun Project (CC BY 3.0).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '© 2026 Docket',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);
    final Color surface =
        isDark ? const Color(0xFF16161A) : theme.colorScheme.surface;
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final Color bg =
        isDark ? const Color(0xFF0A0A0D) : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  Text(
                    'Developer',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kDeveloperDisplayName,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 20),
                  _SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Hi — I\'m $kDeveloperDisplayName, the developer behind Docket.\n\n'
                      'Docket is a personal project focused on a polished, '
                      'local-first digital wallet experience for documents and '
                      'passes. Feedback and ideas are always welcome.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    surface: surface,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: <Widget>[
                      _SettingsLinkRow(
                        icon: Icons.language_rounded,
                        iconColor: const Color(0xFF2F6FED),
                        title: 'Website',
                        subtitle: 'navadeepnaidu.com',
                        onTap: () => _openDeveloperLink(
                          context,
                          kDeveloperWebsiteUrl,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsLinkRow(
                        icon: Icons.article_outlined,
                        iconColor: const Color(0xFFE07A2F),
                        title: 'Blog',
                        subtitle: 'blog.navadeepnaidu.com',
                        onTap: () =>
                            _openDeveloperLink(context, kDeveloperBlogUrl),
                      ),
                      const _SettingsDivider(),
                      _SettingsLinkRow(
                        icon: Icons.code_rounded,
                        iconColor: const Color(0xFF6E7681),
                        title: 'GitHub',
                        subtitle: 'github.com/navadeepnaidu7',
                        onTap: () =>
                            _openDeveloperLink(context, kDeveloperGithubUrl),
                      ),
                      const _SettingsDivider(),
                      _SettingsLinkRow(
                        icon: Icons.alternate_email_rounded,
                        iconColor: const Color(0xFF1DA1F2),
                        title: 'X',
                        subtitle: '@navadeep_naidu7',
                        onTap: () =>
                            _openDeveloperLink(context, kDeveloperXUrl),
                      ),
                      const _SettingsDivider(),
                      _SettingsLinkRow(
                        icon: Icons.mail_outline_rounded,
                        iconColor: const Color(0xFF8E8E93),
                        title: 'Mail to developer',
                        subtitle: kDeveloperEmail,
                        onTap: () => _mailToDeveloper(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}