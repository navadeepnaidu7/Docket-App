import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/motion/smooth_curves.dart';
import '../../application/attachment_open_service.dart';
import '../../application/attachment_providers.dart';
import '../../application/id_list_provider.dart';
import '../../domain/attachment_limits.dart';
import '../../domain/id_attachment.dart';
import '../../domain/id_document.dart';
import 'attachment_full_screen_viewer.dart';
import 'id_attachment_tray.dart';

/// Opens the long-press sheet for an ID card: the attachment tray above, the
/// destructive action sheet below, the card still visible through the scrim.
///
/// Deliberately not `showCupertinoModalPopup`. That route slides its entire
/// child up from the bottom, which would carry the tray along with the action
/// sheet as one block. The issue asks for the tray to bloom in place over the
/// dimmed card, so the two need to be animated separately.
Future<void> showIdAttachmentSheet(
  BuildContext context, {
  required IdDocument document,
  required VoidCallback onRemove,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x8A000000),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext ctx, _, _) => _IdAttachmentSheet(
        documentId: document.id,
        onRemove: onRemove,
      ),
      transitionsBuilder: (
        BuildContext ctx,
        Animation<double> animation,
        Animation<double> secondary,
        Widget child,
      ) {
        return _SheetTransition(animation: animation, child: child);
      },
    ),
  );
}

/// Splits one route animation into two: the action sheet slides up on the
/// Cupertino timing users already know, while the tray fades and scales in
/// slightly later so the card is seen to dim *before* the tray appears over it.
class _SheetTransition extends StatelessWidget {
  const _SheetTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Short, non-essential motion: honour the platform's reduce-motion setting
    // by cutting straight to the end state.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return child;
    }
    return _SheetTransitionScope(animation: animation, child: child);
  }
}

/// Carries the route animation down to the two halves of the sheet.
class _SheetTransitionScope extends InheritedWidget {
  const _SheetTransitionScope({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SheetTransitionScope>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SheetTransitionScope oldWidget) =>
      oldWidget.animation != animation;
}

class _IdAttachmentSheet extends ConsumerStatefulWidget {
  const _IdAttachmentSheet({required this.documentId, required this.onRemove});

  final String documentId;
  final VoidCallback onRemove;

  @override
  ConsumerState<_IdAttachmentSheet> createState() => _IdAttachmentSheetState();
}

class _IdAttachmentSheetState extends ConsumerState<_IdAttachmentSheet> {
  bool _picking = false;

  Future<Uint8List> _resolveBytes(IdAttachment attachment) {
    return ref
        .read(attachmentStoreProvider)
        .resolveBytes(widget.documentId, attachment);
  }

  Future<void> _handleAdd() async {
    // The picker is a platform round trip; a second tap while it is open would
    // stack two sheets and race two writes at the same document.
    if (_picking) return;
    _picking = true;
    HapticService.tap();

    try {
      final FilePickerResult? picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
        withData: false,
      );

      // Not `files.single`: that throws when a non-null result carries an
      // empty list, which some platforms return on cancel.
      final List<PlatformFile> files = picked?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;
      final String? path = files.first.path;
      if (path == null || path.isEmpty) return;

      final AttachResult result = await ref
          .read(idListProvider.notifier)
          .addAttachment(widget.documentId, File(path));

      if (!mounted) return;

      switch (result) {
        case AttachSuccess():
          HapticService.success();
        case AttachFailure(message: final String message):
          HapticService.error();
          _showRejection(message);
      }
    } catch (_) {
      // The store refuses writes when its key cannot be read, and the picker
      // itself can fail. Without this the throw escapes an unawaited callback
      // and the user is left with a tray that simply did nothing.
      if (!mounted) return;
      HapticService.error();
      _showRejection('Could not attach the file.');
    } finally {
      _picking = false;
    }
  }

