import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../shared/widgets/entry/document_entry_scaffold.dart';
import '../../../../shared/widgets/studio_field.dart';
import '../../application/pass_ingest_service.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_ingest.dart';
import '../../domain/pnr_format.dart';
import 'pass_ingest_feedback.dart';

class PnrEntryScreen extends ConsumerStatefulWidget {
  const PnrEntryScreen({super.key});

  @override
  ConsumerState<PnrEntryScreen> createState() => _PnrEntryScreenState();
}

class _PnrEntryScreenState extends ConsumerState<PnrEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && PnrFormat.isValid(_controller.text);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    // Captured before the await: this screen pops itself on success, and a
    // popped context can no longer resolve a messenger.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final WalletPassItem item = await ref
          .read(passIngestServiceProvider)
          .submitPnr(_controller.text);
      if (!mounted) return;
      HapticService.success();
      Navigator.of(context).pop(true);
      showPassIngestSuccess(messenger, item);
    } on PassIngestException catch (e) {
      if (!mounted) return;
      HapticService.error();
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      await showPassIngestError(context, e);
    } catch (_) {
      if (!mounted) return;
      HapticService.error();
      setState(() {
        _submitting = false;
        _error = 'Could not add that PNR.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DocumentEntryScaffold(
      title: 'Train PNR',
      stepIndex: 0,
      stepCount: 1,
      showProgress: false,
      onBack: () => Navigator.of(context).pop(),
      primaryLabel: _submitting ? 'Adding…' : 'Add pass',
      primaryEnabled: _canSubmit,
      onPrimary: _submit,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          StudioField(
            controller: _controller,
            label: 'PNR',
            hintText: '10 digits',
            icon: Icons.confirmation_number_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            errorText: _error,
            onChanged: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}
