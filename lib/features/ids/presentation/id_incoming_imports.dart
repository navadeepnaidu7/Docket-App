import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../application/id_media_service.dart';
import '../application/id_share_service.dart';
import '../domain/id_document.dart';
import 'id_document_ui.dart';
import 'id_entry_screen.dart';

/// Keeps incoming shares queued while another import/review route is active.
class IdIncomingImports extends StatefulWidget {
  const IdIncomingImports({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<IdIncomingImports> createState() => _IdIncomingImportsState();
}

class _IdIncomingImportsState extends State<IdIncomingImports> {
  static const _channel = MethodChannel('com.docket/id_import');
  bool _draining = false;
  @override
  void initState() {
    super.initState();
    unawaited(_sweep());
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'filesAvailable') await _drain();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
    }
  }

  Future<void> _sweep() async {
    try {
      await IdImportSession.sweepStale();
      await IdShareService.sweepStale();
    } catch (_) {
      /* Best effort. */
    }
  }

  Future<void> _drain() async {
    if (_draining || !mounted) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    _draining = true;
    try {
      while (mounted) {
        final batch = await _channel.invokeMapMethod<String, dynamic>(
          'takePending',
        );
        if (batch == null || !mounted) break;
        final error = batch['error'] as String?;
        if (error != null) {
          await showIdMessage(navigator.context, 'Could not import', error);
          continue;
        }
        final paths =
            (batch['files'] as List?)?.whereType<String>().toList() ?? [];
        try {
          if (paths.isNotEmpty) {
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => _IncomingDocument(files: paths),
              ),
            );
          }
        } finally {
          await _channel.invokeMethod<void>('release', {
            'token': batch['token'],
          });
        }
      }
    } on MissingPluginException {
      /* Desktop and widget previews have no native receiver. */
    } catch (_) {
      /* A rejected external payload must not interrupt the wallet. */
    } finally {
      _draining = false;
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingDocument extends StatefulWidget {
  const _IncomingDocument({required this.files});
  final List<String> files;
  @override
  State<_IncomingDocument> createState() => _IncomingDocumentState();
}

class _IncomingDocumentState extends State<_IncomingDocument> {
  bool _opening = false;
  Future<void> _open(IdDocumentType type) async {
    if (_opening) return;
    setState(() => _opening = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdEntryScreen(type: type, initialFiles: widget.files),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add to Docket')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What kind of ID is this?',
            style: AppFonts.ui(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'} received. Review the details before saving.',
          ),
          const SizedBox(height: 28),
          IdSection(
            children: [
              for (final type in IdDocumentType.values)
                ListTile(
                  title: Text(
                    type == IdDocumentType.pan ? 'PAN card' : 'Aadhaar card',
                  ),
                  onTap: _opening ? null : () => _open(type),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
