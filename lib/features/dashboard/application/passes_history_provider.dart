import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true, the Passes tab shows expired (history) items instead of active.
///
/// Owned at the dashboard level so the top-bar History control and
/// [TicketsTab] stay in sync without a local toggle row on the tab.
final passesHistoryFilterProvider = StateProvider<bool>((Ref ref) => false);
