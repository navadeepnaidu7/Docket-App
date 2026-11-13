import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../application/screen_secure.dart';
import '../domain/card_number.dart';
import '../domain/card_surface.dart';
import '../domain/payment_card.dart';
import 'bank_mark.dart';
import 'card_material.dart';
import 'network_mark.dart';

/// An identifying face. The security code lives in the information section.
class WalletPaymentCard extends StatefulWidget {
  const WalletPaymentCard({
    super.key,
    required this.card,
    this.onLongPress,
    this.now,
    this.interactive = true,
    this.previewNetwork,
  });
  final PaymentCard card;
  final bool interactive;
  final CardNetwork? previewNetwork;
  final VoidCallback? onLongPress;
  final DateTime Function()? now;
  @override
  State<WalletPaymentCard> createState() => _WalletPaymentCardState();
}

class _WalletPaymentCardState extends State<WalletPaymentCard>
    with WidgetsBindingObserver {
  bool _numberOpen = false;
  bool _opening = false;
  bool _active = true;
  Timer? _numberTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _hideNumber() {
    _numberTimer?.cancel();
    if (!_numberOpen) return;
    setState(() => _numberOpen = false);
    unawaited(ScreenSecure.release());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) _hideNumber();
  }

  @override
  void didUpdateWidget(covariant WalletPaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.number != widget.card.number ||
        oldWidget.card.id != widget.card.id) {
      _hideNumber();
    }
  }

  Future<void> _toggleNumber() async {
    if (_opening) return;
    if (_numberOpen) {
      _hideNumber();
      return;
    }
    _opening = true;
    final number = widget.card.number;
    await ScreenSecure.acquire();
    _opening = false;
    if (!mounted || !_active || number != widget.card.number) {
      await ScreenSecure.release();
      return;
    }
    setState(() => _numberOpen = true);
    _numberTimer = Timer(const Duration(seconds: 5), _hideNumber);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _numberTimer?.cancel();
    if (_numberOpen) unawaited(ScreenSecure.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final surface = cardSurfaceStyle(card.issuerId, card.surfaceIndex);
    final network = widget.previewNetwork ?? card.network;
    final expired = card.isExpiredAt(widget.now?.call() ?? DateTime.now());
    final title = card.bankName.trim().isEmpty
        ? (network?.label ?? 'Payment card')
        : card.displayBank;
    final kind = switch (card.kind) {
      CardKind.debit => 'Debit',
      CardKind.credit => 'Credit',
      CardKind.unset => '',
    };
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: WalletCardCanvas(
        designSize: WalletCardMetrics.idCanvas,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CustomPaint(
            painter: CardMaterial(
              surface,
              issuerId: card.issuerId,
              variant: card.surfaceIndex,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 28,
                  right: 126,
                  top: 26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BankMark(card: card),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.ui(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.4,
                            height: 1.2,
                            color: surface.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (kind.isNotEmpty)
                  Positioned(
                    right: 28,
                    top: 68,
                    child: Text(
                      kind,
                      style: AppFonts.ui(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: surface.ink.withValues(alpha: .8),
                      ),
                    ),
                  ),
                Positioned(
                  right: 28,
                  top: 26,
                  width: 80,
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: NetworkMark(network: network, surface: surface),
                  ),
                ),
                Positioned(
                  left: 28,
                  right: 28,
                  top: 120,
                  height: 64,
                  child: _NumberButton(
                    card: card,
                    open: _numberOpen,
                    ink: surface.ink,
                    onTap: widget.interactive && card.number.isNotEmpty
                        ? _toggleNumber
                        : null,
                  ),
                ),

                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          card.holderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: surface.ink,
                          ),
                        ),
                      ),
                      if (card.expiryLabel.isNotEmpty) ...[
                        const SizedBox(width: 24),
                        Text(
                          expired ? 'Expired' : card.expiryLabel,
                          style: AppFonts.ui(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: surface.ink,
                            fontFeatures: AppFonts.tabular,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({
    required this.card,
    required this.open,
    required this.ink,
    required this.onTap,
  });
  final PaymentCard card;
  final bool open;
  final Color ink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: open
        ? 'Hide card number'
        : 'Card number ending ${card.lastFour}. Double tap to reveal.',
    child: ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: card.number.isEmpty || open
                  ? Text(
                      card.number.isEmpty
                          ? 'Add your card'
                          : groupedCardNumber(card.number),
                      style: GoogleFonts.robotoMono(
                        fontSize: open ? 24 : 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: .6,
                        color: card.number.isEmpty
                            ? ink.withValues(alpha: .4)
                            : ink,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '••••',
                          style: GoogleFonts.robotoMono(
                            fontSize: 22,
                            letterSpacing: 3,
                            color: ink.withValues(alpha: .65),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          card.lastFour,
                          style: GoogleFonts.robotoMono(
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
