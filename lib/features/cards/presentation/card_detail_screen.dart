import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../application/card_list_provider.dart';
import '../application/card_scan_provider.dart';
import '../application/screen_secure.dart';
import '../domain/payment_card.dart';
import '../domain/card_number.dart';
import '../domain/card_surface.dart';
import 'card_entry_fields.dart';
import 'card_copy_details.dart';
import 'network_mark.dart';
import 'card_review_screen.dart';
import 'wallet_payment_card.dart';

/// The card, its photos, and the way back into the review.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PaymentCard? card;
    for (final PaymentCard item in ref.watch(cardListProvider)) {
      if (item.id == cardId) {
        card = item;
        break;
      }
    }
    if (card == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'This card is no longer in your wallet.',
            style: AppFonts.ui(fontSize: 16),
          ),
        ),
      );
    }
    final PaymentCard current = card;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final brightness = Theme.of(context).brightness;
    final surface = CardSurfaceStyle(
      background: AppTheme.surface(brightness),
      ink: scheme.onSurface,
      light: brightness == Brightness.light,
    );
    final kind = switch (current.kind) {
      CardKind.debit => 'Debit',
      CardKind.credit => 'Credit',
      CardKind.unset => 'Not specified',
    };
    return Scaffold(
      backgroundColor: AppTheme.background(brightness),
      appBar: AppBar(
        title: Text(
          'Card details',
          style: AppFonts.ui(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: () => openCardReview(context, existing: current),
            child: const Text('Edit'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: WalletCardMetrics.idAspect,
            child: WalletPaymentCard(card: current, animate: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Text(
              'Tap the last four digits to reveal your card number.',
              textAlign: TextAlign.center,
              style: AppFonts.ui(
                fontSize: 12,
                color: AppTokens.tertiaryLabel(scheme),
              ),
            ),
          ),
          CardFieldGroup(
            children: [
              _DetailRow(
                label: 'Bank',
                value: current.bankName.isEmpty
                    ? 'Not specified'
                    : current.bankName,
              ),
              _DetailRow(
                label: 'Network',
                value: current.network?.label ?? 'Not recognized',
                trailing: current.network == null
                    ? null
                    : NetworkMark(network: current.network, surface: surface),
              ),
              _DetailRow(label: 'Card type', value: kind),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
            child: Text(
              'Card information',
              style: AppFonts.ui(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTokens.secondaryLabel(scheme),
              ),
            ),
          ),
          CardCopyDetails(card: current),
          if (current.scans.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: Text(
                'Scanned photos',
                style: AppFonts.ui(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.secondaryLabel(scheme),
                ),
              ),
            ),
            CardFieldGroup(
              children: [
                for (final scan in current.scans)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(
                      Icons.photo_outlined,
                      size: 22,
                      color: AppTokens.secondaryLabel(scheme),
                    ),
                    title: Text(
                      _sideLabel(scan.side),
                      style: AppFonts.ui(fontSize: 15),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppTokens.secondaryLabel(scheme),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CardScanPhotoScreen(cardId: current.id, scan: scan),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.trailing});
  final String label;
  final String value;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.ui(
                fontSize: 15,
                color: AppTokens.secondaryLabel(scheme),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (trailing == null)
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppFonts.ui(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

String _sideLabel(String side) {
  return switch (side) {
    'front' => 'Front photo',
    'back' => 'Back photo',
    _ => 'Photo',
  };
}

/// A decrypted scan. The screen stays secure for as long as it is open.
class CardScanPhotoScreen extends ConsumerStatefulWidget {
  const CardScanPhotoScreen({
    super.key,
    required this.cardId,
    required this.scan,
  });

  final String cardId;
  final CardScanRef scan;

  @override
  ConsumerState<CardScanPhotoScreen> createState() =>
      _CardScanPhotoScreenState();
}

class _CardScanPhotoScreenState extends ConsumerState<CardScanPhotoScreen> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenSecure.acquire());
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(ScreenSecure.release());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Uint8List bytes = await ref
          .read(cardScanStoreProvider)
          .read(cardId: widget.cardId, scan: widget.scan);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_sideLabel(widget.scan.side)),
      ),
      body: Center(
        child: bytes != null
            ? InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))
            : _failed
            ? Text(
                'This photo could not be opened.',
                style: AppFonts.ui(color: Colors.white, fontSize: 16),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
