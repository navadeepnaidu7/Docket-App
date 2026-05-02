import 'dart:convert';

class PassportProfile {
  const PassportProfile({
    required this.name,
    required this.passportNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.expiryDate,
    required this.imagePath,
    required this.mrzRaw,
    this.placeOfBirth = '',
    this.issueDate = '',
    this.issuingAuthority = '',
    this.gender = '',
  });

  const PassportProfile.empty()
      : name = '',
        passportNumber = '',
        nationality = '',
        dateOfBirth = '',
        expiryDate = '',
        imagePath = '',
        mrzRaw = '',
        placeOfBirth = '',
        issueDate = '',
        issuingAuthority = '',
        gender = '';

  final String name;
  final String passportNumber;
  final String nationality;
  final String dateOfBirth;
  final String expiryDate;
  final String imagePath;
  final String mrzRaw;
  final String placeOfBirth;
  final String issueDate;
  final String issuingAuthority;
  final String gender;

  PassportProfile copyWith({
    String? name,
    String? passportNumber,
    String? nationality,
    String? dateOfBirth,
    String? expiryDate,
    String? imagePath,
    String? mrzRaw,
    String? placeOfBirth,
    String? issueDate,
    String? issuingAuthority,
    String? gender,
  }) {
    return PassportProfile(
      name: name ?? this.name,
      passportNumber: passportNumber ?? this.passportNumber,
      nationality: nationality ?? this.nationality,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      expiryDate: expiryDate ?? this.expiryDate,
      imagePath: imagePath ?? this.imagePath,
      mrzRaw: mrzRaw ?? this.mrzRaw,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      issueDate: issueDate ?? this.issueDate,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      gender: gender ?? this.gender,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'passportNumber': passportNumber,
      'nationality': nationality,
      'dateOfBirth': dateOfBirth,
      'expiryDate': expiryDate,
      'imagePath': imagePath,
      'mrzRaw': mrzRaw,
      'placeOfBirth': placeOfBirth,
      'issueDate': issueDate,
      'issuingAuthority': issuingAuthority,
      'gender': gender,
    };
  }

  factory PassportProfile.fromMap(Map<String, dynamic> map) {
    return PassportProfile(
      name: map['name'] ?? '',
      passportNumber: map['passportNumber'] ?? '',
      nationality: map['nationality'] ?? '',
      dateOfBirth: map['dateOfBirth'] ?? '',
      expiryDate: map['expiryDate'] ?? '',
      imagePath: map['imagePath'] ?? '',
      mrzRaw: map['mrzRaw'] ?? '',
      placeOfBirth: map['placeOfBirth'] ?? '',
      issueDate: map['issueDate'] ?? '',
      issuingAuthority: map['issuingAuthority'] ?? '',
      gender: map['gender'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory PassportProfile.fromJson(String source) => PassportProfile.fromMap(json.decode(source));
}