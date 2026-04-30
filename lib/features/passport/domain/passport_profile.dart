class PassportProfile {
  const PassportProfile({
    required this.name,
    required this.passportNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.expiryDate,
    required this.imagePath,
    required this.mrzRaw,
  });

  const PassportProfile.empty()
      : name = '',
        passportNumber = '',
        nationality = '',
        dateOfBirth = '',
        expiryDate = '',
        imagePath = '',
        mrzRaw = '';

  final String name;
  final String passportNumber;
  final String nationality;
  final String dateOfBirth;
  final String expiryDate;
  final String imagePath;
  final String mrzRaw;

  PassportProfile copyWith({
    String? name,
    String? passportNumber,
    String? nationality,
    String? dateOfBirth,
    String? expiryDate,
    String? imagePath,
    String? mrzRaw,
  }) {
    return PassportProfile(
      name: name ?? this.name,
      passportNumber: passportNumber ?? this.passportNumber,
      nationality: nationality ?? this.nationality,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      expiryDate: expiryDate ?? this.expiryDate,
      imagePath: imagePath ?? this.imagePath,
      mrzRaw: mrzRaw ?? this.mrzRaw,
    );
  }
}