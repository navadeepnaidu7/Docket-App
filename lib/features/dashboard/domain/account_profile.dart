import 'dart:convert';

/// Optional personal details for the signed-in account.
///
/// Name, email, and photo come from [AuthSession]. This model holds the
/// extras the user can fill in on Manage account (DOB, phone, etc.).
class AccountProfile {
  const AccountProfile({
    this.dateOfBirth = '',
    this.phone = '',
    this.nationality = '',
    this.city = '',
    this.notes = '',
  });

  static const AccountProfile empty = AccountProfile();

  /// ISO `YYYY-MM-DD`, or empty when unset.
  final String dateOfBirth;
  final String phone;

  /// ISO 3166-1 alpha-3 when known (e.g. IND), free text allowed.
  final String nationality;
  final String city;

  /// Short free-form note the user chooses to keep on their account.
  final String notes;

  bool get isEmpty =>
      dateOfBirth.trim().isEmpty &&
      phone.trim().isEmpty &&
      nationality.trim().isEmpty &&
      city.trim().isEmpty &&
      notes.trim().isEmpty;

  AccountProfile copyWith({
    String? dateOfBirth,
    String? phone,
    String? nationality,
    String? city,
    String? notes,
    bool clearDateOfBirth = false,
    bool clearPhone = false,
    bool clearNationality = false,
    bool clearCity = false,
    bool clearNotes = false,
  }) {
    return AccountProfile(
      dateOfBirth:
          clearDateOfBirth ? '' : (dateOfBirth ?? this.dateOfBirth),
      phone: clearPhone ? '' : (phone ?? this.phone),
      nationality:
          clearNationality ? '' : (nationality ?? this.nationality),
      city: clearCity ? '' : (city ?? this.city),
      notes: clearNotes ? '' : (notes ?? this.notes),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'dateOfBirth': dateOfBirth,
        'phone': phone,
        'nationality': nationality,
        'city': city,
        'notes': notes,
      };

  factory AccountProfile.fromMap(Map<String, dynamic> map) {
    return AccountProfile(
      dateOfBirth: (map['dateOfBirth'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      nationality: (map['nationality'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AccountProfile.fromJson(String source) {
    try {
      final Object? decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return AccountProfile.fromMap(decoded);
      }
      if (decoded is Map) {
        return AccountProfile.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return AccountProfile.empty;
  }
}
