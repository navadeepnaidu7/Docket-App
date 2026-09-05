import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/entry/document_entry_scaffold.dart';
import '../../../../shared/widgets/studio_field.dart';
import '../../application/pass_ingest_controller.dart';
import '../../domain/pnr_format.dart';

class PnrEntryScreen extends ConsumerStatefulWidget {
  const PnrEntryScreen({super.key});

  @override
  ConsumerState<PnrEntryScreen> createState() => _PnrEntryScreenState();
}

class _PnrEntryScreenState extends ConsumerState<PnrEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => PnrFormat.isValid(_controller.text);

  void _submit() {
    if (!_canSubmit) return;
    final bool started = ref
        .read(passIngestControllerProvider.notifier)
        .startPnr(_controller.text);
    if (started) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = 'Another pass is already being added.');
  }

  @override
  Widget build(BuildContext context) {
    return DocumentEntryScaffold(
      title: 'Train PNR',
      stepIndex: 0,
      stepCount: 1,
      showProgress: false,
      onBack: () => Navigator.of(context).pop(),
      primaryLabel: 'Add pass',
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
