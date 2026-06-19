import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import '../../application/wallet_order_provider.dart';

class ManageCardsView extends ConsumerWidget {
  const ManageCardsView({
    super.key,
    required this.items,
  });

  final List<Object> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.creditcard,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No Cards in Wallet',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1C1C1E),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: ReorderableListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          HapticFeedback.lightImpact();
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final List<String> currentIds = items.map((item) {
            return item is PassportProfile ? item.id : (item as IdDocument).id;
          }).toList();

          final String movedId = currentIds.removeAt(oldIndex);
          currentIds.insert(newIndex, movedId);
          ref.read(walletOrderProvider.notifier).saveOrder(currentIds);
        },
        itemBuilder: (context, index) {
          final item = items[index];
          final String id = item is PassportProfile ? item.id : (item as IdDocument).id;

          return ManageCardTile(
            key: ValueKey(id),
            item: item,
            index: index,
          );
        },
      ),
    );
  }
}

class ManageCardTile extends StatelessWidget {
  const ManageCardTile({
    super.key,
    required this.item,
    required this.index,
  });

  final Object item;
  final int index;

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
        trailing: ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              CupertinoIcons.bars,
              color: isDark ? Colors.white30 : Colors.black26,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
