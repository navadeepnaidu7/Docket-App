import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_palette.dart';
import '../../../ids/domain/id_document.dart';
import '../../../ids/domain/id_document_catalog.dart';
import '../../../passport/domain/passport_profile.dart';

/// Display metadata for one wallet document, resolved in a single place.
///
/// The document *type* is the title. An earlier pass titled rows
/// "Navadeep's Passport" and then set a chip beside it reading "Passport" —
/// the same word twice — while IDs got the vague "Navadeep's ID" with the only
/// real content ("PAN") pushed into the chip. Everything in a personal wallet
/// belongs to the same person, so the possessive was noise on every row.
class WalletRowMeta {
  const WalletRowMeta({
    required this.title,
    required this.value,
    required this.palette,
  });

  /// What the document is: "Passport", "PAN Card", "Aadhaar Card".
  final String title;

  /// The document number, or a placeholder when it is not filled in.
  final String value;

  /// The card's own colours, shared with the wallet backdrop.
  final WalletPalette palette;

  factory WalletRowMeta.of(Object item) {
    if (item is PassportProfile) {
      return WalletRowMeta(
        title: 'Passport',
        value: item.passportNumber.trim().isEmpty
            ? 'No number'
            : item.passportNumber.trim(),
        palette: WalletPalette.forItem(item),
      );
    }

    final IdDocument doc = item as IdDocument;
    return WalletRowMeta(
      title: IdDocumentCatalog.titleFor(doc.type),
      value: doc.documentNumber.trim().isEmpty
          ? 'No number'
          : doc.documentNumber.trim(),
      palette: WalletPalette.forItem(item),
    );
  }

  bool get hasValue => value != 'No number';
}

/// One document as a single-line row: mini card, type, number, trailing slot.
///
/// Layout follows `manage_account_screen.dart`'s `_Field` — label left, value
/// right, one line — so the app's two grouped lists read the same way.
///
/// Shared by Manage (trailing = drag handle) and Trash (trailing = restore +
/// delete). Both are reached from the same view picker, so they have to agree
/// on what a document looks like.
class WalletRowTile extends StatelessWidget {
  const WalletRowTile({
    super.key,
    required this.item,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final Object item;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Aligns the divider with the title rather than the mini card.
  static const double _dividerIndent = 60;

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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: <Widget>[
                  WalletMiniCard(palette: meta.palette),
                  const SizedBox(width: 12),
                  Text(
                    meta.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      meta.value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        letterSpacing: -0.2,
                        color: meta.hasValue
                            ? AppTokens.secondaryLabel(scheme)
                            : AppTokens.tertiaryLabel(scheme),
                      ),
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

/// A miniature of the card itself, in that document's own palette.
///
/// Deliberately not a glyph on a tinted plate: the list is an index of cards,
/// so each row is headed by a small version of the card it points at. The
/// colours come from [WalletPalette], the same source the wallet backdrop
/// blends, so the list and the carousel agree.
class WalletMiniCard extends StatelessWidget {
  const WalletMiniCard({super.key, required this.palette});

  final WalletPalette palette;

  static const double _width = 34;
  static const double _height = 22;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.primary, palette.secondary],
        ),
        border: Border.all(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          width: 0.5,
        ),
      ),
    );
  }
}

/// Plain icon action for the Trash row's trailing slot.
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

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
