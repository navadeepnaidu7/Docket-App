import 'package:flutter/material.dart';

import '../../../../shared/widgets/apple_sheet.dart';
import '../../../../shared/widgets/bounce_tap.dart';

class AddItemSheet extends StatelessWidget {
  const AddItemSheet({
    super.key,
    required this.onAddPassport,
    required this.onAddId,
  });

  final VoidCallback onAddPassport;
  final VoidCallback onAddId;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Add Document',
      subtitle: "Choose what you'd like to add",
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AddOption(
            icon: Icons.book_rounded,
            iconColor: const Color(0xFF4C7CFF),
            title: 'Passport',
            subtitle: 'Indian passport or travel document',
            onTap: onAddPassport,
          ),
          const SizedBox(height: 12),
          AddOption(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF1C3252),
            title: 'ID Card',
            subtitle: 'PAN Card, Aadhaar or national ID',
            onTap: onAddId,
          ),
        ],
      ),
    );
  }
}

class TicketsComingSoonSheet extends StatelessWidget {
  const TicketsComingSoonSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppleSheet(
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF19D3C5).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: Color(0xFF19D3C5),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tickets Coming Soon',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Flight, train, bus and event tickets\nwill be available in a future update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class PassportTypeSheet extends StatelessWidget {
  const PassportTypeSheet({
    super.key,
    required this.onSelectEPassport,
    required this.onSelectRegularPassport,
  });

  final VoidCallback onSelectEPassport;
  final VoidCallback onSelectRegularPassport;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Passport Type',
      subtitle: "Which kind of passport are you adding?",
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AddOption(
            icon: Icons.nfc_rounded,
            iconColor: const Color(0xFF4C7CFF),
            title: 'E-Passport',
            subtitle: 'Biometric passport with an NFC chip',
            onTap: onSelectEPassport,
          ),
          const SizedBox(height: 12),
          AddOption(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF19D3C5),
            title: 'Regular Passport',
            subtitle: 'Standard passport without NFC',
            onTap: onSelectRegularPassport,
          ),
        ],
      ),
    );
  }
}

class AddOption extends StatefulWidget {
  const AddOption({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<AddOption> createState() => _AddOptionState();
}

class _AddOptionState extends State<AddOption> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.74);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.92);

    final Color titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color subtitleColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B);

    return BounceTap(
      onTap: widget.onTap,
      scaleFactor: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: widget.iconColor.withValues(
                  alpha: 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          children: <Widget>[
            AddOptionPreview(
              icon: widget.icon,
              color: widget.iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: widget.iconColor.withValues(alpha: 0.72),
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddOptionPreview extends StatelessWidget {
  const AddOptionPreview({
    super.key,
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  bool get _isId =>
      icon == Icons.badge_rounded || icon == Icons.credit_card_rounded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color endColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.74);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            endColor,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isId)
            Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.18),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 7,
                      top: 8,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: color.withValues(alpha: 0.28),
                      ),
                    ),
                    Positioned(
                      left: 19,
                      right: 7,
                      top: 8,
                      child: PreviewLine(color: color, alpha: 0.24),
                    ),
                    Positioned(
                      left: 7,
                      right: 12,
                      bottom: 8,
                      child: PreviewLine(color: color, alpha: 0.18),
                    ),
                  ],
                ),
              ),
            )
          else
            Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 38,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 10,
                      child: Container(
                        height: 13,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 10,
                      bottom: 14,
                      child: PreviewLine(color: color, alpha: 0.22),
                    ),
                    Positioned(
                      left: 8,
                      right: 16,
                      bottom: 9,
                      child: PreviewLine(color: color, alpha: 0.16),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewLine extends StatelessWidget {
  const PreviewLine({super.key, required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
