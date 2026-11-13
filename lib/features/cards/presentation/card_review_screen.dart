import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/motion/studio_page_route.dart';
import '../../../core/storage/card_scan_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/application/wallet_order_provider.dart';
import '../application/card_list_provider.dart';
import '../application/card_scan_provider.dart';
import '../application/screen_secure.dart';
import '../domain/card_issuer.dart';
import '../domain/card_number.dart';
import '../domain/card_surface.dart';
import '../domain/payment_card.dart';
import 'bank_mark.dart';
import 'card_entry_fields.dart';
import 'network_mark.dart';
import 'wallet_payment_card.dart';

/// The check before a card is saved. Nothing reaches the wallet from the
/// camera shutter alone.
class CardReviewScreen extends ConsumerStatefulWidget {
  const CardReviewScreen({
    super.key,
    this.existing,
    this.number = '',
    this.holderName = '',
    this.expiryMonth,
    this.expiryYear,
    this.cvv = '',
    this.frontPath,
    this.backPath,
    this.fromScan = false,
  });

  final PaymentCard? existing;
  final String number;
  final String holderName;
  final int? expiryMonth;
  final int? expiryYear;
  final String cvv;
  final String? frontPath;
  final String? backPath;

  /// The camera is still under this route, so saving closes both.
  final bool fromScan;

  @override
  ConsumerState<CardReviewScreen> createState() => _CardReviewScreenState();
}

