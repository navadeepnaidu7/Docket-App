import 'package:flutter/foundation.dart';

import 'prompt_step.dart';

/// Direction of the last move, so the view can animate the right way.
enum PromptDirection { forward, backward }

/// Drives a prompted flow: which step is showing, what has been answered, and
/// what is wrong with it.
///
/// A plain [ChangeNotifier] with no Riverpod and no widget dependencies, so
/// the whole state machine — conditional steps, back-stack unwinding, skip,
/// validation, scan confirmation — is unit-testable without pumping a frame.
///
/// It deliberately does not own the document being built. The draft providers
/// keep that; this keeps only flow state. Conflating the two is how `mrzRaw`
/// and `isEPassport` ended up half-wired in the screen this replaces.
class PromptFlowController extends ChangeNotifier {
  PromptFlowController({
    required List<PromptStep> steps,
    Map<String, String> initialValues = const <String, String>{},
    Map<String, bool> initialFlags = const <String, bool>{},
    this.onCommit,
  })  : _steps = steps,
        _state = PromptFlowState(
          values: Map<String, String>.from(initialValues),
          sources: const <String, FieldSource>{},
          path: PromptPath.undecided,
          confirmMode: false,
          flags: Map<String, bool>.from(initialFlags),
        );

  final List<PromptStep> _steps;

  /// Called with the full value map every time a step is committed, so the
  /// caller can mirror into its draft. Never called with invalid values.
  final void Function(Map<String, String> values)? onCommit;

  PromptFlowState _state;
  PromptFlowState get state => _state;

  final Map<String, String> _errors = <String, String>{};
  final List<String> _history = <String>[];
  final Set<String> _skipped = <String>{};

  String? _cursor;
  PromptDirection _direction = PromptDirection.forward;

  /// Set when the user jumped in from review; the next commit returns there
  /// instead of continuing through the flow.
  String? _returnTo;

  /// Highest progress reached, so the bar never runs backwards on a forward
  /// move when the visible list grows mid-flow.
  double _progressHighWater = 0;

  // ── Reading ────────────────────────────────────────────────────────────────

  /// Steps that exist for the current state, in order.
  List<PromptStep> get visibleSteps =>
      _steps.where((PromptStep s) => s.isVisible(_state)).toList();

  PromptStep get current {
    final List<PromptStep> visible = visibleSteps;
    if (visible.isEmpty) {
      throw StateError('A prompt flow must have at least one visible step');
    }
    final int index = visible.indexWhere((PromptStep s) => s.id == _cursor);
    return index == -1 ? visible.first : visible[index];
  }

  int get currentIndex {
    final int index =
        visibleSteps.indexWhere((PromptStep s) => s.id == current.id);
    return index == -1 ? 0 : index;
  }

  int get stepCount => visibleSteps.length;

  PromptDirection get direction => _direction;

  bool get isFirstStep => currentIndex == 0;
  bool get isLastStep => currentIndex == stepCount - 1;

  String? errorFor(String stepId) => _errors[stepId];
  String? get currentError => _errors[current.id];

  bool wasSkipped(String stepId) => _skipped.contains(stepId);

  /// True when the current step already holds a value that came from a scan or
  /// the chip, so it should present as a confirmation rather than a question.
  bool get isConfirming =>
      _state.confirmMode &&
      current.collectsValue &&
      _state.has(current.id) &&
      _state.sourceOf(current.id) != FieldSource.typed;

  /// The question to show, accounting for confirm mode.
  String get currentQuestion {
    final PromptStep step = current;
    if (isConfirming && step.confirmQuestion != null) {
      return step.confirmQuestion!(_state);
    }
    return step.question(_state);
  }

  /// 0..1, monotonic on forward moves.
  double get progress {
    if (stepCount <= 1) return 1;
    final double raw = currentIndex / (stepCount - 1);
    if (_direction == PromptDirection.forward && raw > _progressHighWater) {
      _progressHighWater = raw;
    }
    return _direction == PromptDirection.backward
        ? raw
        : (raw > _progressHighWater ? raw : _progressHighWater);
  }

  // ── Writing ────────────────────────────────────────────────────────────────

