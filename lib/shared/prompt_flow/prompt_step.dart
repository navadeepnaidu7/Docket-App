import 'package:flutter/services.dart';

/// What kind of answer a step collects.
enum PromptStepKind {
  /// Free text or a formatted document number.
  text,

  /// A date, picked inline rather than in a sheet.
  date,

  /// One of a fixed set of options.
  choice,

  /// Not a question — a thing that happens (open the camera, read the chip).
  action,

  /// Terminal summary of everything collected.
  review,
}

/// How a value got into the draft. Drives the provenance marker on review.
enum FieldSource {
  /// The user typed it.
  typed,

  /// Read off the document by OCR.
  scanned,

  /// Read from the passport chip. The most trustworthy source.
  chip,
}

/// Rendering treatment for a text input.
enum PromptInputStyle {
  /// Names, places — sentence-shaped values.
  prose,

  /// Document numbers and dates. Monospaced and tracked, so digits can be
  /// checked against the physical document one character at a time.
  mono,
}

/// One screen in a prompted flow: a single question and a single answer.
///
/// Steps are declarative so a flow can be assembled, reordered and tested
/// without a widget tree. Conditional steps are expressed with [visibleWhen]
/// rather than by branching navigation — that is what let the screen this
/// replaces ask for the same three fields twice under two different headings.
class PromptStep {
  const PromptStep({
    required this.id,
    required this.kind,
    required this.question,
    this.helper,
    this.placeholder,
    this.skippable = false,
    this.visibleWhen,
    this.validate,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters,
    this.style = PromptInputStyle.prose,
    this.maxLength,
    this.choices = const <PromptChoice>[],
    this.label,
    this.confirmQuestion,
  });

  /// Stable identifier, and the key this step's value is stored under.
  final String id;

  final PromptStepKind kind;

  /// The question, resolved against current state so it can interpolate.
  final String Function(PromptFlowState state) question;

  /// Optional supporting line. Says where to find the value or why it is
  /// needed — it should never restate the question.
  final String? Function(PromptFlowState state)? helper;

  final String? placeholder;

  /// Whether this step offers a skip action.
  final bool skippable;

  /// When present and false, the step does not exist for this run — not
  /// rendered, not counted in progress, not walked by back().
  final bool Function(PromptFlowState state)? visibleWhen;

  /// Returns an error message, or null when the value is acceptable.
  final String? Function(String value, PromptFlowState state)? validate;

  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final PromptInputStyle style;
  final int? maxLength;

  /// Options for [PromptStepKind.choice].
  final List<PromptChoice> choices;

  /// Short noun for this value, used on review and in confirm mode. Falls back
  /// to [id] when absent.
  final String? label;

  /// Question used when confirming a pre-filled value, e.g. "Is this your
  /// passport number?" instead of "What's your passport number?".
  final String Function(PromptFlowState state)? confirmQuestion;

  bool isVisible(PromptFlowState state) =>
      visibleWhen == null || visibleWhen!(state);

  /// Whether this step holds data. Actions and review do not.
  bool get collectsValue =>
      kind == PromptStepKind.text ||
      kind == PromptStepKind.date ||
      kind == PromptStepKind.choice;
}

/// One option in a [PromptStepKind.choice] step.
class PromptChoice {
  const PromptChoice({required this.value, required this.label, this.detail});

  final String value;
  final String label;
  final String? detail;
}

/// Which entry route the user picked at the start of a flow.
enum PromptPath { undecided, scan, chip, manual }

/// Immutable snapshot of a flow, passed to every step callback.
///
/// Steps read this rather than closing over a controller, so question text,
/// visibility and validation are pure functions of state and can be tested
/// directly, without a widget tree.
class PromptFlowState {
  const PromptFlowState({
    required this.values,
    required this.sources,
    required this.path,
    required this.confirmMode,
    required this.flags,
  });

  const PromptFlowState.empty()
      : values = const <String, String>{},
        sources = const <String, FieldSource>{},
        path = PromptPath.undecided,
        confirmMode = false,
        flags = const <String, bool>{};

  final Map<String, String> values;
  final Map<String, FieldSource> sources;
  final PromptPath path;

  /// True once a scan or chip read has pre-filled values, so steps holding a
  /// value present as "is this right?" rather than asking from scratch.
  final bool confirmMode;

  /// Flow-specific booleans, e.g. `isEPassport`.
  final Map<String, bool> flags;

  String value(String id) => values[id] ?? '';
  bool has(String id) => (values[id] ?? '').trim().isNotEmpty;
  bool flag(String name) => flags[name] ?? false;
  FieldSource sourceOf(String id) => sources[id] ?? FieldSource.typed;

  PromptFlowState copyWith({
    Map<String, String>? values,
    Map<String, FieldSource>? sources,
    PromptPath? path,
    bool? confirmMode,
    Map<String, bool>? flags,
  }) {
    return PromptFlowState(
      values: values ?? this.values,
      sources: sources ?? this.sources,
      path: path ?? this.path,
      confirmMode: confirmMode ?? this.confirmMode,
      flags: flags ?? this.flags,
    );
  }
}
