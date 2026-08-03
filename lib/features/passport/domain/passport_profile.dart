import 'dart:convert';
import 'dart:math';

import '../../../core/storage/image_payload.dart';

/// Current on-disk shape of a persisted [PassportProfile].
///
/// v1 kept the data-page photo and the chip portrait in a single `imagePath`
/// field. v2 splits them into [PassportProfile.imagePath] (a filesystem path)
/// and [PassportProfile.photoBase64] (an encoded portrait). Records without a
/// version marker are treated as v1 and migrated on read.
const int kPassportSchemaVersion = 2;

String _generateId() {
  final rand = Random();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final suffix = rand.nextInt(99999).toString().padLeft(5, '0');
  return '$ts$suffix';
}

class PassportProfile {
  PassportProfile({
    String? id,
    required this.name,
    required this.passportNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.expiryDate,
    required this.imagePath,
    required this.mrzRaw,
    this.photoBase64 = '',
    this.placeOfBirth = '',
    this.issueDate = '',
    this.issuingAuthority = '',
    this.gender = '',
    this.isEPassport = false,
  }) : id = id ?? _generateId();

  PassportProfile.empty()
      : id = _generateId(),
        name = '',
        passportNumber = '',
        nationality = '',
        dateOfBirth = '',
        expiryDate = '',
        imagePath = '',
        mrzRaw = '',
        photoBase64 = '',
        placeOfBirth = '',
        issueDate = '',
        issuingAuthority = '',
        gender = '',
        isEPassport = false;

  final String id;
  final String name;
  final String passportNumber;
  final String nationality;
  final String dateOfBirth;
  final String expiryDate;
  /// Filesystem path of a captured data-page image. Never base64.
  final String imagePath;
  final String mrzRaw;

  /// Base64-encoded portrait read from the chip (DG2). Never a path.
  final String photoBase64;
  final String placeOfBirth;
  final String issueDate;
  final String issuingAuthority;
  final String gender;
  final bool isEPassport;

  PassportProfile copyWith({
    String? id,
    String? name,
    String? passportNumber,
    String? nationality,
    String? dateOfBirth,
    String? expiryDate,
    String? imagePath,
    String? mrzRaw,
    String? photoBase64,
    String? placeOfBirth,
    String? issueDate,
    String? issuingAuthority,
    String? gender,
    bool? isEPassport,
  }) {
    return PassportProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      passportNumber: passportNumber ?? this.passportNumber,
      nationality: nationality ?? this.nationality,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      expiryDate: expiryDate ?? this.expiryDate,
      imagePath: imagePath ?? this.imagePath,
      mrzRaw: mrzRaw ?? this.mrzRaw,
      photoBase64: photoBase64 ?? this.photoBase64,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      issueDate: issueDate ?? this.issueDate,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      gender: gender ?? this.gender,
      isEPassport: isEPassport ?? this.isEPassport,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'v': kPassportSchemaVersion,
      'id': id,
      'name': name,
      'passportNumber': passportNumber,
      'nationality': nationality,
      'dateOfBirth': dateOfBirth,
      'expiryDate': expiryDate,
      'imagePath': imagePath,
      'mrzRaw': mrzRaw,
      'photoBase64': photoBase64,
      'placeOfBirth': placeOfBirth,
      'issueDate': issueDate,
      'issuingAuthority': issuingAuthority,
      'gender': gender,
      'isEPassport': isEPassport,
    };
  }

  /// True when [map] predates the image split and needed migrating on read.
  ///
  /// Used by the list controller to decide whether a one-off rewrite is worth
  /// doing, so a normal launch does not pay for a pointless encrypted write.
  static bool mapNeedsMigration(Map<String, dynamic> map) =>
      (map['v'] as int? ?? 1) < kPassportSchemaVersion;

  factory PassportProfile.fromMap(Map<String, dynamic> map) {
    final int version = map['v'] as int? ?? 1;
    final String storedImage = map['imagePath'] ?? '';

    // v1 kept both a captured-image path and a base64 chip portrait in
    // `imagePath`. Route each to its own field; the original string always
    // survives in one of them, so the migration cannot lose data.
    final String imagePath;
    final String photoBase64;
    if (version >= 2) {
      imagePath = storedImage;
      photoBase64 = map['photoBase64'] ?? '';
    } else if (isBase64ImagePayload(storedImage)) {
      imagePath = '';
      photoBase64 = storedImage;
    } else {
      imagePath = storedImage;
      photoBase64 = '';
    }

    return PassportProfile(
      id: map['id'] as String?,
      name: map['name'] ?? '',
      passportNumber: map['passportNumber'] ?? '',
      nationality: map['nationality'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      expiryDate: map['expiryDate'] ?? '',
      imagePath: imagePath,
      mrzRaw: map['mrzRaw'] ?? '',
      photoBase64: photoBase64,
      placeOfBirth: map['placeOfBirth'] ?? '',
      issueDate: map['issueDate'] ?? '',
      issuingAuthority: map['issuingAuthority'] ?? '',
      gender: map['gender'] ?? '',
      isEPassport: map['isEPassport'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory PassportProfile.fromJson(String source) => PassportProfile.fromMap(json.decode(source));
}