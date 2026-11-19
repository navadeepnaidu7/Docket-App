import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/line_icon.dart';
import '../../../cards/domain/card_issuer.dart';
import '../../../cards/domain/payment_card.dart';
import '../../../ids/domain/id_document.dart';
import '../../../ids/domain/id_document_catalog.dart';
import '../../../passport/domain/passport_profile.dart';

/// Display metadata for one wallet document, resolved in a single place.
///
/// The document *type* is the title. The holder's name leads the detail line,
/// because a wallet routinely carries a family's documents: five rows titled
/// "Passport" are only distinguishable by whose they are.
class WalletRowMeta {
  const WalletRowMeta({
    required this.title,
    required this.holder,
    required this.number,
  });

  /// What the document is: "Passport", "PAN Card", "HDFC Bank".
  final String title;

  /// Whose it is, or empty when the record never captured a name.
  final String holder;

  /// The document number as stored. Rows show it only through [maskedNumber].
  final String number;

  factory WalletRowMeta.of(Object item) {
    if (item is PassportProfile) {
      return WalletRowMeta(
        title: 'Passport',
        holder: item.name.trim(),
        number: item.passportNumber.trim(),
      );
    }

    if (item is PaymentCard) {
      return WalletRowMeta(
        title: item.displayBank,
        holder: item.holderName.trim(),
        number: item.lastFour,
      );
    }

    final IdDocument doc = item as IdDocument;
    return WalletRowMeta(
      title: IdDocumentCatalog.titleFor(doc.type),
      holder: doc.holderName.trim(),
      number: doc.documentNumber.trim(),
    );
  }

  bool get hasNumber => number.isNotEmpty;

  /// Last four characters, the same treatment for every kind of document.
  ///
  /// The list is a glanceable index, often looked at with someone beside you.
  /// It used to print full PAN and Aadhaar numbers next to masked bank cards,
  /// which was both inconsistent and the wrong way round for sensitivity.
  String get maskedNumber {
    if (number.isEmpty) return '';
    final String tail = number.length <= 4
        ? number
        : number.substring(number.length - 4);
    return '•••• $tail';
  }

  /// "Meera Kapoor  ·  •••• 888B", or whichever half exists.
  String get detail {
    final String masked = maskedNumber;
    if (holder.isEmpty) return masked.isEmpty ? 'No number' : masked;
    return masked.isEmpty ? holder : '$holder  ·  $masked';
  }
}

/// One document as a row: issuer mark, type, then whose it is and which one.
///
/// Shared by Manage (no trailing; the row itself is the drag handle) and Trash
/// (trailing = restore + delete). Both are reached from the same view picker,
/// so they have to agree on what a document looks like.
class WalletRowTile extends StatelessWidget {
  const WalletRowTile({
    super.key,
    required this.item,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.removed = false,
  });

  final Object item;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Trash rows: the mark fades, so the list reads as "out of the wallet"
  /// before a word is read. The text stays full strength to scan.
  final bool removed;

  static const double _hPad = 16;
  static const double _gap = 14;

  /// Aligns the divider with the title rather than the mark.
  static const double _dividerIndent = _hPad + WalletDocMark.size + _gap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final WalletRowMeta meta = WalletRowMeta.of(item);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_hPad, 12, 12, 12),
              child: Row(
                children: <Widget>[
                  Opacity(
                    opacity: removed ? 0.42 : 1,
                    child: WalletDocMark(item: item),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          meta.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            height: 1.25,
                            color: AppTheme.ink(theme.brightness),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _DetailLine(meta: meta, scheme: scheme),
                      ],
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: _dividerIndent,
            color: AppTokens.separator(scheme),
          ),
      ],
    );
  }
}

/// Holder, then number. The name gives way first: a long name must never
/// push the masked number, the one thing that tells two passports of the
/// same person apart, off the end of the row.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.meta, required this.scheme});

  final WalletRowMeta meta;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppFonts.ui(
      fontSize: 13.5,
      letterSpacing: -0.1,
      height: 1.3,
      color: AppTokens.secondaryLabel(scheme),
    );
    if (meta.holder.isEmpty || meta.maskedNumber.isEmpty) {
      return Text(
        meta.detail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            meta.holder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Text('  ·  ${meta.maskedNumber}', maxLines: 1, style: style),
      ],
    );
  }
}

/// The document's issuer, in its real artwork, on one neutral tile.
///
/// Replaces a gradient swatch that was meant to echo each card's palette but
/// read as arbitrary colour: the PAN swatch was yellow-green on a pale-blue
/// card. Every mark here is an asset the app already ships for the card faces
/// (bank logos, the Aadhaar sun, the national emblem, the passport cover), so
/// the row says who issued the document instead of decorating it. Anything
/// without a mark gets a monogram, never an invented colour.
class WalletDocMark extends StatelessWidget {
  const WalletDocMark({super.key, required this.item});

  final Object item;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        // Issuer logos are drawn for a white field, in both themes: the same
        // rule [BankMark] follows on the card faces.
        color: isDark ? const Color(0xFFF2F2F0) : Colors.white,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: AppTokens.hairline(scheme), width: 0.5),
        ),
      ),
      alignment: Alignment.center,
      child: _mark(),
    );
  }

  Widget _mark() {
    final Object item = this.item;
    if (item is PassportProfile) {
      if (_isIndian(item.nationality)) {
        // The cover is the one passport image people recognise at a glance.
        return SvgPicture.asset(
          AppAssets.passportCoverRegular,
          height: 30,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        );
      }
      return _Monogram(item.nationality);
    }

    if (item is PaymentCard) {
      final CardIssuer? issuer = item.bankName.trim().isNotEmpty
          ? issuerFromName(item.bankName)
          : cardIssuers
                .where((CardIssuer i) => i.id == item.issuerId)
                .firstOrNull;
      if (issuer == null) return _Monogram(item.displayBank);
      return Padding(
        padding: const EdgeInsets.all(7),
        child: SvgPicture.asset(
          issuer.logoAsset,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      );
    }

    final IdDocument doc = item as IdDocument;
    return switch (doc.type) {
      IdDocumentType.aadhaar => Padding(
        padding: const EdgeInsets.all(5),
        child: SvgPicture.asset(
          AppAssets.aadhaarLogo,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
      IdDocumentType.pan => Image.asset(
        AppAssets.passportEmblemStandard,
        height: 26,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    };
  }

  /// A passport with no nationality recorded is treated as Indian: every
  /// passport flow in the app is built around the Indian booklet.
  static bool _isIndian(String raw) {
    final String v = raw.trim().toUpperCase();
    return v.isEmpty || v == 'IND' || v == 'INDIAN' || v == 'INDIA';
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram(this.source);

  final String source;

  @override
  Widget build(BuildContext context) {
    final String letters = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .take(2)
        .map((String w) => w[0].toUpperCase())
        .join();
    return Text(
      letters,
      style: AppFonts.ui(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: const Color(0xFF1C1C1E),
      ),
    );
  }
}

/// Plain line-glyph action for the Trash row's trailing slot.
///
/// No tinted circle behind it — the colour alone carries the meaning, and a
/// filled plate on every row turned the list into a field of coloured dots.
class WalletRowAction extends StatelessWidget {
  const WalletRowAction({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  /// An `AppAssets.icon*` Lucide glyph.
  final String icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: LineIcon(icon, size: 20, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
