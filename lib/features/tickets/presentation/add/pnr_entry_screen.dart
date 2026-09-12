import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/prompt_typography.dart';
import '../../../../shared/prompt_flow/prompt_flow_controller.dart';
import '../../../../shared/prompt_flow/prompt_flow_screen.dart';
import '../../../../shared/prompt_flow/prompt_step.dart';
import '../../../../shared/prompt_flow/widgets/prompt_slot_input.dart';
import '../../application/pass_ingest_controller.dart';
import '../../domain/pnr_format.dart';

class PnrEntryScreen extends ConsumerStatefulWidget {
  const PnrEntryScreen({
    super.key,
    this.initialPnr = '',
    this.replaceFailed = false,
  });
  final String initialPnr;
  final bool replaceFailed;

  @override
  ConsumerState<PnrEntryScreen> createState() => _PnrEntryScreenState();
}

class _PnrEntryScreenState extends ConsumerState<PnrEntryScreen> {
  static const String _field = 'pnr';

  late final PromptFlowController _flow;
  String? _conflict;

  @override
  void initState() {
    super.initState();
    _flow = PromptFlowController(
      steps: <PromptStep>[
        PromptStep(
          id: _field,
          kind: PromptStepKind.text,
          question: (_) => 'Enter PNR',
          helper: (_) => '10 digits',
          label: 'PNR',
          style: PromptInputStyle.mono,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validate: (String value, PromptFlowState _) =>
              PnrFormat.isValid(value) ? null : 'PNR is 10 digits.',
        ),
      ],
    );
    if (widget.initialPnr.isNotEmpty) _flow.setValue(_field, widget.initialPnr);
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  bool get _canSubmit => PnrFormat.isValid(_flow.state.value(_field));

  void _submit() {
    if (!_canSubmit) {
      _flow.next();
      return;
    }
    final bool started = ref
        .read(passIngestControllerProvider.notifier)
        .startPnr(
          _flow.state.value(_field),
          replaceFailed: widget.replaceFailed,
        );
    if (started) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _conflict = 'Another pass is already being added.');
  }

  void _advanceWhenFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_canSubmit) return;
      HapticService.select();
      _submit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flow,
      builder: (BuildContext context, Widget? _) {
        return PromptFlowScreen(
          controller: _flow,
          minimal: true,
          stepBuilder: (BuildContext context, PromptStep step) {
            return Column(
              children: <Widget>[
                PromptSlotInput(
                  value: _flow.state.value(_field),
                  label: 'PNR',
                  length: 10,
                  keyboardType: TextInputType.number,
                  digitsOnly: true,
                  hasError: _flow.currentError != null || _conflict != null,
                  onChanged: (String value) {
                    if (_conflict != null) setState(() => _conflict = null);
                    _flow.setValue(_field, value);
                  },
                  onSubmitted: _submit,
                  onComplete: _advanceWhenFilled,
                ),
                if (_conflict != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _conflict!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.promptError,
                    ),
                  ),
              ],
            );
          },
          primaryLabel: 'Add pass',
          primaryEnabled: _canSubmit,
          onPrimary: _submit,
          onExit: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
