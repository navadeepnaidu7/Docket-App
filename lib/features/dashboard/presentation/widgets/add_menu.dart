import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../../../shared/widgets/morph_sheet.dart';
import '../../../../shared/widgets/squircle_tile.dart';
import '../../../ids/domain/id_document.dart';
import '../../../ids/domain/id_document_catalog.dart';
import '../../../passport/presentation/widgets/passport_cover_art.dart';

/// Height of the passport artwork inside a Documents tile.
const double _kCoverHeight = 84;

/// Documents tiles are a little taller than wide to seat the cover art plus a
/// two-line caption.
const double _kDocumentTileAspect = 0.92;

/// Displayed height of the wordmark close-up on the passport-kind step.
///
/// The kind step compares two covers that differ only in the chip symbol, so
/// it frames the lower cover instead of the whole thing — at full-cover scale
/// the chip is a few pixels.
const double _kCropHeight = 62;

/// Opens the Documents add menu — the IDs tab's `+`.
///
/// Callbacks fire *after* the sheet closes, and run against the caller's
/// context, so the entry screen pushes onto the dashboard's navigator rather
/// than a dead sheet route.
Future<void> showAddDocumentsMenu({
  required BuildContext context,
  required void Function(bool isEPassport) onSelectPassportKind,
  required void Function(IdDocumentType type) onSelectIdType,
  MorphStep Function()? passesStep,
  VoidCallback? onSwitchToPasses,
}) {
  return showMorphSheet(
    context: context,
    root: MorphStep(
      id: 'documents',
      title: 'Documents',
      builder: (BuildContext context, MorphSheetController controller) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SquircleTileGrid(
              columns: 2,
              tiles: <Widget>[
                SquircleTile(
                  label: 'Passport',
                  sublabel: 'E-passport via NFC',
                  aspectRatio: _kDocumentTileAspect,
                  art: const PassportCoverArt(
                    variant: PassportCoverVariant.regular,
                    height: _kCoverHeight,
                  ),
                  onTap: () =>
                      controller.push(_passportKindStep(onSelectPassportKind)),
                ),
                SquircleTile(
                  label: 'ID Cards',
                  sublabel: 'Aadhaar, PAN and more',
                  aspectRatio: _kDocumentTileAspect,
                  icon: Icons.badge_outlined,
                  onTap: () => controller.push(_idTypeStep(onSelectIdType)),
                ),
              ],
            ),
            // One-way on purpose. Someone on the IDs tab may not realise the
            // passes wallet exists; someone already in Passes has no such gap,
            // so there is no matching link back.
            if (passesStep != null)
              _SwitchLink(
                label: 'Add a pass instead',
                onTap: () {
                  onSwitchToPasses?.call();
                  controller.replaceRoot(passesStep());
                },
              ),
          ],
        );
      },
    ),
  );
}

/// A quiet text link under a grid, for moving sideways to another section.
///
/// Deliberately not a filled button: it is an escape hatch for someone in the
/// wrong place, not a call to action competing with the tiles above it.
class _SwitchLink extends StatelessWidget {
  const _SwitchLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color ink = AppTokens.secondaryLabel(scheme);

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: BounceTap(
            onTap: onTap,
            scaleFactor: 0.97,
            child: Padding(
              // Generous vertical padding: the text is small, the tap target
              // should not be.
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.chevron_right_rounded, color: ink, size: 17),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the passport-kind choice directly, skipping the Documents step.
///
/// The easter-egg drawer's "add passport" shortcut is already specific about
/// what it is adding, so it roots the sheet one level in.
Future<void> showPassportKindMenu({
  required BuildContext context,
  required void Function(bool isEPassport) onSelect,
}) {
  return showMorphSheet(context: context, root: _passportKindStep(onSelect));
}

/// E-passport versus regular — told apart by the artwork, since the chip symbol
/// on the cover is exactly how the two differ in the hand.
MorphStep _passportKindStep(void Function(bool isEPassport) onSelect) {
  return MorphStep(
    id: 'passport-kind',
    title: 'Passport',
    subtitle: 'Which kind are you adding?',
    builder: (BuildContext context, MorphSheetController controller) {
      return SquircleTileGrid(
        columns: 2,
        tiles: <Widget>[
          SquircleTile(
            label: 'E-Passport',
            sublabel: 'Has an NFC chip',
            aspectRatio: _kDocumentTileAspect,
            art: const PassportCoverArt(
              variant: PassportCoverVariant.ePassport,
              crop: PassportCoverCrop.wordmark,
              height: _kCropHeight,
            ),
            onTap: () {
              controller.close();
              onSelect(true);
            },
          ),
          SquircleTile(
            label: 'Regular Passport',
            sublabel: 'No chip',
            aspectRatio: _kDocumentTileAspect,
            art: const PassportCoverArt(
              variant: PassportCoverVariant.regular,
              crop: PassportCoverCrop.wordmark,
              height: _kCropHeight,
            ),
            onTap: () {
              controller.close();
              onSelect(false);
            },
          ),
        ],
      );
    },
  );
}

MorphStep _idTypeStep(void Function(IdDocumentType type) onSelect) {
  return MorphStep(
    id: 'id-type',
    title: 'ID Cards',
    subtitle: 'Choose a document type',
    builder: (BuildContext context, MorphSheetController controller) {
      return SquircleTileGrid(
        columns: 3,
        tiles: <Widget>[
          SquircleTile(
            label: IdDocumentCatalog.titleFor(IdDocumentType.aadhaar),
            icon: Icons.fingerprint_rounded,
            onTap: () {
              controller.close();
              onSelect(IdDocumentType.aadhaar);
            },
          ),
          SquircleTile(
            label: IdDocumentCatalog.titleFor(IdDocumentType.pan),
            icon: Icons.account_balance_outlined,
            onTap: () {
              controller.close();
              onSelect(IdDocumentType.pan);
            },
          ),
          const SquircleTile(
            label: 'Driving Licence',
            icon: Icons.directions_car_outlined,
            soon: true,
          ),
          const SquircleTile(
            label: 'Voter ID',
            icon: Icons.how_to_vote_outlined,
            soon: true,
          ),
        ],
      );
    },
  );
}
