import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/entry_reveal.dart';
import '../application/passport_draft_controller.dart';
import '../domain/passport_profile.dart';

class PassportEntryScreen extends ConsumerStatefulWidget {
  const PassportEntryScreen({super.key});

  @override
  ConsumerState<PassportEntryScreen> createState() => _PassportEntryScreenState();
}

class _PassportEntryScreenState extends ConsumerState<PassportEntryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _passportNumberController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _mrzController;

  @override
  void initState() {
    super.initState();
    final PassportProfile profile = ref.read(passportDraftProvider);
    _nameController = TextEditingController(text: profile.name);
    _passportNumberController = TextEditingController(text: profile.passportNumber);
    _nationalityController = TextEditingController(text: profile.nationality);
    _dateOfBirthController = TextEditingController(text: profile.dateOfBirth);
    _expiryDateController = TextEditingController(text: profile.expiryDate);
    _mrzController = TextEditingController(text: profile.mrzRaw);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passportNumberController.dispose();
    _nationalityController.dispose();
    _dateOfBirthController.dispose();
    _expiryDateController.dispose();
    _mrzController.dispose();
    super.dispose();
  }

  void _syncDraft() {
    final PassportDraftController controller = ref.read(passportDraftProvider.notifier);
    controller
      ..updateName(_nameController.text)
      ..updatePassportNumber(_passportNumberController.text)
      ..updateNationality(_nationalityController.text)
      ..updateDateOfBirth(_dateOfBirthController.text)
      ..updateExpiryDate(_expiryDateController.text)
      ..updateMrzRaw(_mrzController.text);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PassportProfile profile = ref.watch(passportDraftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: <Widget>[
          EntryReveal(
            delay: const Duration(milliseconds: 0),
            child: _HeroCard(profile: profile),
          ),
          const SizedBox(height: 20),
          EntryReveal(
            delay: const Duration(milliseconds: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Manual details', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _EntryField(
                  controller: _nameController,
                  label: 'Full name',
                  onChanged: (_) => _syncDraft(),
                ),
                const SizedBox(height: 12),
                _EntryField(
                  controller: _passportNumberController,
                  label: 'Passport number',
                  onChanged: (_) => _syncDraft(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _EntryField(
                        controller: _nationalityController,
                        label: 'Nationality',
                        onChanged: (_) => _syncDraft(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EntryField(
                        controller: _dateOfBirthController,
                        label: 'Date of birth',
                        hintText: 'YYYY-MM-DD',
                        onChanged: (_) => _syncDraft(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EntryField(
                  controller: _expiryDateController,
                  label: 'Expiry date',
                  hintText: 'YYYY-MM-DD',
                  onChanged: (_) => _syncDraft(),
                ),
                const SizedBox(height: 12),
                _EntryField(
                  controller: _mrzController,
                  label: 'MRZ raw text',
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => _syncDraft(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EntryReveal(
            delay: const Duration(milliseconds: 220),
            child: FilledButton.icon(
              onPressed: () {
                _syncDraft();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passport draft saved locally in memory.')),
                );
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save draft'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile});

  final PassportProfile profile;

  @override
  Widget build(BuildContext context) {
    final bool hasName = profile.name.trim().isNotEmpty;
    final String displayName = hasName ? profile.name : 'Add a passport profile';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF111827), Color(0xFF2653FF), Color(0xFF0F172A)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, 18)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Live preview', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.badge_rounded, color: Colors.white, size: 30),
            ],
          ),
          const SizedBox(height: 18),
          _DetailChip(label: 'Passport', value: profile.passportNumber.isEmpty ? 'Pending' : profile.passportNumber),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: _DetailChip(label: 'Nationality', value: profile.nationality.isEmpty ? '--' : profile.nationality)),
              const SizedBox(width: 10),
              Expanded(child: _DetailChip(label: 'DOB', value: profile.dateOfBirth.isEmpty ? '--' : profile.dateOfBirth)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EntryField extends StatelessWidget {
  const _EntryField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hintText,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
      ),
    );
  }
}