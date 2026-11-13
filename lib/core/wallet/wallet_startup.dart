import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/cards/application/card_list_provider.dart';
import '../../features/cards/application/payment_card_stack_provider.dart';
import '../../features/cards/domain/card_issuer.dart';
import '../../features/cards/domain/payment_card.dart';
import '../../features/cards/domain/card_surface.dart';
import '../../features/cards/presentation/network_mark.dart';
import '../../features/dashboard/application/wallet_order_provider.dart';
import '../../features/dashboard/application/wallet_filter_provider.dart';
import '../../features/dashboard/presentation/wallet_passport_card.dart';
import '../../features/ids/application/id_list_provider.dart';
import '../../features/ids/domain/id_document.dart';
import '../../features/passport/application/passport_list_provider.dart';
import '../../features/passport/domain/passport_profile.dart';
import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'wallet_items.dart';
import 'wallet_filter.dart';
import '../../shared/widgets/safe_base64_image.dart';

/// Runs before runApp, in the same container the UI will use. No second read,
/// document screenshots, extra plaintext storage, or network work is involved.
Future<void> prepareWalletStartup(
  ProviderContainer container, {
  Future<void> Function(List<Object>) warm = warmInitialWalletAssets,
}) async {
  container.read(resolvedThemeModeProvider);
  container.read(paymentCardStackProvider);
  container.read(walletFilterEnabledProvider);
  container.read(walletFilterCategoryProvider);
  await Future.wait([
    container.read(passportListProvider.notifier).loaded,
    container.read(idListProvider.notifier).loaded,
    container.read(cardListProvider.notifier).loaded,
    container.read(walletOrderProvider.notifier).loadOrder(),
  ]);
  var items = sortWalletItems(
    passports: container.read(passportListProvider),
    idDocs: container.read(idListProvider),
    cards: container.read(cardListProvider),
    order: container.read(walletOrderProvider),
  );
  if (container.read(walletFilterEnabledProvider)) {
    final category = container.read(walletFilterCategoryProvider);
    if (walletFilterOptionsFor(items).contains(category)) {
      items = filterWalletItems(items: items, category: category);
    }
  }
  final initial = items.take(2).toList();
  if (items.firstOrNull is PaymentCard &&
      container.read(paymentCardStackProvider)) {
    initial.addAll(
      items
          .whereType<PaymentCard>()
          .where((card) => !initial.contains(card))
          .toList(),
    );
  }
  // A damaged/missing bundled asset must not strand an otherwise usable wallet.
  try {
    await warm(initial);
  } catch (_) {}
}

Future<void> warmInitialWalletAssets(List<Object> items) async {
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ]) {
    AppFonts.ui(fontWeight: weight);
  }
  for (final weight in [FontWeight.w400, FontWeight.w500, FontWeight.w700]) {
    GoogleFonts.robotoMono(fontWeight: weight);
  }
  if (items.any((item) => item is PassportProfile)) WalletPassportCard.warmUp();
  if (items.any((item) => item is IdDocument)) {
    GoogleFonts.robotoMono(fontWeight: FontWeight.w800);
  }
  final pngs = <String>{};
  final svgs = <String>{};
  final jobs = <Future<void>>[];
  for (final item in items) {
    if (item is PassportProfile) pngs.add(AppAssets.passportEmblemWatermark);
    if (item is IdDocument) {
      jobs.add(
        SafeBase64Image.prepare(item.imagePath).then((image) async {
          if (image != null) await warmWalletImage(image);
        }),
      );
      pngs.addAll([
        AppAssets.passportEmblemHeader,
        AppAssets.passportEmblemWatermark,
        AppAssets.passportEmblemHologram,
      ]);
      if (item.type == IdDocumentType.aadhaar) svgs.add(AppAssets.aadhaarLogo);
    }
    if (item is PaymentCard) {
      final issuer = item.bankName.trim().isNotEmpty
          ? issuerFromName(item.bankName)
          : cardIssuers
                .where((issuer) => issuer.id == item.issuerId)
                .firstOrNull;
      if (issuer != null) svgs.add(issuer.logoAsset);
      jobs.add(
        NetworkMark.warmUp(
          item.network,
          cardSurfaceStyle(item.issuerId, item.surfaceIndex),
        ),
      );
    }
  }
  jobs.add(GoogleFonts.pendingFonts().then<void>((_) {}));
  jobs.addAll(pngs.map((path) => warmWalletImage(AssetImage(path))));
  jobs.addAll(
    svgs.map((path) async {
      final loader = SvgAssetLoader(path);
      await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => loader.loadBytes(null),
      );
    }),
  );
  await Future.wait(
    jobs.map((job) async {
      try {
        await job;
      } catch (_) {}
    }),
  );
}

/// Populate Flutter's regular image cache without needing an on-screen widget.
Future<void> warmWalletImage(ImageProvider provider) {
  return provider
      .obtainCacheStatus(configuration: ImageConfiguration.empty)
      .then((status) async {
        if (status?.keepAlive ?? false) return;
        final stream = provider.resolve(ImageConfiguration.empty);
        final completer = Completer<void>();
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (image, _) {
            image.dispose();
            if (!completer.isCompleted) completer.complete();
          },
          onError: (Object _, StackTrace? _) {
            if (!completer.isCompleted) completer.complete();
          },
        );
        stream.addListener(listener);
        await completer.future;
        stream.removeListener(listener);
      });
}
