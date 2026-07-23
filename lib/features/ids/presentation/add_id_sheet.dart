import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/apple_sheet.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../domain/id_document.dart';
import '../domain/id_document_catalog.dart';

class AddIdSheet extends StatelessWidget {
  const AddIdSheet({super.key, required this.onSelectType});

  final void Function(IdDocumentType) onSelectType;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Add ID card',
      subtitle: 'Choose a document type',
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _IdOption(
            icon: Icons.account_balance_rounded,
            iconColor: IdDocumentCatalog.descriptorFor(IdDocumentType.pan)
                .sheetIconColor,
            title: IdDocumentCatalog.titleFor(IdDocumentType.pan),
            subtitle: 'Permanent Account Number — Income Tax India',
            onTap: () {
              Navigator.of(context).pop();
              onSelectType(IdDocumentType.pan);
            },
          ),
          const SizedBox(height: 10),
          _IdOption(
            icon: Icons.fingerprint_rounded,
            iconColor: IdDocumentCatalog.descriptorFor(IdDocumentType.aadhaar)
                .sheetIconColor,
            title: IdDocumentCatalog.titleFor(IdDocumentType.aadhaar),
            subtitle: 'UIDAI 12-digit biometric identity',
            onTap: () {
              Navigator.of(context).pop();
              onSelectType(IdDocumentType.aadhaar);
            },
          ),
          const SizedBox(height: 10),
          _IdOption(
            icon: Icons.drive_eta_rounded,
            iconColor: const Color(0xFF8E8E93),
            title: 'Driving Licence',
            subtitle: 'State-issued driving licence',
            onTap: () {},
            comingSoon: true,
          ),
          const SizedBox(height: 10),
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;

    final Color bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.88);

    final Color titleColor = scheme.onSurface;
    final Color subtitleColor = AppTokens.secondaryLabel(scheme);

    return BounceTap(
      onTap: comingSoon ? null : onTap,
      scaleFactor: 0.98,
      child: Opacity(
        opacity: comingSoon ? 0.48 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : scheme.onSurface.withValues(alpha: 0.05),
            ),
            boxShadow: comingSoon || isDark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: <Widget>[
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
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              color: titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (comingSoon) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Soon',
                              style: GoogleFonts.inter(
                                color: subtitleColor,
                                fontSize: 11,
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
                      style: GoogleFonts.inter(
                        color: subtitleColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!comingSoon)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTokens.tertiaryLabel(scheme),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
