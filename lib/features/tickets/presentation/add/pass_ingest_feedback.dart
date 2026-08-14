import 'package:flutter/cupertino.dart';

import '../../domain/pass_ingest.dart';

Future<void> showPassIngestError(
  BuildContext context,
  PassIngestException error,
) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (BuildContext ctx) => CupertinoAlertDialog(
      title: Text(_titleFor(error.code)),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(error.message),
      ),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _titleFor(PassIngestCode code) {
  return switch (code) {
    PassIngestCode.needsRemote => 'Connect a server',
    PassIngestCode.needsAuth => 'Sign in required',
    PassIngestCode.invalidPnr => 'Check the PNR',
    PassIngestCode.fileTooLarge => 'File too large',
    PassIngestCode.unsupportedFile => 'Unsupported file',
    PassIngestCode.rateLimited => 'Scan limit reached',
    PassIngestCode.unreadable => 'Saved',
    PassIngestCode.failed => 'Could not add pass',
  };
}
