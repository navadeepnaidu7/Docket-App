import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/prompt_typography.dart';
import '../../../core/validation/document_validators.dart';
import '../../widgets/bounce_tap.dart';
import '../prompt_step.dart';

/// A single large text field, the only thing on its screen.
///
/// Autofocus is deferred one frame plus a short delay: focusing while the step
/// transition is still running drops the first keystroke and janks the slide.
class PromptTextInput extends StatefulWidget {
  const PromptTextInput({
    super.key,
    required this.step,
    required this.value,
    required this.onChanged,
    required this.onSubmitted,
    this.hasError = false,
  });

  final PromptStep step;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool hasError;

  @override
  State<PromptTextInput> createState() => _PromptTextInputState();
}

class _PromptTextInputState extends State<PromptTextInput> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _focus.requestFocus();
      });
    });
  }

  @override
  void didUpdateWidget(PromptTextInput old) {
    super.didUpdateWidget(old);
    // Only adopt external changes (a scan landing), never fight the user.
    if (widget.value != old.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool mono = widget.step.style == PromptInputStyle.mono;

    return AnimatedBuilder(
      animation: _focus,
      builder: (BuildContext context, Widget? _) {
        final bool focused = _focus.hasFocus;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x1,
          ),
          decoration: BoxDecoration(
            color: AppTokens.fieldFill(scheme, focused: focused),
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            border: Border.all(
              color: widget.hasError
                  ? AppTheme.danger.withValues(alpha: 0.55)
                  : AppTokens.fieldBorder(scheme, focused: focused),
              width: theme.brightness == Brightness.dark ? 0.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onSubmitted(),
            textInputAction: TextInputAction.next,
            keyboardType: widget.step.keyboardType,
            textCapitalization: widget.step.capitalization,
            inputFormatters: widget.step.inputFormatters,
            maxLength: widget.step.maxLength,
            style: mono
                ? theme.textTheme.promptInputMono
                : theme.textTheme.promptInput,
            cursorColor: scheme.primary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              counterText: '',
              hintText: widget.step.placeholder,
              hintStyle: (mono
                      ? theme.textTheme.promptInputMono
                      : theme.textTheme.promptInput)
                  .copyWith(color: AppTokens.tertiaryLabel(scheme)),
              contentPadding: const EdgeInsets.symmetric(vertical: Space.x3),
            ),
          ),
        );
      },
    );
  }
}

/// An inline date wheel.
///
/// Deliberately not a sheet. The sheet it replaces wrote the controller only
/// from `onDateTimeChanged` and had no confirm button, so opening it and
/// dismissing without scrolling left the field empty — and a user whose date
/// happened to be the default could never set it at all. Here the value is
/// seeded on mount and the step's own CTA is the confirmation.
class PromptDateInput extends StatefulWidget {
  const PromptDateInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.mode = PromptDateMode.past,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final PromptDateMode mode;

  @override
  State<PromptDateInput> createState() => _PromptDateInputState();
}

enum PromptDateMode { past, future }

class _PromptDateInputState extends State<PromptDateInput> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = _initial();
    // Seed immediately so "opened it and moved on" records a real value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.value.trim().isEmpty) {
        widget.onChanged(_format(_selected));
      }
    });
  }

  DateTime get _min => widget.mode == PromptDateMode.past
      ? DateTime(1900)
      : DateTime.now().add(const Duration(days: 1));

  DateTime get _max => widget.mode == PromptDateMode.past
      ? DateTime.now().subtract(const Duration(days: 1))
      : DateTime(DateTime.now().year + 30);

  DateTime _initial() {
    final DateTime? parsed = DocumentValidators.tryParseYmd(widget.value);
    if (parsed != null && !parsed.isBefore(_min) && !parsed.isAfter(_max)) {
      return parsed;
    }
    return widget.mode == PromptDateMode.past
        ? DateTime(DateTime.now().year - 25, 1, 1)
        : DateTime(DateTime.now().year + 5, 1, 1);
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.groupedFieldFill(theme.colorScheme, isDark: isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      height: 190,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: theme.brightness,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: theme.textTheme.promptInput,
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _selected,
          minimumDate: _min,
          maximumDate: _max,
          onDateTimeChanged: (DateTime d) {
            _selected = d;
            widget.onChanged(_format(d));
          },
        ),
      ),
    );
  }
}

