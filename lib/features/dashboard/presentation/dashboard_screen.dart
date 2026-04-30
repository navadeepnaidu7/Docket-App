import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/entry_reveal.dart';
import '../../passport/application/passport_draft_controller.dart';
import '../../passport/domain/passport_profile.dart';
import '../../passport/presentation/passport_entry_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final PassportProfile profile = ref.watch(passportDraftProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const _Backdrop(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                const EntryReveal(
                  delay: Duration(milliseconds: 0),
                  child: _Header(),
                ),
                const SizedBox(height: 24),
                EntryReveal(
                  delay: const Duration(milliseconds: 90),
                  child: _PassportCard(colors: colors, profile: profile),
                ),
                const SizedBox(height: 22),
                EntryReveal(
                  delay: const Duration(milliseconds: 160),
                  child: _ActionRow(
                    colors: colors,
                    onScanTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PassportEntryScreen()),
                      );
                    },
                    onNfcTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('NFC flow will land here next.')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const EntryReveal(
                  delay: Duration(milliseconds: 220),
                  child: _SectionTitle(
                    title: 'Passport proverbs',
                    subtitle: 'Quiet reminders that identity should feel effortless.',
                  ),
                ),
                const SizedBox(height: 12),
                const EntryReveal(
                  delay: Duration(milliseconds: 260),
                  child: _ProverbStrip(),
                ),
                const SizedBox(height: 12),
                const EntryReveal(
                  delay: Duration(milliseconds: 320),
                  child: _SectionTitle(
                    title: 'Build direction',
                    subtitle: 'Android-first foundation for a sleek passport workflow.',
                  ),
                ),
                const SizedBox(height: 12),
                EntryReveal(
                  delay: const Duration(milliseconds: 360),
                  child: _PlanCard(
                    title: '1. Foundation',
                    body: 'Theme, navigation shell, and app state structure.',
                    accent: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                EntryReveal(
                  delay: const Duration(milliseconds: 400),
                  child: _PlanCard(
                    title: '2. Capture and OCR',
                    body: 'Camera flow, MRZ cropping, and text extraction.',
                    accent: colors.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                const EntryReveal(
                  delay: Duration(milliseconds: 440),
                  child: _PlanCard(
                    title: '3. NFC and secure storage',
                    body: 'Local storage, encrypted data, and Android chip reads.',
                    accent: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF8FAFF),
              Color(0xFFEFF4FB),
              Color(0xFFF7F8FC),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -90,
              right: -70,
              child: _Orb(color: Color(0xFF4C7CFF), size: 220),
            ),
            Positioned(
              top: 120,
              left: -100,
              child: _Orb(color: Color(0xFF19D3C5), size: 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'SlickPort',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 10),
              Text(
                'A sleek, modern Android passport workspace with motion-first UI.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: const Icon(Icons.credit_card_rounded, size: 28),
        ),
      ],
    );
  }
}

class _PassportCard extends StatelessWidget {
  const _PassportCard({required this.colors, required this.profile});

  final ColorScheme colors;
  final PassportProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF091827),
            colors.primary.withValues(alpha: 0.96),
            const Color(0xFF111827),
          ],
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
                children: const <Widget>[
                  Text('Passport profile', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 6),
                ],
              ),
            ],
          ),
          Text(
            profile.name.isEmpty ? 'Add a passport profile' : profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 24),
          _PassportField(label: 'Passport number', value: profile.passportNumber.isEmpty ? 'Pending' : profile.passportNumber),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _PassportField(label: 'Nationality', value: profile.nationality.isEmpty ? '--' : profile.nationality)),
              const SizedBox(width: 12),
              Expanded(child: _PassportField(label: 'Expiry', value: profile.expiryDate.isEmpty ? '--' : profile.expiryDate)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('NFC ready', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('OCR pending', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PassportField extends StatelessWidget {
  const _PassportField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.colors, required this.onScanTap, required this.onNfcTap});

  final ColorScheme colors;
  final VoidCallback onScanTap;
  final VoidCallback onNfcTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            icon: Icons.document_scanner_rounded,
            title: 'Scan MRZ',
            subtitle: 'Camera + OCR',
            tint: colors.primary,
            onTap: onScanTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.nfc_rounded,
            title: 'Read chip',
            subtitle: 'Android NFC',
            tint: colors.secondary,
            onTap: onNfcTap,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.title, required this.subtitle, required this.tint, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.body, required this.accent});

  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProverbStrip extends StatelessWidget {
  const _ProverbStrip();

  static const List<_Proverb> _items = <_Proverb>[
    _Proverb(title: 'Clarity', body: 'Small details carry big trust.'),
    _Proverb(title: 'Identity', body: 'Presence should feel light, not loud.'),
    _Proverb(title: 'Travel', body: 'Move fast, verify faster.'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final _Proverb proverb = _items[index];
          return EntryReveal(
            delay: Duration(milliseconds: 60 * index),
            child: _ProverbCard(proverb: proverb),
          );
        },
      ),
    );
  }
}

class _ProverbCard extends StatelessWidget {
  const _ProverbCard({required this.proverb});

  final _Proverb proverb;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                proverb.title,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                proverb.body,
                style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Proverb {
  const _Proverb({required this.title, required this.body});

  final String title;
  final String body;
}