  /// Rejections surface as a Cupertino alert rather than a snackbar: this app
  /// has no snackbar anywhere, and the tray is already inside a modal so a
  /// bar sliding in behind it would be half-covered.
  void _showRejection(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Cannot attach'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
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

  /// An image opens a zoomable viewer in-app; a PDF goes out to the device's
  /// own viewer, which is the only way to get page scrolling and text
  /// selection without rebuilding a reader here.
  Future<void> _handleOpen(IdAttachment attachment) async {
    HapticService.tap();

    if (attachment.kind == IdAttachmentKind.image) {
      await showAttachmentFullScreen(
        context,
        attachment: attachment,
        resolveBytes: _resolveBytes,
      );
      return;
    }

    final String? failure = await AttachmentOpenService.openExternally(
      store: ref.read(attachmentStoreProvider),
      docId: widget.documentId,
      attachment: attachment,
      fileExtension: 'pdf',
    );

    if (!mounted || failure == null) return;
    HapticService.error();
    _showRejection(failure);
  }

  @override
  void dispose() {
    // The external viewer works from a decrypted copy in the cache. Closing the
    // sheet is the natural end of that viewing session, so drop it here rather
    // than leaving it for the next app start.
    AttachmentOpenService.purge();
    super.dispose();
  }

  Future<void> _confirmRemoveAttachment(IdAttachment attachment) async {
    HapticService.destructive();
    final bool? confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Remove attachment?'),
        message: const Text(
          'The copy is deleted from this device. The ID card itself stays.',
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(idListProvider.notifier)
        .removeAttachment(widget.documentId, attachment.id);
  }

  @override
  Widget build(BuildContext context) {
    // Watching the list keeps the tray honest: an add or remove rewrites the
    // record, and the tray redraws from it rather than from local state.
    final List<IdDocument> documents = ref.watch(idListProvider);
    final int index = documents.indexWhere((d) => d.id == widget.documentId);

    // The document can vanish underneath this sheet (a restore, a sync, the
    // remove action itself). Close rather than render a stale card.
    if (index == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final IdDocument document = documents[index];
    final List<IdAttachment> attachments = document.attachments;

    final bool canAddMore = rejectionFor(
          existing: attachments,
          incoming: IdAttachmentKind.image,
          sizeBytes: 0,
        ) ==
        null ||
        rejectionFor(
          existing: attachments,
          incoming: IdAttachmentKind.pdf,
          sizeBytes: 0,
        ) ==
            null;

    final Animation<double>? animation = _SheetTransitionScope.maybeOf(context);

    final Widget tray = IdAttachmentTray(
      attachments: attachments,
      resolveBytes: _resolveBytes,
      onAdd: _handleAdd,
      onRemoveRequested: (int i) {
        if (i < 0 || i >= attachments.length) return;
        _confirmRemoveAttachment(attachments[i]);
      },
      onOpenRequested: (int i) {
        if (i < 0 || i >= attachments.length) return;
        _handleOpen(attachments[i]);
      },
      canAddMore: canAddMore,
    );

    final Widget actionSheet = _RemoveActionSheet(
      document: document,
      onRemove: () {
        Navigator.of(context).pop();
        widget.onRemove();
      },
    );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _TrayEntrance(
                animation: animation,
                // Sits below centre rather than at it. Dead-centring leaves the
                // tray floating in the empty upper half; nudging it down closes
                // the gap to the action sheet and keeps the whole composition
                // in the lower two thirds, nearer the thumb.
                child: Align(
                  alignment: const Alignment(0, 0.45),
                  child: tray,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SheetSlide(animation: animation, child: actionSheet),
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts the tray in, starting after the scrim has visibly darkened.
class _TrayEntrance extends StatelessWidget {
  const _TrayEntrance({required this.animation, required this.child});

  final Animation<double>? animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? source = animation;
    if (source == null) return child;

    final Animation<double> delayed = CurvedAnimation(
      parent: source,
      // The 0.18 head start is the beat where only the scrim is moving, so the
      // card is seen to dim first and the tray reads as arriving over it.
      curve: const Interval(0.18, 1.0, curve: smoothCurve),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: delayed,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.0).animate(delayed),
        child: child,
      ),
    );
  }
}

/// Slides the action sheet up on Cupertino's own timing, so the destructive
/// control feels exactly as it did before the tray existed.
class _SheetSlide extends StatelessWidget {
  const _SheetSlide({required this.animation, required this.child});

  final Animation<double>? animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? source = animation;
    if (source == null) return child;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: source, curve: Curves.easeOutCubic),
      ),
      child: child,
    );
  }
}

/// The original destructive sheet, unchanged in wording and behaviour.
class _RemoveActionSheet extends StatelessWidget {
  const _RemoveActionSheet({required this.document, required this.onRemove});

  final IdDocument document;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String label =
        document.holderName.isEmpty ? 'this card' : "${document.holderName}'s";
    final String type =
        document.type == IdDocumentType.pan ? 'PAN Card' : 'Aadhaar Card';

    return CupertinoActionSheet(
      title: const Text('Remove ID Card?'),
      message: Text('This will remove $label $type from your wallet.'),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: onRemove,
          child: const Text('Remove'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    );
  }
}
