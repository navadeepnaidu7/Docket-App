import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/bounce_tap.dart';
import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../application/trash_provider.dart';

class TrashView extends ConsumerWidget {
  const TrashView({super.key});

  void _showConfirmDeleteDialog(BuildContext context, WidgetRef ref, Object item) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text(
          'This card will be permanently deleted from your offline wallet and cannot be restored.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              ref.read(trashProvider.notifier).permanentlyDeleteItem(item);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trashState = ref.watch(trashProvider);
    final List<Object> items = [...trashState.passports, ...trashState.idDocs];

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.trash,
                size: 36,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Trash is Empty',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1C1C1E),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Items removed from your wallet are stored here until restored or deleted permanently.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TrashCardTile(
          item: item,
          onRestore: () {
            ref.read(trashProvider.notifier).restoreItem(item, ref);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  item is PassportProfile ? 'Passport restored to wallet' : 'ID Document restored to wallet',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onDelete: () => _showConfirmDeleteDialog(context, ref, item),
        );
      },
    );
  }
}

class TrashCardTile extends StatelessWidget {
  const TrashCardTile({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  final Object item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String title;
    final String subtitle;
    final IconData icon;
    final Color iconColor;

    if (item is PassportProfile) {
      final p = item as PassportProfile;
      title = p.name.isEmpty ? 'Passport' : "${p.name.split(' ').first}'s Passport";
      subtitle = p.passportNumber.isEmpty ? 'Passport' : p.passportNumber;
      icon = CupertinoIcons.book;
      iconColor = const Color(0xFF4C7CFF);
    } else {
      final d = item as IdDocument;
      title = d.holderName.isEmpty
          ? (d.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card')
          : "${d.holderName.split(' ').first}'s ID";
      subtitle = d.documentNumber;
      icon = CupertinoIcons.creditcard;
      iconColor = const Color(0xFF19D3C5);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF1C1C1E).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF1C1C1E).withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BounceTap(
              onTap: onRestore,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C7CFF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_counterclockwise,
                  size: 18,
                  color: Color(0xFF4C7CFF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BounceTap(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: Color(0xFFFF453A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
