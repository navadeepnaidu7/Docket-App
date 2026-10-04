import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/dashboard/presentation/settings_screen.dart';
import 'package:docket/features/dashboard/presentation/wallet_passport_card.dart';
import 'package:docket/features/tickets/presentation/pass_typography.dart';
import 'package:docket/features/tickets/presentation/train/train_pass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every app font loads from bundled assets with fetching disabled',
    () async {
      GoogleFonts.config.allowRuntimeFetching = false;
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      WalletPassportCard.warmUp();
      WalletMembershipCard.warmUp();
      PassType.warmUp();
      TrainPassType.warmUp();
      // Include lower weights used in detail rows and the heavier weight used
      // by Aadhaar (Roboto Mono resolves w800 to its available w700 variant).
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ]) {
        GoogleFonts.robotoMono(fontWeight: weight);
        GoogleFonts.geist(fontWeight: weight);
      }
      GoogleFonts.robotoMono(fontWeight: FontWeight.w800);
      GoogleFonts.inter(fontWeight: FontWeight.w900);
      await GoogleFonts.pendingFonts();
    },
  );
}
