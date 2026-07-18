import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/id_document.dart';

final idDraftProvider =
    StateNotifierProvider<IdDraftController, IdDocument>((ref) {
  return IdDraftController();
});

class IdDraftController extends StateNotifier<IdDocument> {
  IdDraftController() : super(IdDocument.empty(IdDocumentType.pan));

  void reset(IdDocumentType type) => state = IdDocument.empty(type);
  void replaceWith(IdDocument doc) => state = doc;

  void updateHolderName(String v) => state = state.copyWith(holderName: v);
  void updateDocumentNumber(String v) => state = state.copyWith(documentNumber: v);
  void updateDateOfBirth(String v) => state = state.copyWith(dateOfBirth: v);
  void updateFatherName(String v) => state = state.copyWith(fatherName: v);
  void updateAddress(String v) => state = state.copyWith(address: v);
  void updateGender(String v) => state = state.copyWith(gender: v);
  void updateImagePath(String v) => state = state.copyWith(imagePath: v);
  void updateQrImageBase64(String v) => state = state.copyWith(qrImageBase64: v);
}
