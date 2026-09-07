import 'package:flutter/services.dart';

import '../../../../core/validation/document_validators.dart';
import '../../../../shared/prompt_flow/prompt_step.dart';
import '../../domain/id_document.dart';

/// Field ids. Also the keys the flow's value map is written under.
abstract final class IdField {
  IdField._();

  static const String method = 'method';
  static const String name = 'holderName';
  static const String number = 'documentNumber';
  static const String dateOfBirth = 'dateOfBirth';
  static const String fatherName = 'fatherName';
  static const String gender = 'gender';
  static const String address = 'address';
  static const String review = 'review';
}

abstract final class IdFlag {
  IdFlag._();

  static const String isPan = 'isPan';
}

bool _isPan(PromptFlowState s) => s.flag(IdFlag.isPan);

bool _isAadhaar(PromptFlowState s) => !s.flag(IdFlag.isPan);

bool _isIsoDate(String value) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

/// One question per screen for PAN and Aadhaar.
///
/// The form this replaces put every field on one details page. Optional
/// fields stay skippable so a number-only save still works; review refuses
/// to save when both name and number are empty.
List<PromptStep> buildIdFlow(IdDocumentType type) {
  final bool pan = type == IdDocumentType.pan;
  final String numberLabel = pan ? 'PAN' : 'Aadhaar';

  return <PromptStep>[
    PromptStep(
      id: IdField.method,
      kind: PromptStepKind.choice,
      question: (_) => 'How would you like to add it?',
      helper: (_) => pan
          ? 'Scan the PAN card to auto-fill, or type the details yourself.'
          : 'Scan the Aadhaar card or QR to auto-fill, or enter details.',
      label: 'Method',
    ),

    PromptStep(
      id: IdField.name,
      kind: PromptStepKind.text,
      question: (_) => 'Enter the name on the card',
      helper: (_) => 'Exactly as printed',
      placeholder: 'Full name',
      label: 'Name',
      capitalization: TextCapitalization.words,
      keyboardType: TextInputType.name,
      skippable: true,
      validate: (String v, PromptFlowState s) {
        if (v.trim().isNotEmpty) return null;
        if (s.value(IdField.number).trim().isNotEmpty) return null;
        return 'Enter the name, or skip and add the number instead.';
      },
    ),

    PromptStep(
      id: IdField.number,
      kind: PromptStepKind.text,
      question: (_) => 'Enter $numberLabel number',
      helper: (_) => pan ? 'ABCDE1234F' : '12 digits',
      placeholder: pan ? 'ABCDE1234F' : '000000000000',
      label: numberLabel,
      style: PromptInputStyle.mono,
      capitalization: TextCapitalization.characters,
      maxLength: pan ? 10 : 12,
      keyboardType: pan ? TextInputType.text : TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          pan ? RegExp('[A-Za-z0-9]') : RegExp('[0-9]'),
        ),
      ],
      skippable: true,
      validate: (String v, PromptFlowState s) {
        if (v.trim().isEmpty) return null;
        return pan
            ? DocumentValidators.validatePanNumber(v)
            : DocumentValidators.validateAadhaarNumber(v);
      },
    ),

    PromptStep(
      id: IdField.dateOfBirth,
      kind: PromptStepKind.date,
      question: (_) => 'Enter date of birth',
      helper: (_) => 'DDMMYYYY',
      label: 'Date of birth',
      style: PromptInputStyle.mono,
      skippable: true,
      validate: (String v, PromptFlowState s) {
        if (v.trim().isEmpty) return null;
        if (!_isIsoDate(v)) return 'Enter all 8 digits: DDMMYYYY';
        return DocumentValidators.validateDateOfBirth(
          v,
          requireAdult: _isPan(s),
        );
      },
    ),

    PromptStep(
      id: IdField.fatherName,
      kind: PromptStepKind.text,
      question: (_) => "Enter father's name",
      placeholder: "Father's name",
      label: "Father's name",
      capitalization: TextCapitalization.words,
      keyboardType: TextInputType.name,
      skippable: true,
      visibleWhen: _isPan,
    ),

    PromptStep(
      id: IdField.gender,
      kind: PromptStepKind.choice,
      question: (_) => 'Sex as printed on the card',
      label: 'Gender',
      skippable: true,
      visibleWhen: _isAadhaar,
      choices: const <PromptChoice>[
        PromptChoice(value: 'Male', label: 'Male'),
        PromptChoice(value: 'Female', label: 'Female'),
        PromptChoice(value: 'Other', label: 'Other'),
      ],
    ),

    PromptStep(
      id: IdField.address,
      kind: PromptStepKind.text,
      question: (_) => 'Enter address',
      placeholder: 'As printed on the card',
      label: 'Address',
      capitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.streetAddress,
      maxLines: 3,
      skippable: true,
      visibleWhen: _isAadhaar,
    ),

    PromptStep(
      id: IdField.review,
      kind: PromptStepKind.review,
      question: (_) => 'Ready to save',
      helper: (_) => 'Tap any line to change it.',
      label: 'Review',
    ),
  ];
}
