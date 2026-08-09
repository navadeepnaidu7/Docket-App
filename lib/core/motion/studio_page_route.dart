import 'package:flutter/material.dart';

/// The app's standard push transition for a peer destination.
///
/// Fade plus a short rise, on [Curves.easeOutQuint] — matching the entry flows
/// and the archive. Modal screens (settings, pass detail) use
/// `MaterialPageRoute(fullscreenDialog: true)` instead, so a slide-up keeps
/// meaning "this is a sheet".
Route<T> studioPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (BuildContext context, _, _) => builder(context),
    transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuint,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
