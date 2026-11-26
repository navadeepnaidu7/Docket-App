import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_config.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/haptics/haptics_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shining_action_label.dart';
import '../../cards/application/payment_card_stack_provider.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/application/movie_artwork_blend_provider.dart';
import '../../tickets/presentation/calendar/calendar_import_screen.dart';
import '../../auth/application/auth_session_provider.dart';
import '../application/card_shine_border_provider.dart';
import '../application/nav_labels_provider.dart';
import '../application/pass_deck_provider.dart';
import '../application/profile_avatar_shape_provider.dart';
import '../application/search_button_provider.dart';
import '../application/wallet_filter_provider.dart';
import 'manage_account_screen.dart';
import 'settings/about_screens.dart';
import 'settings/appearance_settings.dart';
import 'settings/developer_settings_section.dart';
import 'settings/membership_card.dart';
import 'settings/settings_rows.dart';
import 'settings/notification_settings.dart';
import 'settings/delete_account_sheet.dart';
import 'user_card_detail_screen.dart';

// Public Settings API that callers and tests import from this file.
export 'settings/about_screens.dart'
    show
        AboutDeveloperScreen,
        AboutDocketScreen,
        kAppVersion,
        kDeveloperBlogUrl,
        kDeveloperDisplayName,
        kDeveloperEmail,
        kDeveloperGithubUrl,
        kDeveloperWebsiteUrl,
        kDeveloperXUrl;
