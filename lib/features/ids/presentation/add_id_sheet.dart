import 'package:flutter/material.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../../../shared/widgets/apple_sheet.dart';
import '../domain/id_document.dart';

class AddIdSheet extends StatelessWidget {
  const AddIdSheet({super.key, required this.onSelectType});

  final void Function(IdDocumentType) onSelectType;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Add ID Card',
      subtitle: 'Choose the type of ID to add',
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IdOption(
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFFC6973F), // PAN warm gold
            title: 'PAN Card',
            subtitle: 'Permanent Account Number — Income Tax India',
            onTap: () {
              Navigator.of(context).pop();
              onSelectType(IdDocumentType.pan);
            },
          ),
          const SizedBox(height: 12),
          _IdOption(
            icon: Icons.fingerprint_rounded,
            iconColor: const Color(0xFF005EA6), // Aadhaar blue
            title: 'Aadhaar Card',
            subtitle: 'UIDAI 12-digit biometric identity',
            onTap: () {
              Navigator.of(context).pop();
              onSelectType(IdDocumentType.aadhaar);
            },
          ),
          const SizedBox(height: 12),
          _IdOption(
            icon: Icons.drive_eta_rounded,
            iconColor: const Color(0xFF8E8E93),
            title: 'Driving Licence',
            subtitle: 'State-issued driving licence',
            onTap: () {},
            comingSoon: true,
          ),
          const SizedBox(height: 12),
          _IdOption(
            icon: Icons.how_to_vote_rounded,
            iconColor: const Color(0xFF8E8E93),
            title: 'Voter ID',
            subtitle: 'Election Commission of India',
            onTap: () {},
            comingSoon: true,
          ),
        ],
      ),
    );
  }
}

class _IdOption extends StatelessWidget {
  const _IdOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF2F2F7);

    final Color titleColor = isDark
        ? Colors.white
        : const Color(0xFF1C1C1E);

    final Color subtitleColor = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF8E8E93);

    final Color soonBg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE5E5EA);

    final Color soonText = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF8E8E93);

    return BounceTap(
      onTap: comingSoon ? null : onTap,
      scaleFactor: 0.98,
      child: Opacity(
        opacity: comingSoon ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: soonBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Soon',
                              style: TextStyle(
                                color: soonText,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!comingSoon)
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
