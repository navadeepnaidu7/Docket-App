import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/application/wallet_order_provider.dart';
import '../../features/ids/application/id_list_provider.dart';
import '../../features/ids/domain/id_document.dart';
import '../../features/passport/application/passport_list_provider.dart';
import '../../features/passport/domain/passport_profile.dart';

/// Fictional documents for Settings → Developer.
///
/// Ids are stable (`dummy-…`) so a second tap is a no-op and Remove can find
/// every seeded card without touching the holder's real records.
abstract final class DummyWalletSeed {
  static const String idPrefix = 'dummy-';

  static bool isDummyId(String id) => id.startsWith(idPrefix);

  static List<PassportProfile> get passports => <PassportProfile>[
        PassportProfile(
          id: '${idPrefix}pp-regular-full',
          name: 'Karan Desai',
          passportNumber: 'Z9000001',
          nationality: 'INDIAN',
          dateOfBirth: '1991-03-12',
          expiryDate: '2031-03-11',
          imagePath: '',
          mrzRaw: '',
          placeOfBirth: 'AHMEDABAD',
          issueDate: '2021-03-12',
          issuingAuthority: 'AHMEDABAD',
          gender: 'MALE',
          isEPassport: false,
        ),
        PassportProfile(
          id: '${idPrefix}pp-e-full',
          name: 'Ananya Iyer',
          passportNumber: 'Z9000002',
          nationality: 'INDIAN',
          dateOfBirth: '1994-07-08',
          expiryDate: '2034-07-07',
          imagePath: '',
          mrzRaw: '',
          placeOfBirth: 'CHENNAI',
          issueDate: '2024-07-08',
          issuingAuthority: 'CHENNAI',
          gender: 'FEMALE',
          isEPassport: true,
        ),
        PassportProfile(
          id: '${idPrefix}pp-sparse',
          name: 'Rohit Nair',
          passportNumber: 'Z9000003',
          nationality: '',
          dateOfBirth: '',
          expiryDate: '',
          imagePath: '',
          mrzRaw: '',
          isEPassport: false,
        ),
        PassportProfile(
          id: '${idPrefix}pp-long-name',
          name: 'Venkataraman Ramachandra Subramanian',
          passportNumber: 'Z9000004',
          nationality: 'INDIAN',
          dateOfBirth: '1986-11-02',
          expiryDate: '2028-11-01',
          imagePath: '',
          mrzRaw: '',
          placeOfBirth: 'THIRUVANANTHAPURAM',
          issueDate: '2018-11-02',
          issuingAuthority: 'THIRUVANANTHAPURAM',
          gender: 'MALE',
          isEPassport: false,
        ),
        PassportProfile(
          id: '${idPrefix}pp-e-sparse',
          name: 'Meera Kapoor',
          passportNumber: 'Z9000005',
          nationality: 'INDIAN',
          dateOfBirth: '1998-01-19',
          expiryDate: '2033-01-18',
          imagePath: '',
          mrzRaw: '',
          isEPassport: true,
        ),
      ];

  static List<IdDocument> get ids => <IdDocument>[
        IdDocument(
          id: '${idPrefix}aadhaar-full',
          type: IdDocumentType.aadhaar,
          holderName: 'Karan Desai',
          documentNumber: '999988887771',
          dateOfBirth: '1991-03-12',
          gender: 'MALE',
          address: '12 Lake View, Navrangpura, Ahmedabad, Gujarat 380009',
        ),
        IdDocument(
          id: '${idPrefix}aadhaar-female',
          type: IdDocumentType.aadhaar,
          holderName: 'Ananya Iyer',
          documentNumber: '999988887772',
          dateOfBirth: '1994-07-08',
          gender: 'FEMALE',
          address: '44 Boat Club Road, Chennai, Tamil Nadu 600028',
        ),
        IdDocument(
          id: '${idPrefix}aadhaar-sparse',
          type: IdDocumentType.aadhaar,
          holderName: 'Rohit Nair',
          documentNumber: '999988887773',
        ),
        IdDocument(
          id: '${idPrefix}pan-full',
          type: IdDocumentType.pan,
          holderName: 'Karan Desai',
          documentNumber: 'AAAAA9999A',
          dateOfBirth: '1991-03-12',
          fatherName: 'Suresh Desai',
        ),
        IdDocument(
          id: '${idPrefix}pan-sparse',
          type: IdDocumentType.pan,
          holderName: 'Meera Kapoor',
          documentNumber: 'BBBBB8888B',
        ),
      ];

  /// Inserts any missing dummy cards. Returns how many were added.
  static int load(WidgetRef ref) {
    int added = 0;
    final PassportListController passports =
        ref.read(passportListProvider.notifier);
    final IdListController ids = ref.read(idListProvider.notifier);
    final WalletOrderController order = ref.read(walletOrderProvider.notifier);

    final Set<String> havePassports =
        ref.read(passportListProvider).map((p) => p.id).toSet();
    for (final PassportProfile profile in DummyWalletSeed.passports) {
      if (havePassports.contains(profile.id)) continue;
      passports.addPassport(profile);
      order.updateOrderOnItemAdded(profile.id);
      added++;
    }

    final Set<String> haveIds =
        ref.read(idListProvider).map((d) => d.id).toSet();
    for (final IdDocument doc in DummyWalletSeed.ids) {
      if (haveIds.contains(doc.id)) continue;
      ids.addDocument(doc);
      order.updateOrderOnItemAdded(doc.id);
      added++;
    }
    return added;
  }

  /// Drops every `dummy-` card. Returns how many were removed.
  static int remove(WidgetRef ref) {
    int removed = 0;
    final PassportListController passports =
        ref.read(passportListProvider.notifier);
    final IdListController ids = ref.read(idListProvider.notifier);
    final WalletOrderController order = ref.read(walletOrderProvider.notifier);

    for (final PassportProfile profile in ref.read(passportListProvider)) {
      if (!isDummyId(profile.id)) continue;
      passports.removePassport(profile.id);
      order.updateOrderOnItemRemoved(profile.id);
      removed++;
    }
    for (final IdDocument doc in ref.read(idListProvider)) {
      if (!isDummyId(doc.id)) continue;
      ids.removeDocument(doc.id);
      order.updateOrderOnItemRemoved(doc.id);
      removed++;
    }
    return removed;
  }
}
