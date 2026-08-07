import 'package:flutter/material.dart';

import '../../domain/history_folder.dart';
import 'history_category_passes_view.dart';
import 'history_folders_view.dart';

/// History experience: folders root ↔ category list, in-tab (no nested route).
///
/// Cross-fades only (no scale/slide fight) so switches stay smooth.
class HistoryPassesShell extends StatefulWidget {
  const HistoryPassesShell({
    super.key,
    required this.folders,
  });

  final List<HistoryFolderSummary> folders;

  @override
  State<HistoryPassesShell> createState() => _HistoryPassesShellState();
}

class _HistoryPassesShellState extends State<HistoryPassesShell>
    with SingleTickerProviderStateMixin {
  HistoryFolderSummary? _openFolder;
  late final AnimationController _switchCtrl;
  late final Animation<double> _fadeOut;
  late final Animation<double> _fadeIn;

  /// Content shown under the outgoing layer during a switch.
  Widget? _outgoing;
  Widget? _incoming;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _switchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    // Staggered cross-fade: old eases out first half, new eases in second.
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _switchCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _switchCtrl,
        curve: const Interval(0.30, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _switchCtrl.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _outgoing = null;
          _incoming = null;
        });
        _switchCtrl.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _switchCtrl.dispose();
    super.dispose();
  }

  Widget _folders() => HistoryFoldersView(
        key: const ValueKey<String>('history-folders'),
        folders: widget.folders,
        onOpenFolder: _open,
      );

  Widget _category(HistoryFolderSummary folder) => HistoryCategoryPassesView(
        key: ValueKey<String>('history-cat-${folder.category.name}'),
        folder: folder,
        onBack: _closeFolder,
      );

  Widget _current() {
    final HistoryFolderSummary? open = _openFolder;
    return open == null ? _folders() : _category(open);
  }

  void _transitionTo(HistoryFolderSummary? next) {
    if (_switchCtrl.isAnimating) return;
    final bool reduce =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduce) {
      setState(() {
        _openFolder = next;
        _outgoing = null;
        _incoming = null;
      });
      return;
    }

    final Widget from = _current();
    setState(() {
      _openFolder = next;
      _outgoing = from;
      _incoming = _current();
      _forward = next != null;
    });
    _switchCtrl.forward(from: 0);
  }

  void _open(HistoryFolderSummary folder) => _transitionTo(folder);

  void _closeFolder() {
    if (_openFolder == null) return;
    _transitionTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _openFolder == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_openFolder != null) {
          _closeFolder();
        }
      },
      child: AnimatedBuilder(
        animation: _switchCtrl,
        builder: (BuildContext context, Widget? _) {
          final bool animating =
              _switchCtrl.isAnimating || _outgoing != null && _incoming != null;

          if (!animating) {
            return KeyedSubtree(
              key: ValueKey<String>(
                _openFolder == null
                    ? 'folders'
                    : 'cat-${_openFolder!.category.name}',
              ),
              child: _current(),
            );
          }

          // Soft horizontal drift in the open/close direction (very slight).
          final double drift = _forward ? 10.0 : -10.0;
          final double t = _switchCtrl.value;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_outgoing != null)
                IgnorePointer(
                  child: Opacity(
                    opacity: _fadeOut.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(-drift * t * 0.35, 0),
                      child: _outgoing,
                    ),
                  ),
                ),
              if (_incoming != null)
                Opacity(
                  opacity: _fadeIn.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(drift * (1 - t) * 0.45, 0),
                    child: _incoming,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
