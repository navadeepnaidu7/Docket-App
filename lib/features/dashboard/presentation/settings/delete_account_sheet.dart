import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_session_provider.dart';
import 'settings_rows.dart';

class DeleteAccountAction extends ConsumerWidget {
  const DeleteAccountAction({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.realAccount || !auth.session.isSignedIn) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        const SettingsDivider(),
        SettingsLinkRow(
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFFF3B30),
          title: 'Delete account',
          onTap: () {
            if (auth.busy) return;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              isDismissible: false,
              enableDrag: false,
              showDragHandle: true,
              builder: (_) => DeleteAccountSheet(
                onDelete: ref
                    .read(authControllerProvider.notifier)
                    .deleteAccount,
              ),
            );
          },
        ),
      ],
    );
  }
}

class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key, required this.onDelete});
  final Future<void> Function() onDelete;
  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || _confirmation.text != 'DELETE') return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not delete your account. Nothing was removed from this phone. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete your account?',
              style: AppFonts.ui(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'Permanently deleted',
              style: AppFonts.ui(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Your Docket account, all server passes and their history, calendar connection, notification registrations and preferences.',
              style: AppFonts.ui(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Kept on this phone',
              style: AppFonts.ui(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Passports, IDs, payment cards and attachments. These never leave this phone.',
              style: AppFonts.ui(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmation,
              enabled: !_busy,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: !_busy && _confirmation.text == 'DELETE'
                  ? _delete
                  : null,
              child: Text(_busy ? 'Deleting account…' : 'Delete account'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
