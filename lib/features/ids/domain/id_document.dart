import 'dart:convert';
import 'dart:math';

enum IdDocumentType { pan, aadhaar }

String _generateId() {
  final rand = Random();
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '$ts${rand.nextInt(99999).toString().padLeft(5, '0')}';
}

class IdDocument {
  IdDocument({
    String? id,
    required this.type,
    required this.holderName,
    required this.documentNumber,
    this.dateOfBirth = '',
    this.fatherName = '',
    this.address = '',
    this.gender = '',
    this.imagePath = '',
    this.issueDate = '',
    this.qrImageBase64 = '',
  }) : id = id ?? _generateId();

  IdDocument.empty(IdDocumentType docType)
      : id = _generateId(),
        type = docType,
        holderName = '',
        documentNumber = '',
        dateOfBirth = '',
        fatherName = '',
        address = '',
        gender = '',
        imagePath = '',
        issueDate = '',
        qrImageBase64 = '';

  final String id;
  final IdDocumentType type;
  final String holderName;
  final String documentNumber;
  final String dateOfBirth;
  final String fatherName;   // PAN-specific
  final String address;      // Aadhaar-specific
  final String gender;       // Aadhaar-specific
  final String imagePath;
  final String issueDate;
  final String qrImageBase64;

  IdDocument copyWith({
    String? id,
    IdDocumentType? type,
    String? holderName,
    String? documentNumber,
    String? dateOfBirth,
    String? fatherName,
    String? address,
    String? gender,
    String? imagePath,
    String? issueDate,
    String? qrImageBase64,
  }) {
    return IdDocument(
      id: id ?? this.id,
      type: type ?? this.type,
      holderName: holderName ?? this.holderName,
      documentNumber: documentNumber ?? this.documentNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      fatherName: fatherName ?? this.fatherName,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      imagePath: imagePath ?? this.imagePath,
      issueDate: issueDate ?? this.issueDate,
      qrImageBase64: qrImageBase64 ?? this.qrImageBase64,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'holderName': holderName,
        'documentNumber': documentNumber,
        'dateOfBirth': dateOfBirth,
        'fatherName': fatherName,
        'address': address,
        'gender': gender,
        'imagePath': imagePath,
        'issueDate': issueDate,
        'qrImageBase64': qrImageBase64,
      };

  factory IdDocument.fromMap(Map<String, dynamic> map) => IdDocument(
        id: map['id'] as String?,
        type: IdDocumentType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => IdDocumentType.pan,
        ),
        holderName: map['holderName'] ?? '',
        documentNumber: map['documentNumber'] ?? '',
        dateOfBirth: map['dateOfBirth'] ?? '',
        fatherName: map['fatherName'] ?? '',
        address: map['address'] ?? '',
        gender: map['gender'] ?? '',
        imagePath: map['imagePath'] ?? '',
        issueDate: map['issueDate'] ?? '',
        qrImageBase64: map['qrImageBase64'] ?? '',
      );

  String toJson() => json.encode(toMap());
  factory IdDocument.fromJson(String source) =>
      IdDocument.fromMap(json.decode(source) as Map<String, dynamic>);
}
