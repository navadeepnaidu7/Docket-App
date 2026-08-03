import 'package:flutter/services.dart';

import '../../../../core/validation/document_validators.dart';
import '../../../../shared/prompt_flow/prompt_step.dart';

/// Field ids. Also the keys the flow's value map is written under, so they
/// match the draft's field names.
abstract final class PassportField {
  PassportField._();

  static const String method = 'method';
  static const String name = 'name';
  static const String passportNumber = 'passportNumber';
  static const String dateOfBirth = 'dateOfBirth';
  static const String expiryDate = 'expiryDate';
  static const String nationality = 'nationality';
  static const String gender = 'gender';
  static const String nfcRead = 'nfcRead';
  static const String review = 'review';
}

/// Flow flags.
abstract final class PassportFlag {
  PassportFlag._();

  /// The user chose "E-Passport" before entering, so the chip route exists.
  static const String isEPassport = 'isEPassport';

  /// A chip read has completed, so the flow can offer to save.
  static const String chipRead = 'chipRead';

  /// The chip was attempted and given up on. The fields it would have
  /// supplied have to be asked for after all.
  static const String chipSkipped = 'chipSkipped';
}

/// Fields the chip would supply. Asked only when it will not.
bool _askedWhenNoChip(PromptFlowState s) =>
    !s.flag(PassportFlag.isEPassport) || s.flag(PassportFlag.chipSkipped);

/// The passport flow, one question per screen.
///
/// The three BAC fields are declared **once**, and are the passport's core data
/// on every route. The screen this replaces rendered them twice, on the same
/// controllers, under two headings, both labelled "step 2 of 3".
///
/// On an e-passport the chip is not one route among several — it is the point
/// of the document. The user picks only *how to supply the three values BAC
/// needs* (scan the photo page, or type them), and the read follows either way.
/// Name, nationality and sex are never asked: DG1 carries them, so asking would
/// be collecting data we are about to read off the chip.
///
/// If the read is abandoned, [PassportFlag.chipSkipped] brings those steps
/// back, because nothing else is going to supply them.
List<PromptStep> buildPassportFlow() {
  return <PromptStep>[
    // ── Route ────────────────────────────────────────────────────────────────
    PromptStep(
      id: PassportField.method,
      kind: PromptStepKind.choice,
      question: (_) => 'How would you like to add it?',
      helper: (_) => 'Scanning the photo page fills in most of this for you.',
      label: 'Method',
    ),

    // ── Identity ─────────────────────────────────────────────────────────────
    PromptStep(
      id: PassportField.name,
      kind: PromptStepKind.text,
      question: (_) => 'What name is on the passport?',
      helper: (_) => 'Exactly as printed, including any middle names.',
      confirmQuestion: (_) => 'Is this you?',
      placeholder: 'Full name',
      label: 'Name',
      capitalization: TextCapitalization.words,
      keyboardType: TextInputType.name,
      visibleWhen: _askedWhenNoChip,
      validate: (String v, _) =>
          v.trim().isEmpty ? 'A name is needed to save this passport.' : null,
    ),

    PromptStep(
      id: PassportField.passportNumber,
      kind: PromptStepKind.text,
      question: (_) => "What's the passport number?",
      helper: (_) => 'Top-right of the photo page. Letters and digits only.',
      confirmQuestion: (_) => 'Is this the passport number?',
      placeholder: 'Z3456789',
      label: 'Number',
      style: PromptInputStyle.mono,
      capitalization: TextCapitalization.characters,
      maxLength: 9,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
      ],
      validate: (String v, _) =>
          DocumentValidators.validatePassportNumber(v, required: true),
    ),

    PromptStep(
      id: PassportField.dateOfBirth,
      kind: PromptStepKind.date,
      question: (_) => 'When were you born?',
      confirmQuestion: (_) => 'Is this your date of birth?',
      label: 'Date of birth',
      style: PromptInputStyle.mono,
      validate: (String v, _) =>
          DocumentValidators.validateDateOfBirth(v, required: true),
    ),

    PromptStep(
      id: PassportField.expiryDate,
      kind: PromptStepKind.date,
      question: (_) => 'When does it expire?',
      helper: (PromptFlowState s) =>
          s.flag(PassportFlag.isEPassport) && !s.flag(PassportFlag.chipSkipped)
          ? 'These three together are what unlock the chip.'
          : null,
      confirmQuestion: (_) => 'Is this the expiry date?',
      label: 'Expires',
      style: PromptInputStyle.mono,
      validate: (String v, PromptFlowState s) =>
          DocumentValidators.validateExpiryDate(
            v,
            dob: s.value(PassportField.dateOfBirth),
            required: true,
          ),
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    // Every e-passport route ends here, whether the three values above were
    // scanned or typed. It is not something the user opts into.
    PromptStep(
      id: PassportField.nfcRead,
      kind: PromptStepKind.action,
      question: (_) => 'Hold your phone against the passport',
      helper: (_) =>
          'Rest the top of your phone on the cover and keep it still.',
      visibleWhen: (PromptFlowState s) =>
          s.flag(PassportFlag.isEPassport) && !s.flag(PassportFlag.chipSkipped),
      label: 'Chip',
    ),

    // ── Optional detail ──────────────────────────────────────────────────────
    PromptStep(
      id: PassportField.nationality,
      kind: PromptStepKind.text,
      question: (_) => "What's your nationality?",
      confirmQuestion: (_) => 'Is this your nationality?',
      placeholder: 'IND',
      label: 'Nationality',
      style: PromptInputStyle.mono,
      capitalization: TextCapitalization.characters,
      maxLength: 3,
      skippable: true,
      visibleWhen: _askedWhenNoChip,
    ),

    PromptStep(
      id: PassportField.gender,
      kind: PromptStepKind.choice,
      question: (_) => 'Sex as printed on the passport',
      confirmQuestion: (_) => 'Is this right?',
      label: 'Sex',
      skippable: true,
      visibleWhen: _askedWhenNoChip,
      choices: const <PromptChoice>[
        PromptChoice(value: 'M', label: 'Male'),
        PromptChoice(value: 'F', label: 'Female'),
        PromptChoice(value: 'X', label: 'Unspecified'),
      ],
    ),

    // ── Review ───────────────────────────────────────────────────────────────
    PromptStep(
      id: PassportField.review,
      kind: PromptStepKind.review,
      question: (_) => 'Ready to save',
      helper: (_) => 'Tap any line to change it.',
      label: 'Review',
    ),
  ];
}

/// Normalises the chip's gender encoding to the flow's.
///
/// JMRTD reports `MALE` / `FEMALE` / `UNKNOWN` while the MRZ carries `M` / `F`,
/// and both used to be written into the same field — so a record's sex was
/// stored in one of two incompatible encodings depending on how it was added.
String normaliseGender(String raw) {
  final String v = raw.trim().toUpperCase();
  if (v.startsWith('M')) return 'M';
  if (v.startsWith('F')) return 'F';
  if (v.isEmpty) return '';
  return 'X';
}
