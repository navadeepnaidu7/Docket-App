import 'package:flutter/material.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/id_document.dart';
import 'wallet_aadhaar_card.dart';
import 'wallet_pan_card.dart';

typedef IdCardFaceBuilder = Widget Function(IdDocument document);

/// Maps each [IdDocumentType] to its wallet card faces.
/// Register new document types here when adding support.
class IdCardRegistry {
  const IdCardRegistry._();

  static final Map<IdDocumentType, IdCardFaceBuilder> fronts = {
    IdDocumentType.pan: (document) => PanCardFront(document: document),
    IdDocumentType.aadhaar: (document) => AadhaarCardFront(document: document),
  };

  static final Map<IdDocumentType, IdCardFaceBuilder> backs = {
    IdDocumentType.pan: (document) => PanCardBack(document: document),
    IdDocumentType.aadhaar: (document) => AadhaarCardBack(document: document),
  };

  /// Logical canvas a type's faces are authored against. Override here if a
  /// future document type needs a different one.
  static const Map<IdDocumentType, Size> _canvases = <IdDocumentType, Size>{};

  static Size canvasFor(IdDocumentType type) =>
      _canvases[type] ?? WalletCardMetrics.idCanvas;

  static Widget buildFront(IdDocument document) {
    final builder = fronts[document.type];
    if (builder == null) {
      throw UnsupportedError('No wallet front registered for ${document.type}');
    }
    return WalletCardCanvas(
      designSize: canvasFor(document.type),
      child: builder(document),
    );
  }

  static Widget buildBack(IdDocument document) {
    final builder = backs[document.type];
    if (builder == null) {
      throw UnsupportedError('No wallet back registered for ${document.type}');
    }
    return WalletCardCanvas(
      designSize: canvasFor(document.type),
      child: builder(document),
    );
  }
}