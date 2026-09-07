import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/prompt_typography.dart';
import 'prompt_caret.dart';

/// Sequential character slots with a blinking underline instead of a caret.
///
/// Native [TextField] stays in the tree for IME, paste, and accessibility;
/// glyphs and dashes are painted separately so tracking never fights the
/// insertion point.
class PromptSlotInput extends StatefulWidget {
  const PromptSlotInput({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onSubmitted,
    this.isDate = false,
    this.length,
    this.keyboardType,
    this.digitsOnly = false,
    this.hasError = false,
    this.onComplete,
  });

  final String value;
  final String label;
  final bool isDate;

  /// Slot count. Defaults to 8 for dates and 9 for document numbers.
  final int? length;
  final TextInputType? keyboardType;
  final bool digitsOnly;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback? onComplete;

  @override
  State<PromptSlotInput> createState() => _PromptSlotInputState();
}

class _PromptSlotInputState extends State<PromptSlotInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();
  late final AnimationController _blink;
  Timer? _focusTimer;
  late int _lastLength;

  int get _length => widget.length ?? (widget.isDate ? 8 : 9);

  String _display(String value) {
    if (!widget.isDate || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return value;
    }
    return '${value.substring(8)}${value.substring(5, 7)}${value.substring(0, 4)}';
  }

  String _store(String value) {
    if (widget.isDate && value.length == 8) {
      return '${value.substring(4)}-${value.substring(2, 4)}-${value.substring(0, 2)}';
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    final String display = _display(widget.value);
    _text = TextEditingController(text: display);
    _lastLength = display.length;
    _blink = AnimationController(vsync: this, duration: PromptCaret.period);
    _focus.addListener(_syncBlink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestFocus());
  }

  void _requestFocus() {
    if (!mounted) return;
    _focusTimer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _focus.requestFocus();
      return;
    }
    // Focusing during the step slide drops the first keystroke and janks
    // the incoming motion. PromptTextInput uses the same delay.
    _focusTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBlink();
  }

  void _syncBlink() {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final bool live =
        _focus.hasFocus && !reduced && _text.text.length < _length;
    if (live) {
      if (!_blink.isAnimating) _blink.repeat();
    } else {
      _blink.stop();
      _blink.value = 0;
    }
  }

  @override
  void didUpdateWidget(PromptSlotInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String display = _display(widget.value);
    if (oldWidget.value != widget.value && display != _text.text) {
      _text.value = TextEditingValue(
        text: display,
        selection: TextSelection.collapsed(offset: display.length),
      );
      _lastLength = display.length;
      _syncBlink();
    }
  }

  void _changed(String value) {
    final int previous = _lastLength;
    _lastLength = value.length;
    widget.onChanged(_store(value));
    _syncBlink();
    if (value.length == _length && previous < _length) {
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _focus.removeListener(_syncBlink);
    _focus.dispose();
    _text.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle mono = Theme.of(context).textTheme.promptInputMono;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cell = constraints.maxWidth / _length;
        final double fontSize = math.min(26, cell * 0.62);
        final TextStyle glyph = mono.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          height: 1,
          color: widget.hasError ? colors.error : colors.onSurface,
        );

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: SizedBox(
            height: 72,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        _blink,
                        _text,
                        _focus,
                      ]),
                      builder: (BuildContext context, Widget? _) {
                        return _SlotRow(
                          text: _text.text,
                          length: _length,
                          focused: _focus.hasFocus,
                          blink: _blink.value,
                          reduced: MediaQuery.disableAnimationsOf(context),
                          style: glyph,
                          ink: widget.hasError
                              ? colors.error
                              : colors.onSurface,
                        );
                      },
                    ),
                  ),
                ),
                Semantics(
                  label: widget.label,
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    showCursor: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                    textDirection: TextDirection.ltr,
                    style: glyph.copyWith(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    keyboardType:
                        widget.keyboardType ??
                        (widget.isDate
                            ? TextInputType.number
                            : TextInputType.text),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        widget.isDate || widget.digitsOnly
                            ? RegExp('[0-9]')
                            : RegExp('[a-zA-Z0-9]'),
                      ),
                      TextInputFormatter.withFunction((
                        TextEditingValue oldValue,
                        TextEditingValue newValue,
                      ) {
                        final String upper = newValue.text.toUpperCase();
                        return newValue.copyWith(
                          text: upper,
                          selection: TextSelection.collapsed(
                            offset: upper.length,
                          ),
                          composing: TextRange.empty,
                        );
                      }),
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    onChanged: _changed,
                    onSubmitted: (_) => widget.onSubmitted(),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.text,
    required this.length,
    required this.focused,
    required this.blink,
    required this.reduced,
    required this.style,
    required this.ink,
  });

  final String text;
  final int length;
  final bool focused;
  final double blink;
  final bool reduced;
  final TextStyle style;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final int filled = text.length;
    final bool complete = filled >= length;
    final int active = (!focused || complete) ? -1 : filled;
    final double glow = reduced ? 1 : PromptCaret.envelope(blink);

    return Row(
      children: List<Widget>.generate(length, (int index) {
        final bool selected = index == active;
        final String char = index < filled ? text[index] : '';
        final double widthFactor = selected ? 0.70 + glow * 0.22 : 0.58;
        final double alpha = selected
            ? 0.22 + glow * 0.78
            : (char.isEmpty ? 0.22 : 0.38);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(char, style: style, maxLines: 1),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 3,
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: alpha),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: selected && glow > 0.4
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: ink.withValues(
                                      alpha: (glow - 0.4) * 0.28,
                                    ),
                                    blurRadius: 5,
                                    spreadRadius: 0.4,
                                  ),
                                ]
                              : null,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