export 'settings/membership_card.dart'
    show WalletMembershipCard, kSettingsHeroHeight, kSettingsHeroRadius;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// While false, pause continuous effects so scroll isn't fighting paint work.
  ///
  /// A notifier rather than `setState`: only the membership card and the
  /// shimmer label care, and rebuilding the whole screen for them meant every
  /// scroll gesture rebuilt all fifteen list children — sections, the
  /// Developer block, and the two dozen GoogleFonts lookups in them — twice,
  /// at the two moments the list could least afford it.
  final ValueNotifier<bool> _effectsOn = ValueNotifier<bool>(true);
  Timer? _scrollIdleTimer;

  @override
  void dispose() {
    _scrollIdleTimer?.cancel();
    _effectsOn.dispose();
    super.dispose();
  }

  void _resumeEffectsAfter(Duration delay) {
    _scrollIdleTimer = Timer(delay, () {
      if (mounted) _effectsOn.value = true;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Any scroll activity → pause; resume shortly after motion settles.
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _scrollIdleTimer?.cancel();
      _effectsOn.value = false;
      _resumeEffectsAfter(const Duration(milliseconds: 140));
    } else if (notification is ScrollEndNotification) {
      _scrollIdleTimer?.cancel();
      _resumeEffectsAfter(const Duration(milliseconds: 80));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;
    final Color scaffoldBg = isDark
        ? const Color(0xFF0A0A0D)
        : const Color(0xFFF8F8FA);
    final Color surface = isDark
        ? const Color(0xFF16161A)
        : const Color(0xFFFFFFFF);
    final Color borderColor = ink.withValues(alpha: isDark ? 0.08 : 0.05);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);
    final AuthSession session = ref.watch(authSessionProvider);

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
                  scrollCacheExtent: const ScrollCacheExtent.pixels(480),
                  // Avoid keep-alive overhead for a short settings list.
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  children: [
                    RepaintBoundary(
                      child: SettingsPressScale(
                        onTap: () {
                          HapticService.select();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const UserCardDetailScreen(),
                            ),
                          );
                        },
                        child: SizedBox(
                          height: kSettingsHeroHeight,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _effectsOn,
                            builder: (BuildContext context, bool effectsOn, _) {
                              return WalletMembershipCard(
                                passports: passports,
                                idDocs: idDocs,
                                isDark: isDark,
                                enableMotion: effectsOn,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _effectsOn,
                          builder: (BuildContext context, bool effectsOn, _) {
                            return ShiningActionLabel(
                              label: 'Tap to open',
                              enabled: effectsOn,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SettingsSection(
                      title: 'Appearance',
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                      children: [
                        const ThemeAppearanceBlock(),
                        const SettingsDivider(),
                        SettingsToggleRow(
                          icon: Icons.vibration_rounded,
                          iconColor: const Color(0xFFE07A2F),
                          title: 'Haptics',
                          value: ref.watch(hapticsEnabledProvider),
                          onChanged: (_) {
                            final bool enabled = ref.read(
                              hapticsEnabledProvider,
                            );
                            if (enabled) HapticService.select();
                            ref.read(hapticsEnabledProvider.notifier).toggle();
                          },
                        ),
                        const SettingsDivider(),
                        ProfileAvatarShapeRow(
                          shape: ref.watch(profileAvatarShapeProvider),
                          onTap: () {
                            HapticService.select();
                            ref
                                .read(profileAvatarShapeProvider.notifier)
                                .toggle();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SettingsSection(
                      title: 'Navigation',
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                      children: [
                        SettingsToggleRow(
                          icon: CupertinoIcons.textformat_abc,
                          iconColor: const Color(0xFF2F6FED),
                          title: 'Labels',
                          value: ref.watch(showNavLabelsProvider),
                          onChanged: (_) {
                            HapticService.select();
                            ref.read(showNavLabelsProvider.notifier).toggle();
                          },
                        ),
                        const SettingsDivider(),
                        SettingsToggleRow(
                          icon: Icons.search_rounded,
                          iconColor: const Color(0xFF0FA968),
                          title: 'Search button',
                          subtitle: 'Search your wallet from the Home header',
                          value: ref.watch(searchButtonEnabledProvider),
                          onChanged: (_) {
                            HapticService.select();
                            ref
                                .read(searchButtonEnabledProvider.notifier)
                                .toggle();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SettingsSection(
                      title: 'Experimental',
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                      children: [
                        SettingsToggleRow(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF2F6FED),
                          title: 'Stack payment cards',
                          subtitle:
                              'Group bank cards into one Wallet-style stack',
                          value: ref.watch(paymentCardStackProvider),
                          onChanged: (enabled) {
                            HapticService.select();
                            ref
                                .read(paymentCardStackProvider.notifier)
                                .setEnabled(enabled);
                          },
                        ),
                        const SettingsDivider(),
                        SettingsToggleRow(
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
                        const SettingsDivider(),
                        SettingsToggleRow(
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
                        const SettingsDivider(),
                        SettingsToggleRow(
                          icon: Icons.style_rounded,
                          iconColor: const Color(0xFF0FA968),
                          title: 'Stacked pass deck',
                          subtitle:
                              'Passes overlap in a deck you swipe sideways, '
                              'instead of the vertical roll',
                          value: ref.watch(passDeckModeProvider),
                          onChanged: (_) {
                            HapticService.select();
                            ref.read(passDeckModeProvider.notifier).toggle();
                          },
                        ),
                        const SettingsDivider(),
                        SettingsToggleRow(
                          icon: Icons.movie_outlined,
                          iconColor: const Color(0xFF5E5CE6),
                          title: 'Movie artwork blend',
                          subtitle: 'Blend movie posters into your pass cards',
                          value: ref.watch(movieArtworkBlendProvider),
                          onChanged: (enabled) {
                            HapticService.select();
                            ref
                                .read(movieArtworkBlendProvider.notifier)
                                .setEnabled(enabled);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    NotificationSettingsSection(
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                    ),
                    if (session.isSignedIn) ...[
                      const SizedBox(height: 20),
                      SettingsSection(
                        title: 'Account',
                        surface: surface,
                        borderColor: borderColor,
                        isDark: isDark,
                        children: [
                          SettingsLinkRow(
                            icon: Icons.manage_accounts_rounded,
                            iconColor: const Color(0xFF2F6FED),
                            title: 'Manage account',
                            subtitle: session.email,
                            onTap: () {
                              HapticService.select();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ManageAccountScreen(),
                                ),
                              );
                            },
                          ),
                          const SettingsDivider(),
                          SettingsLinkRow(
                            icon: Icons.event_available_rounded,
                            iconColor: const Color(0xFF0FA968),
                            title: 'Google Calendar',
                            subtitle: 'Import bookings automatically',
                            onTap: () {
                              HapticService.select();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CalendarImportScreen(),
                                ),
                              );
                            },
                          ),
                          const SettingsDivider(),
                          SettingsLinkRow(
                            icon: Icons.logout_rounded,
                            iconColor: const Color(0xFFFF3B30),
                            title: 'Sign out',
                            onTap: () => _confirmSignOut(context, ref),
                          ),
                          const DeleteAccountAction(),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SettingsSection(
                      title: 'About',
                      surface: surface,
                      borderColor: borderColor,
                      isDark: isDark,
                      children: [
                        SettingsLinkRow(
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
                        const SettingsDivider(),
                        SettingsLinkRow(
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
                        const SettingsDivider(),
                        SettingsLinkRow(
                          icon: Icons.mail_outline_rounded,
                          iconColor: const Color(0xFF8E8E93),
                          title: 'Mail to developer',
                          subtitle: kDeveloperEmail,
                          onTap: () => mailToDeveloper(context),
                        ),
                        const SettingsDivider(),
                        SettingsLinkRow(
                          icon: Icons.cloud_outlined,
                          iconColor: const Color(0xFF8E8E93),
                          title: 'Weather credits',
                          subtitle: 'Open-Meteo \u00b7 CC BY 4.0',
                          onTap: () => showWeatherCredits(context),
                        ),
                      ],
                    ),
                    if (DevConfig.showDevMenu) ...[
                      const SizedBox(height: 20),
                      DeveloperSettingsSection(
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
  await ref.read(authControllerProvider.notifier).signOut();
}

/// Big translucent wordmark at the foot of Settings.
class _DocketSettingsWatermark extends StatelessWidget {
  const _DocketSettingsWatermark({required this.isDark, required this.ink});

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
                  style: AppFonts.ui(
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
              style: AppFonts.ui(
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
