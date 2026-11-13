import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/card_issuer.dart';
import '../domain/payment_card.dart';
import 'bank_mark.dart';

class CardFieldGroup extends StatelessWidget {
  const CardFieldGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surface(Theme.of(context).brightness),
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: .5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .1),
              ),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class CardEntryField extends StatelessWidget {
  const CardEntryField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard,
    this.obscure = false,
    this.formatters,
    this.suffix,
    this.autofillHints,
    this.maxLength,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;
  final bool obscure;
  final List<TextInputFormatter>? formatters;
  final Widget? suffix;
  final List<String>? autofillHints;
  final int? maxLength;
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: formatters,
      textInputAction: TextInputAction.next,
      autofillHints: autofillHints,
      maxLength: maxLength,
      style: AppFonts.ui(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: .1,
        color: scheme.onSurface,
        fontFeatures: AppFonts.tabular,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: AppFonts.ui(
          fontSize: 16,
          color: AppTokens.secondaryLabel(scheme),
        ),
        hintStyle: AppFonts.ui(
          fontSize: 16,
          color: scheme.onSurface.withValues(alpha: .25),
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 16), child: suffix),
        suffixIconConstraints: const BoxConstraints(
          maxWidth: 72,
          maxHeight: 32,
        ),
      ),
    );
  }
}

class CardKindControl extends StatelessWidget {
  const CardKindControl({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final CardKind value;
  final ValueChanged<CardKind> onChanged;
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return CupertinoSlidingSegmentedControl<CardKind>(
      groupValue: value,
      backgroundColor: scheme.onSurface.withValues(alpha: .055),
      thumbColor: AppTheme.elevated(Theme.of(context).brightness),
      padding: const EdgeInsets.all(4),
      onValueChanged: (kind) {
        if (kind != null) onChanged(kind);
      },
      children: {
        for (final kind in [CardKind.debit, CardKind.credit, CardKind.unset])
          kind: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              switch (kind) {
                CardKind.debit => 'Debit',
                CardKind.credit => 'Credit',
                CardKind.unset => 'Not set',
              },
              style: AppFonts.ui(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
      },
    );
  }
}

Future<String?> pickCardBank(BuildContext context, String current) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BankPicker(current: current),
    );

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.current});
  final String current;
  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  final TextEditingController _query = TextEditingController();
  void _select(String name) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, name);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final matches = cardIssuers
        .where(
          (bank) =>
              bank.name.toLowerCase().contains(query.toLowerCase()) ||
              issuerFromName(query)?.id == bank.id,
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    120)
                .clamp(180.0, MediaQuery.sizeOf(context).height * .7),
        child: Column(
          children: [
            Text(
              'Choose your bank',
              style: AppFonts.ui(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _query,
                autofocus: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search banks',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  for (final issuer in matches)
                    ListTile(
                      leading: BankMark(
                        card: PaymentCard(
                          bankName: issuer.name,
                          issuerId: issuer.id,
                        ),
                      ),
                      title: Text(
                        issuer.name,
                        style: AppFonts.ui(fontSize: 16),
                      ),
                      trailing: issuerFromName(widget.current)?.id == issuer.id
                          ? const Icon(Icons.check_rounded, size: 20)
                          : null,
                      onTap: () => _select(issuer.name),
                    ),
                  if (query.isNotEmpty &&
                      issuerFromName(query) == null &&
                      !matches.any(
                        (bank) =>
                            bank.name.toLowerCase() == query.toLowerCase(),
                      ))
                    ListTile(
                      title: Text('Use “$query”'),
                      subtitle: const Text('Save this bank name'),
                      onTap: () => _select(query),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
