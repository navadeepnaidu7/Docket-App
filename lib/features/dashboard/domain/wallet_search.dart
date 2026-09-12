import '../../ids/domain/id_document.dart';
import '../../passport/domain/passport_profile.dart';
import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/pass_display.dart';
import '../../tickets/domain/pass_share_summary.dart';
import '../../tickets/domain/pass_status.dart';

enum WalletSearchScope { all, documents, passes, archive }

/// Ephemeral display/search metadata. Never persists or logs queries or payloads.
class WalletSearchEntry {
  const WalletSearchEntry({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.searchText,
    required this.scope,
  });

  final Object item;
  final String title;
  final String subtitle;
  final String searchText;
  final WalletSearchScope scope;

  factory WalletSearchEntry.document(Object item) {
    final (String, String, String) fields = switch (item) {
      PassportProfile p => ('Passport', p.name, p.passportNumber),
      IdDocument d => (
        d.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card',
        d.holderName,
        d.documentNumber,
      ),
      _ => throw ArgumentError('Unsupported wallet document'),
    };
    return WalletSearchEntry(
      item: item,
      title: fields.$1,
      subtitle: [
        fields.$2,
        fields.$3,
      ].where((s) => s.trim().isNotEmpty).join(' · '),
      searchText: '${fields.$1} ${fields.$2} ${fields.$3}',
      scope: WalletSearchScope.documents,
    );
  }

  factory WalletSearchEntry.pass(WalletPassItem item) => WalletSearchEntry(
    item: item,
    title: passTitle(item),
    subtitle: [
      passPlaceLabel(item),
      passWhenLabel(item),
    ].where((s) => s.trim().isNotEmpty).join('\n'),
    searchText: '${passShareKindLabel(item)} ${buildPassShareText(item)}',
    scope: item.status == TicketStatus.expired
        ? WalletSearchScope.archive
        : WalletSearchScope.passes,
  );
}

List<WalletSearchEntry> searchWallet(
  List<WalletSearchEntry> entries,
  String query,
  WalletSearchScope scope,
) {
  final terms = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  return entries
      .where((entry) {
        if (scope != WalletSearchScope.all && entry.scope != scope) {
          return false;
        }
        final text = entry.searchText.toLowerCase();
        final compact = text.replaceAll(RegExp(r'[\s-]+'), '');
        return terms.every(
          (term) =>
              text.contains(term) || compact.contains(term.replaceAll('-', '')),
        );
      })
      .toList(growable: false);
}