/// Radio-style option rows for a small fixed set.
class PromptChoiceList extends StatelessWidget {
  const PromptChoiceList({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  final List<PromptChoice> choices;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      children: <Widget>[
        for (final PromptChoice choice in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: BounceTap(
              scaleFactor: 0.985,
              onTap: () {
                HapticService.select();
                onChanged(choice.value);
              },
              child: Container(
                height: AppTheme.controlHeight,
                padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                decoration: BoxDecoration(
                  color: AppTokens.fieldFill(
                    scheme,
                    focused: choice.value == value,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  border: Border.all(
                    color: choice.value == value
                        ? scheme.primary.withValues(alpha: 0.65)
                        : AppTokens.separator(scheme),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        choice.label,
                        style: theme.textTheme.promptReviewValue,
                      ),
                    ),
                    if (choice.value == value)
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A route choice at the start of a flow: scan, chip, or type it in.
class PromptOptionTile extends StatelessWidget {
  const PromptOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.emphasis = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// The recommended route, given more visual weight than the alternatives.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color background = emphasis
        ? (isDark ? scheme.primary : scheme.onSurface)
        : AppTokens.fieldFill(scheme);
    final Color foreground = emphasis
        ? (isDark ? scheme.onPrimary : scheme.surface)
        : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x3),
      child: BounceTap(
        scaleFactor: 0.985,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: emphasis
                ? null
                : Border.all(color: AppTokens.separator(scheme)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.promptReviewValue.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.promptHelper(scheme).copyWith(
                            fontSize: 13,
                            color: foreground.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: foreground.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presentation for a value that arrived from a scan or the chip.
///
/// The value is shown large enough to check against the document, with a
/// quiet marker saying where it came from. "Change" swaps this step to its
/// normal editable input in place, so correcting a value is never a navigation.
class PromptConfirmValue extends StatelessWidget {
  const PromptConfirmValue({
    super.key,
    required this.value,
    required this.source,
    required this.onChange,
    this.mono = false,
    this.trusted = true,
  });

  final String value;
  final FieldSource source;
  final VoidCallback onChange;
  final bool mono;

  /// False when the MRZ checksum did not verify — the value is shown but
  /// flagged for a second look rather than presented as confirmed.
  final bool trusted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x4,
          ),
          decoration: BoxDecoration(
            color: AppTokens.groupedFieldFill(
              scheme,
              isDark: theme.brightness == Brightness.dark,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Text(
            value,
            style:
                mono ? theme.textTheme.promptInputMono : theme.textTheme.promptInput,
          ),
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: <Widget>[
            _SourceMarker(source: source, trusted: trusted),
            const Spacer(),
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                minimumSize: const Size(0, AppTheme.controlHeightSm),
              ),
              child: Text(
                'Change',
                style: theme.textTheme.promptHelper(scheme).copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceMarker extends StatelessWidget {
  const _SourceMarker({required this.source, required this.trusted});

  final FieldSource source;
  final bool trusted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (!trusted) {
      return Text(
        'Double-check this one',
        style: theme.textTheme.promptHelper(scheme).copyWith(
              fontSize: 13,
              color: AppTheme.accentOf(theme.brightness),
              fontWeight: FontWeight.w600,
            ),
      );
    }

    return switch (source) {
      FieldSource.chip => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.nfc_rounded, size: 14, color: scheme.primary),
            const SizedBox(width: Space.x1),
            Text(
              'From the chip',
              style: theme.textTheme.promptStepCount(scheme).copyWith(
                    color: scheme.primary,
                  ),
            ),
          ],
        ),
      FieldSource.scanned => Text(
          'Scanned',
          style: theme.textTheme.promptStepCount(scheme),
        ),
      // Typed values carry no marker at all — absence is the default.
      FieldSource.typed => const SizedBox.shrink(),
    };
  }
}
