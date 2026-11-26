import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/dev/dev_flags.dart';
import '../../../../core/dev/dev_flags_provider.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cards/application/card_list_provider.dart';
import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../auth/application/google_auth_gateway.dart';
import '../widgets/membership_mesh.dart';
import 'settings_rows.dart';

/// Apple Card–like hero dimensions (scrolls with the settings list).
const double kSettingsHeroHeight = 226.0;
const double kSettingsHeroRadius = 22.0;

Future<void> _handleGoogleSignInTap(BuildContext context, WidgetRef ref) async {
  HapticService.confirm();
  try {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  } on GoogleAuthFailure catch (e) {
    if (!context.mounted) return;
    await _showAuthMessage(
      context,
      title: 'Could not sign in',
      message: e.message,
    );
  } catch (_) {
    if (!context.mounted) return;
    await _showAuthMessage(
      context,
      title: 'Could not sign in',
      message: 'Try again in a moment.',
    );
  }
}

Future<void> _showAuthMessage(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
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

  /// Requests Roboto Mono so `main()`'s `pendingFonts()` wait covers it.
  ///
  /// The membership number is the only Roboto Mono in the app, and this card
  /// only appears once Settings or the card detail is opened — so without this
  /// the family was fetched on that first open, hitching the screen and then
  /// reflowing the number out of a fallback face. The return value is
  /// deliberately discarded: asking is what starts the load.
  static void warmUp() {
    GoogleFonts.robotoMono(fontWeight: FontWeight.w700);
  }

  @override
  ConsumerState<WalletMembershipCard> createState() =>
      _WalletMembershipCardState();
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
    final bool routeVisible =
        route == null ||
        (route.isCurrent && (route.secondaryAnimation?.value ?? 0) == 0);
    final bool shouldRun =
        widget.enableMotion &&
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
    final PassportProfile? primaryPassport = widget.passports.isNotEmpty
        ? widget.passports.first
        : null;
    final IdDocument? primaryId = widget.idDocs.isNotEmpty
        ? widget.idDocs.first
        : null;

    final String name = _resolveName(session, primaryPassport, primaryId);
    final List<Color> washes = walletWashColors(
      passports: widget.passports,
      idDocs: widget.idDocs,
      cards: ref.watch(cardListProvider),
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
            color: Colors.black.withValues(alpha: widget.isDark ? 0.12 : 0.055),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.06 : 0.025),
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
                    signedIn && session.joinedLabel.isNotEmpty
                        ? session.joinedLabel
                        : 'Docket',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.ui(
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
                            style: AppFonts.ui(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.12,
                              color: ink,
                            ),
                          ),
                        ),
                        if (session.membershipNumber.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 16),
                          Text(
                            session.membershipNumber,
                            style: GoogleFonts.robotoMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: inkMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
                              busy: ref.watch(
                                authControllerProvider.select(
                                  (AuthControllerState s) => s.busy,
                                ),
                              ),
                              onTap: () => _handleGoogleSignInTap(context, ref),
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
  const _GoogleSignInOnCardButton({required this.onTap, this.busy = false});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SettingsPressScale(
      onTap: busy ? () {} : onTap,
      child: SizedBox(
        height: 40,
        child: busy
            ? const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            : SvgPicture.asset(
                AppAssets.googleSignInButton,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
      ),
    );
  }
}