  /// Records a value without advancing. Clears any error on that field, so a
  /// message disappears as soon as the user starts fixing what it referred to.
  void setValue(String stepId, String value, {FieldSource? source}) {
    final Map<String, String> values =
        Map<String, String>.from(_state.values)..[stepId] = value;
    final Map<String, FieldSource> sources =
        Map<String, FieldSource>.from(_state.sources);
    if (source != null) {
      sources[stepId] = source;
    } else {
      // Typing over a scanned value makes it typed.
      sources[stepId] = FieldSource.typed;
    }
    _state = _state.copyWith(values: values, sources: sources);
    _errors.remove(stepId);
    notifyListeners();
  }

  void setFlag(String name, {required bool value}) {
    _state = _state.copyWith(
      flags: Map<String, bool>.from(_state.flags)..[name] = value,
    );
    notifyListeners();
  }

  void setPath(PromptPath path) {
    _state = _state.copyWith(path: path);
    notifyListeners();
  }

  /// Applies values from a scan or chip read and switches to confirm mode.
  ///
  /// Empty values are ignored, so a partial scan leaves the steps it could not
  /// fill asking normally, in their original position, rather than producing a
  /// separate "some fields are missing" screen.
  void applyScan(
    Map<String, String> scanned, {
    required FieldSource source,
    bool trusted = true,
  }) {
    final Map<String, String> values = Map<String, String>.from(_state.values);
    final Map<String, FieldSource> sources =
        Map<String, FieldSource>.from(_state.sources);

    scanned.forEach((String key, String value) {
      if (value.trim().isEmpty) return;
      values[key] = value;
      sources[key] = source;
    });

    _state = _state.copyWith(
      values: values,
      sources: sources,
      confirmMode: true,
      flags: Map<String, bool>.from(_state.flags)..['trustedScan'] = trusted,
    );
    _errors.clear();
    notifyListeners();
  }

  /// Validates and advances. Returns false and surfaces an inline error when
  /// the current value is not acceptable.
  bool next() {
    final PromptStep step = current;

    if (step.collectsValue && step.validate != null) {
      final String? error = step.validate!(_state.value(step.id), _state);
      if (error != null) {
        _errors[step.id] = error;
        notifyListeners();
        return false;
      }
    }

    _errors.remove(step.id);
    _skipped.remove(step.id);
    onCommit?.call(Map<String, String>.unmodifiable(_state.values));

    // Jumped in from review: go straight back rather than re-walking.
    final String? returnTo = _returnTo;
    if (returnTo != null) {
      _returnTo = null;
      _moveTo(returnTo, PromptDirection.forward);
      return true;
    }

    _advanceFrom(step);
    return true;
  }

  /// Leaves the current step unanswered and moves on. Only meaningful when the
  /// step is [PromptStep.skippable].
  void skip() {
    final PromptStep step = current;
    if (!step.skippable) return;

    _skipped.add(step.id);
    _errors.remove(step.id);

    final String? returnTo = _returnTo;
    if (returnTo != null) {
      _returnTo = null;
      _moveTo(returnTo, PromptDirection.forward);
      return;
    }

    _advanceFrom(step);
  }

  /// Steps back through the path actually taken.
  ///
  /// Pops a history stack rather than decrementing an index, so unwinding a
  /// branch lands where the user came from. Returns false when there is
  /// nowhere left to go and the caller should pop the route.
  bool back() {
    if (_returnTo != null) {
      final String target = _returnTo!;
      _returnTo = null;
      _moveTo(target, PromptDirection.backward);
      return true;
    }

    if (_history.isEmpty) return false;

    final String previous = _history.removeLast();
    _errors.clear();
    _cursor = previous;
    _direction = PromptDirection.backward;
    notifyListeners();
    return true;
  }

  /// Edits one step and returns to [returnTo] when it is committed.
  void jumpTo(String stepId, {required String returnTo}) {
    _returnTo = returnTo;
    _errors.clear();
    _moveTo(stepId, PromptDirection.forward);
  }

  void _advanceFrom(PromptStep step) {
    final List<PromptStep> visible = visibleSteps;
    final int index = visible.indexWhere((PromptStep s) => s.id == step.id);
    if (index == -1 || index >= visible.length - 1) {
      notifyListeners();
      return;
    }
    _history.add(step.id);
    _cursor = visible[index + 1].id;
    _direction = PromptDirection.forward;
    notifyListeners();
  }

  void _moveTo(String stepId, PromptDirection direction) {
    final bool exists = visibleSteps.any((PromptStep s) => s.id == stepId);
    if (!exists) return;
    if (_cursor != null && direction == PromptDirection.forward) {
      _history.add(_cursor ?? current.id);
    }
    _cursor = stepId;
    _direction = direction;
    notifyListeners();
  }
}
