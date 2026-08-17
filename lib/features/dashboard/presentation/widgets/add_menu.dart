import 'package:flutter/material.dart';

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

/// Opens the Documents add menu — the IDs tab's `+`.
///
/// Callbacks fire *after* the sheet closes, and run against the caller's
/// context, so the entry screen pushes onto the dashboard's navigator rather
/// than a dead sheet route.
Future<void> showAddDocumentsMenu({
  required BuildContext context,
  required void Function(bool isEPassport) onSelectPassportKind,
  required void Function(IdDocumentType type) onSelectIdType,
}) {
  return showMorphSheet(
    context: context,
    root: MorphStep(
      id: 'documents',
      title: 'Documents',
      subtitle: 'Add your important documents securely',
      builder: (BuildContext context, MorphSheetController controller) {
        return SquircleTileGrid(
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
        );
      },
    ),
  );
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
              height: _kCoverHeight,
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
              height: _kCoverHeight,
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
