import 'package:flutter/material.dart';

import '../../../../core/motion/entry_reveal.dart';
import '../../domain/history_folder.dart';
import 'history_category_passes_view.dart';
import 'history_folders_view.dart';

/// History experience: folders root ↔ category list, in-tab (no nested route).
///
/// Stays inside the Passes tab so the dashboard backdrop remains visible —
/// no opaque black navigator stack. Pass details are opened by strips via the
/// root navigator (same as active wallet cards).
class HistoryPassesShell extends StatefulWidget {
  const HistoryPassesShell({
    super.key,
    required this.folders,
  });

  final List<HistoryFolderSummary> folders;

  @override
  State<HistoryPassesShell> createState() => _HistoryPassesShellState();
}

class _HistoryPassesShellState extends State<HistoryPassesShell> {
  HistoryFolderSummary? _openFolder;

  void _open(HistoryFolderSummary folder) {
    setState(() => _openFolder = folder);
  }

  void _closeFolder() {
    if (_openFolder == null) return;
    setState(() => _openFolder = null);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final HistoryFolderSummary? open = _openFolder;

    // System back closes the open folder; at root, History is a filter so we
    // do not pop the dashboard.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_openFolder != null) {
          _closeFolder();
        }
      },
      child: AnimatedSwitcher(
        duration: reduce
            ? const Duration(milliseconds: 180)
            : const Duration(milliseconds: 380),
        reverseDuration: reduce
            ? const Duration(milliseconds: 140)
            : const Duration(milliseconds: 280),
        switchInCurve: easeOutQuint,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          if (reduce) {
            return FadeTransition(opacity: animation, child: child);
          }
          final Animation<double> fade = CurvedAnimation(
            parent: animation,
            curve: easeOutQuint,
            reverseCurve: Curves.easeInCubic,
          );
          final Animation<Offset> slide = Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(fade);
          final Animation<double> scale = Tween<double>(
            begin: 0.98,
            end: 1.0,
          ).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          );
        },
        child: open == null
            ? HistoryFoldersView(
                key: const ValueKey<String>('history-folders'),
                folders: widget.folders,
                onOpenFolder: _open,
              )
            : HistoryCategoryPassesView(
                key: ValueKey<String>('history-cat-${open.category.name}'),
                folder: open,
                onBack: _closeFolder,
              ),
      ),
    );
  }
}
