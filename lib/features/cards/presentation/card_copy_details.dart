import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../application/screen_secure.dart';
import '../domain/card_number.dart';
import '../domain/payment_card.dart';
import 'card_entry_fields.dart';

/// Utilities below the issuer information, independent of the card artwork.
class CardCopyDetails extends StatelessWidget {
  const CardCopyDetails({super.key, required this.card});
  final PaymentCard card;

  @override
  Widget build(BuildContext context) => CardFieldGroup(
    children: [
      _CopyField(
        key: ValueKey('${card.id}:number'),
        label: 'Card number',
        value: card.number,
        display: groupedCardNumber(card.number),
        masked: '•••• ${card.lastFour}',
      ),
      _CopyField(
        key: ValueKey('${card.id}:cvv'),
        label: 'Security code',
        value: card.cvv,
        masked: '•' * card.cvv.length,
      ),
      _CopyField(
        key: ValueKey('${card.id}:holder'),
        label: 'Name on card',
        value: card.holderName,
      ),
      _CopyField(
        key: ValueKey('${card.id}:expiry'),
        label: 'Expiry date',
        value: card.expiryLabel,
      ),
    ],
  );
}

class _CopyField extends StatefulWidget {
  const _CopyField({
    super.key,
    required this.label,
    required this.value,
    this.display,
    this.masked,
  });
  final String label;
  final String value;
  final String? display;
  final String? masked;
  @override
  State<_CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<_CopyField> with WidgetsBindingObserver {
  bool _revealed = false;
  bool _opening = false;
  bool _active = true;
  bool _copied = false;
  Timer? _revealTimer;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _hide() {
    _revealTimer?.cancel();
    if (!_revealed) return;
    setState(() => _revealed = false);
    unawaited(ScreenSecure.release());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) _hide();
  }

  @override
  void didUpdateWidget(covariant _CopyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _hide();
      _copyTimer?.cancel();
      _copied = false;
    }
  }

  Future<void> _toggleReveal() async {
    if (_opening) return;
    if (_revealed) {
      _hide();
      return;
    }
    _opening = true;
    final value = widget.value;
    await ScreenSecure.acquire();
    _opening = false;
    if (!mounted || !_active || value != widget.value) {
      await ScreenSecure.release();
      return;
    }
    setState(() => _revealed = true);
    _revealTimer = Timer(const Duration(seconds: 5), _hide);
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.value));
      if (!mounted) return;
      HapticService.select();
      _copyTimer?.cancel();
      setState(() => _copied = true);
      _copyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy. Try again.')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealTimer?.cancel();
    _copyTimer?.cancel();
    if (_revealed) unawaited(ScreenSecure.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final present = widget.value.trim().isNotEmpty;
    final sensitive = widget.masked != null;
    final shown = !present
        ? 'Not added'
        : sensitive && !_revealed
        ? widget.masked!
        : widget.display ?? widget.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppFonts.ui(
                    fontSize: 12,
                    color: AppTokens.secondaryLabel(scheme),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  shown,
                  style: AppFonts.ui(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFeatures: AppFonts.tabular,
                    color: present
                        ? scheme.onSurface
                        : AppTokens.secondaryLabel(scheme),
                  ),
                ),
              ],
            ),
          ),
          if (present && sensitive)
            IconButton(
              tooltip:
                  '${_revealed ? 'Hide' : 'Reveal'} ${widget.label.toLowerCase()}',
              onPressed: _toggleReveal,
              icon: Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              color: AppTokens.secondaryLabel(scheme),
            ),
          if (present)
            Semantics(
              liveRegion: _copied,
              label: _copied ? '${widget.label} copied' : null,
              child: IconButton(
                tooltip: _copied
                    ? '${widget.label} copied'
                    : 'Copy ${widget.label.toLowerCase()}',
                onPressed: _copy,
                icon: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 19,
                ),
                color: _copied
                    ? scheme.onSurface
                    : AppTokens.secondaryLabel(scheme),
              ),
            ),
        ],
      ),
    );
  }
}
