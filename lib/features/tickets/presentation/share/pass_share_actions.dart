import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../shared/widgets/pass_action_bar.dart';
import '../../application/pass_share_service.dart';
import '../../domain/pass_catalog.dart';

/// The Save / Share bar as the three pass detail screens use it.
///
/// Owns the button states so the screens themselves stay as thin as they are
/// today — the movie screen in particular is a `StatelessWidget` and there is
/// no reason for exporting an image to change that.
class PassShareActions extends StatefulWidget {
  const PassShareActions({super.key, required this.item});

  final WalletPassItem item;

  @override
  State<PassShareActions> createState() => _PassShareActionsState();
}

class _PassShareActionsState extends State<PassShareActions> {
  /// How long "Saved" stays up before the button settles back to "Save".
  static const Duration _doneHold = Duration(milliseconds: 1600);

  PassActionState _save = PassActionState.idle;
  PassActionState _share = PassActionState.idle;

  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _holdThenSettle() {
    _settle?.cancel();
    _settle = Timer(_doneHold, () {
      if (!mounted) return;
      setState(() => _save = PassActionState.idle);
    });
  }

  void _report(PassShareResult result) {
    if (result.isOk || result.message == null) return;
    if (!mounted) return;
    HapticService.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message!)),
    );
  }

  Future<void> _onSave() async {
    if (_save == PassActionState.busy || _share == PassActionState.busy) return;
    HapticService.select();
    _settle?.cancel();
    setState(() => _save = PassActionState.busy);

    final PassShareResult result =
        await PassShareService.saveToGallery(context, widget.item);
    if (!mounted) return;

    if (result.isOk) {
      HapticService.success();
      setState(() => _save = PassActionState.done);
      _holdThenSettle();
      return;
    }

    setState(() => _save = PassActionState.idle);
    _report(result);
  }

  Future<void> _onShare() async {
    if (_save == PassActionState.busy || _share == PassActionState.busy) return;
    HapticService.select();
    setState(() => _share = PassActionState.busy);

    final PassShareResult result =
        await PassShareService.share(context, widget.item);
    if (!mounted) return;

    // No "done" state for share: the OS sheet is its own confirmation, and a
    // button reading "Shared" would be a lie when the sheet was dismissed.
    setState(() => _share = PassActionState.idle);
    _report(result);
  }

  @override
  Widget build(BuildContext context) {
    return PassActionBar(
      secondaryLabel: 'Save',
      secondaryBusyLabel: 'Saving',
      secondaryDoneLabel: 'Saved',
      primaryLabel: 'Share',
      primaryBusyLabel: 'Preparing',
      secondaryState: _save,
      primaryState: _share,
      onSecondary: _onSave,
      onPrimary: _onShare,
    );
  }
}
