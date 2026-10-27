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
import 'settings_screen.dart';
import 'widgets/account_summary.dart';
import 'widgets/membership_ribbon.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.background(theme.brightness),
      body: SafeArea(
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
                  child: WalletMembershipCard(
                    passports: passports,
                    idDocs: idDocs,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: AccountSummary(
                        passes: passes,
                        ids: idDocs,
                        passports: passports,
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 220),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: MembershipRibbon(),
                      ),
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
