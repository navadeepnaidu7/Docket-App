import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/pass_catalog.dart';
import '../../domain/pass_ingest.dart';
import '../../domain/pass_status.dart';

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
    PassIngestCode.unreadable => 'Could not read pass',
    PassIngestCode.failed => 'Could not add pass',
  };
}

/// Confirms a saved pass, and says where it landed.
///
/// Only [TicketStatus.active] passes reach the wallet — `activePassesProvider`
/// filters the rest into the archive. A past-dated ticket therefore extracts
/// perfectly and still leaves the wallet looking untouched, which reads as a
/// silent failure unless the confirmation names the archive.
///
/// Takes the messenger rather than a [BuildContext] because the PNR screen pops
/// itself on success, and a popped context can no longer look one up.
void showPassIngestSuccess(
  ScaffoldMessengerState messenger,
  WalletPassItem item,
) {
  final String label = switch (item) {
    TrainPassItem(:final ticket) => ticket.trainName,
    MoviePassItem(:final pass) => pass.movieTitle,
    BusPassItem(:final pass) => pass.operator,
  };
  final String subject = label.trim().isEmpty ? 'Pass' : label.trim();

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        item.status == TicketStatus.expired
            ? '$subject saved to Archive — that date has passed.'
            : '$subject added to your wallet.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