class _CardReviewScreenState extends ConsumerState<CardReviewScreen> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _expiry;
  late final TextEditingController _cvv;
  late final TextEditingController _bank;
  late CardKind _kind;
  bool _bankChosen = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenSecure.acquire());
    final PaymentCard? existing = widget.existing;
    _number = TextEditingController(
      text: groupedCardNumber(existing?.number ?? widget.number),
    );
    _name = TextEditingController(
      text: existing?.holderName ?? widget.holderName,
    );
    _expiry = TextEditingController(
      text:
          existing?.expiryLabel ??
          (widget.expiryMonth == null || widget.expiryYear == null
              ? ''
              : formatCardExpiry(widget.expiryMonth!, widget.expiryYear!)),
    );
    _cvv = TextEditingController(text: existing?.cvv ?? widget.cvv);
    _bank = TextEditingController(text: existing?.bankName ?? _suggestedBank());
    _kind = existing?.kind ?? CardKind.unset;
    _bankChosen = existing?.bankName.trim().isNotEmpty ?? false;
    for (final controller in [_name, _expiry, _cvv, _bank]) {
      controller.addListener(_onChanged);
    }
    _number.addListener(_onNumberChanged);
  }

  void _onNumberChanged() {
    if (!mounted) return;
    if (!_bankChosen) {
      final suggested = lookupCardIssuer(_number.text)?.name ?? '';
      if (_bank.text != suggested) _bank.text = suggested;
    }
    _onChanged();
  }

  void _onChanged() {
    if (mounted) setState(() => _error = null);
  }

  String _suggestedBank() {
    if (widget.existing != null) return widget.existing!.bankName;
    return lookupCardIssuer(widget.number)?.name ?? '';
  }

  @override
  void dispose() {
    _number.removeListener(_onNumberChanged);
    _number.dispose();
    _name.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _bank.dispose();
    unawaited(ScreenSecure.release());
    super.dispose();
  }

  CardNetwork? get _matched => detectCardNetwork(_number.text);

  Future<void> _save() async {
    final String digits = cardDigits(_number.text);
    if (!cardNumberValid(digits)) {
      setState(() => _error = 'That number does not check out.');
      return;
    }
    final String expiryRaw = _expiry.text.trim();
    final (int, int)? expiry = parseCardExpiry(expiryRaw);
    if (expiryRaw.isNotEmpty && expiry == null) {
      setState(() => _error = 'Expiry should look like 09/28.');
      return;
    }
    final String cvv = cardDigits(_cvv.text);
    final codeLength = _matched?.securityCodeLength ?? 3;
    if (cvv.isNotEmpty && cvv.length != codeLength) {
      setState(() => _error = 'Enter the $codeLength-digit security code.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final PaymentCard? existing = widget.existing;
    final List<PaymentCard> others = ref.read(cardListProvider);
    final ({String? issuerId, int surfaceIndex, String bankName}) face =
        resolveCardFace(
          bankName: _bank.text,
          number: digits,
          existing: others,
          exceptId: existing?.id,
        );
    final int surface = existing != null && existing.issuerId == face.issuerId
        ? existing.surfaceIndex
        : face.surfaceIndex;

    try {
      final String id = existing?.id ?? PaymentCard().id;
      List<CardScanRef> scans = existing?.scans ?? const <CardScanRef>[];
      if (widget.frontPath != null || widget.backPath != null) {
        final CardScanStore store = ref.read(cardScanStoreProvider);
        final List<CardScanRef> saved = <CardScanRef>[];
        if (widget.frontPath != null) {
          saved.add(
            await store.save(
              cardId: id,
              side: 'front',
              file: File(widget.frontPath!),
            ),
          );
        }
        if (widget.backPath != null) {
          saved.add(
            await store.save(
              cardId: id,
              side: 'back',
              file: File(widget.backPath!),
            ),
          );
        }
        scans = saved;
        await _deleteTemp(widget.frontPath);
        await _deleteTemp(widget.backPath);
      }

      final PaymentCard card = PaymentCard(
        id: id,
        holderName: _name.text.trim(),
        number: digits,
        expiryMonth: expiry?.$1,
        expiryYear: expiry?.$2,
        cvv: cvv,
        kind: _kind,
        bankName: face.bankName,
        issuerId: face.issuerId,
        surfaceIndex: surface,
        manualNetwork: null,
        scans: scans,
      );
      await ref.read(cardListProvider.notifier).saveCard(card);
      ref.read(walletOrderProvider.notifier).updateOrderOnItemAdded(card.id);
      if (!mounted) return;
      HapticService.confirm();
      final NavigatorState navigator = Navigator.of(context);
      navigator.pop();
      if (widget.fromScan && navigator.canPop()) {
        navigator.pop();
      }
    } on DuplicateCardException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'This card is already in your wallet.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this card.';
      });
    }
  }

  Future<void> _deleteTemp(String? path) async {
    if (path == null) return;
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matched = _matched;
    final valid = cardNumberValid(_number.text);
    final digits = cardDigits(_number.text);
    final expiry = parseCardExpiry(_expiry.text);
    final issuer = issuerFromName(_bank.text);
    final saved = widget.existing;
    final preview = PaymentCard(
      id: 'entry-preview',
      number: digits,
      holderName: _name.text,
      cvv: cardDigits(_cvv.text),
      bankName: _bank.text,
      expiryMonth: expiry?.$1,
      expiryYear: expiry?.$2,
      issuerId: issuer?.id,
      surfaceIndex: saved != null && saved.issuerId == issuer?.id
          ? saved.surfaceIndex
          : 0,
      kind: _kind,
    );
    final bool showNumberError = digits.length >= 13 && !valid;
    final surface = CardSurfaceStyle(
      background: AppTheme.surface(theme.brightness),
      ink: scheme.onSurface,
      light: theme.brightness == Brightness.light,
    );
    return Scaffold(
      backgroundColor: AppTheme.background(theme.brightness),
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Add card' : 'Edit card',
          style: AppFonts.ui(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.background(theme.brightness),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 1.586,
                child: ExcludeSemantics(
                  child: WalletPaymentCard(
                    card: preview,
                    interactive: false,
                    previewNetwork: matched,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            child: Text(
              'Card details',
              style: AppFonts.ui(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTokens.secondaryLabel(scheme),
              ),
            ),
          ),
          CardFieldGroup(
            children: [
              CardEntryField(
                label: 'Card number',
                controller: _number,
                hint: 'Enter card number',
                keyboard: TextInputType.number,
                formatters: [_CardNumberFormatter()],
                suffix: matched == null
                    ? null
                    : Center(
                        widthFactor: 1,
                        child: NetworkMark(network: matched, surface: surface),
                      ),
              ),
              CardEntryField(
                label: 'Name on card',
                controller: _name,
                hint: 'As printed on the card',
                keyboard: TextInputType.name,
              ),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: CardEntryField(
                        label: 'Expiry',
                        controller: _expiry,
                        hint: 'MM/YY',
                        keyboard: TextInputType.number,
                        formatters: [_CardExpiryFormatter()],
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: .5,
                      indent: 12,
                      endIndent: 12,
                      color: scheme.onSurface.withValues(alpha: .1),
                    ),
                    Expanded(
                      child: CardEntryField(
                        label: matched == CardNetwork.amex
                            ? 'Security code · 4 digits'
                            : 'Security code',
                        controller: _cvv,
                        hint: 'Optional',
                        keyboard: TextInputType.number,
                        obscure: true,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showNumberError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Check the card number.',
                style: AppFonts.ui(fontSize: 12, color: scheme.error),
              ),
            ),
          const SizedBox(height: 16),
          CardFieldGroup(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: issuer == null ? null : BankMark(card: preview),
                title: Text(
                  _bank.text.isEmpty ? 'Bank' : _bank.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _bank.text.isEmpty ? 'Choose or enter a bank' : 'Card issuer',
                  style: AppFonts.ui(
                    fontSize: 12,
                    color: AppTokens.secondaryLabel(scheme),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTokens.secondaryLabel(scheme),
                ),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  final name = await pickCardBank(context, _bank.text);
                  if (name != null && mounted) {
                    _bankChosen = true;
                    _bank.text = name;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          CardKindControl(
            value: _kind,
            onChanged: (kind) => setState(() => _kind = kind),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                _error!,
                style: AppFonts.ui(fontSize: 13, color: scheme.error),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: AppTheme.controlHeight,
                child: FilledButton(
                  onPressed: _saving || !valid ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save card'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Stored only on this device',
                style: AppFonts.ui(
                  fontSize: 11,
                  color: AppTokens.secondaryLabel(scheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = cardDigits(newValue.text);
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = clipped.length <= 2
        ? clipped
        : '${clipped.substring(0, 2)}/${clipped.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = cardDigits(newValue.text);
    final String clipped = digits.length > 19
        ? digits.substring(0, 19)
        : digits;
    final String grouped = groupedCardNumber(clipped);
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}

/// Opens the review on top of the current route.
Future<void> openCardReview(BuildContext context, {PaymentCard? existing}) {
  return Navigator.of(context).push(
    studioPageRoute<void>(builder: (_) => CardReviewScreen(existing: existing)),
  );
}
