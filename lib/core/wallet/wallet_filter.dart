import '../../features/cards/domain/payment_card.dart';
import '../../features/ids/domain/id_document.dart';
import '../../features/ids/domain/id_document_catalog.dart';
import '../../features/passport/domain/passport_profile.dart';

/// Wallet document categories for the experimental filter bar.
enum WalletFilterCategory {
  all,
  passport,
  pan,
  aadhaar,
  card,
}

extension WalletFilterCategoryMeta on WalletFilterCategory {
  String get label => switch (this) {
        WalletFilterCategory.all => 'All',
        WalletFilterCategory.passport => 'Passport',
        WalletFilterCategory.pan =>
          IdDocumentCatalog.shortLabelFor(IdDocumentType.pan),
        WalletFilterCategory.aadhaar =>
          IdDocumentCatalog.shortLabelFor(IdDocumentType.aadhaar),
        WalletFilterCategory.card => 'Cards',
      };
}

WalletFilterCategory walletCategoryFor(Object item) {
  return switch (item) {
    PassportProfile() => WalletFilterCategory.passport,
    IdDocument doc => switch (doc.type) {
        IdDocumentType.pan => WalletFilterCategory.pan,
        IdDocumentType.aadhaar => WalletFilterCategory.aadhaar,
      },
    PaymentCard() => WalletFilterCategory.card,
    _ => WalletFilterCategory.all,
  };
}

/// Categories present in the wallet (excluding [WalletFilterCategory.all]).
Set<WalletFilterCategory> walletCategoriesIn(List<Object> items) {
  final Set<WalletFilterCategory> categories = {};
  for (final Object item in items) {
    categories.add(walletCategoryFor(item));
  }
  return categories;
}

List<WalletFilterCategory> walletFilterOptionsFor(List<Object> items) {
  final Set<WalletFilterCategory> present = walletCategoriesIn(items);
  if (present.length <= 1) {
    return const [WalletFilterCategory.all];
  }

  const List<WalletFilterCategory> order = [
    WalletFilterCategory.all,
    WalletFilterCategory.passport,
    WalletFilterCategory.pan,
    WalletFilterCategory.aadhaar,
    WalletFilterCategory.card,
  ];

  return order.where((c) {
    return c == WalletFilterCategory.all || present.contains(c);
  }).toList();
}

List<Object> filterWalletItems({
  required List<Object> items,
  required WalletFilterCategory category,
}) {
  if (category == WalletFilterCategory.all) return items;
  return items.where((item) => walletCategoryFor(item) == category).toList();
}

String walletFilterEmptyMessage(WalletFilterCategory category) {
  return switch (category) {
    WalletFilterCategory.all => 'No documents in your wallet yet.',
    WalletFilterCategory.passport => 'No passports in your wallet.',
    WalletFilterCategory.pan => 'No PAN cards in your wallet.',
    WalletFilterCategory.aadhaar => 'No Aadhaar cards in your wallet.',
    WalletFilterCategory.card => 'No cards in your wallet.',
  };
}