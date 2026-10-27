import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ids/application/id_list_provider.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/application/passport_list_provider.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/application/pass_list_provider.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../application/auth_session_provider.dart';
import 'settings_screen.dart';
import 'widgets/account_summary.dart';
import 'widgets/account_greeting.dart';
import 'widgets/membership_card_material.dart';
import 'widgets/membership_horizon.dart';

/// The membership card with a short account summary under it.
class UserCardDetailScreen extends ConsumerWidget {
  const UserCardDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = AppTheme.ink(theme.brightness);

    final List<PassportProfile> passports = ref.watch(passportListProvider);
    final List<IdDocument> idDocs = ref.watch(idListProvider);
    final List<WalletPassItem> passes =
        ref.watch(passListProvider).value ?? const <WalletPassItem>[];
    final displayName =
        <String?>[
              ref.watch(authSessionProvider).displayName,
              if (passports.isNotEmpty) passports.first.name,
              if (idDocs.isNotEmpty) idDocs.first.holderName,
            ]
            .whereType<String>()
            .map((name) => name.trim())
            .firstWhere((name) => name.isNotEmpty, orElse: () => '');

    return Scaffold(
      backgroundColor: AppTheme.background(theme.brightness),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: (MediaQuery.sizeOf(context).height * 0.26).clamp(
              180.0,
              260.0,
            ),
            child: const MembershipHorizon(),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                        onPressed: () {
                          HapticService.select();
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Your Docket',
                        style: AppFonts.ui(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RepaintBoundary(
                    child: SizedBox(
                      height: kSettingsHeroHeight,
                      child: MembershipCardMaterial(
                        radius: kSettingsHeroRadius,
                        child: WalletMembershipCard(
                          passports: passports,
                          idDocs: idDocs,
                          isDark: isDark,
                          enableMotion: false,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 36, 24, 44),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AccountGreeting(displayName: displayName),
                              const SizedBox(height: 18),
                              AccountSummary(
                                passes: passes,
                                ids: idDocs,
                                passports: passports,
                                showCaption: false,
                              ),
                              const SizedBox(height: 28),
                              UpNextSummary(passes: passes),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'A little less to carry.',
                        textAlign: TextAlign.center,
                        style: AppFonts.ui(
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.25,
                          color: ink.withValues(alpha: isDark ? 0.96 : 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Made with ❤️ by Navadeep',
                        textAlign: TextAlign.center,
                        style: AppFonts.ui(
                          fontSize: 12,
                          height: 1.5,
                          color: ink.withValues(alpha: isDark ? 0.64 : 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
