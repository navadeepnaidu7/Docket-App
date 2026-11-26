/// Shared, testable account departure sequence. For deletion the caller must
/// await the server's 204 before entering this sequence. Local documents are
/// never touched. Once authorized, every cleanup step runs even if one fails.
Future<void> cleanupAccount({
  required Future<void> Function() unregisterPush,
  required Future<void> Function() clearSession,
  required Future<void> Function() clearOfflinePasses,
  required Future<void> Function() clearPendingPasses,
  required Future<void> Function() clearIdentity,
  required Future<void> Function() cancelServerReminders,
  required Future<void> Function() googleSignOut,
}) async {
  for (final step in [
    unregisterPush,
    clearSession,
    clearOfflinePasses,
    clearPendingPasses,
    clearIdentity,
    cancelServerReminders,
    googleSignOut,
  ]) {
    try {
      await step();
    } catch (_) {
      /* Continue local cleanup after departure. */
    }
  }
}
