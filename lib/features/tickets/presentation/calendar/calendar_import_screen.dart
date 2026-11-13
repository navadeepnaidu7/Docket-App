import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/docket_button.dart';
import '../../application/calendar_import_controller.dart';
import '../../application/pass_ingest_service.dart';
import '../../application/pass_list_provider.dart';
import '../../domain/calendar_import.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_display.dart';
import '../../domain/pass_ingest.dart';
import '../../domain/pass_status.dart';

/// Settings → Google Calendar. Connect, see sync state, sync now, disconnect, and finish
/// passes the calendar could only partly describe.
class CalendarImportScreen extends ConsumerStatefulWidget {
  const CalendarImportScreen({super.key});

  @override
  ConsumerState<CalendarImportScreen> createState() =>
      _CalendarImportScreenState();
}

class _CalendarImportScreenState extends ConsumerState<CalendarImportScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Consent happens in the system browser. Coming back to the app is the only signal;
    // the server's status, not the browser, decides whether it worked.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(calendarImportProvider.notifier).onAppResumed(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = AppTheme.ink(theme.brightness);
    final Color muted = AppTokens.secondaryLabel(theme.colorScheme);
    final Color bg = isDark
        ? const Color(0xFF0A0A0D)
        : theme.scaffoldBackgroundColor;
    final Color surface = isDark ? const Color(0xFF16161A) : Colors.white;
    final CalendarImportState state = ref.watch(calendarImportProvider);
    final CalendarImportController controller = ref.read(
      calendarImportProvider.notifier,
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 44,
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: ink,
                    ),
                    tooltip: 'Back',
                    onPressed: () {
                      HapticService.select();
                      Navigator.of(context).pop();
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Google Calendar',
                      textAlign: TextAlign.center,
                      style: AppFonts.ui(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    Text(
                      'Docket can add the train, bus and movie bookings that Gmail places on '
                      'your Google Calendar, and keep them up to date. Access is read-only: '
                      'Docket never reads your email and never changes your calendar.',
                      style: AppFonts.ui(
                        fontSize: 15,
                        height: 1.4,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Card(
                      surface: surface,
                      child: _StatusBody(
                        state: state,
                        controller: controller,
                        ink: ink,
                        muted: muted,
                      ),
                    ),
                    if (state.error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.error!,
                          style: AppFonts.ui(
                            fontSize: 14,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                    ],
                    if (state.status?.available ?? false) ...<Widget>[
                      const SizedBox(height: 24),
                      _NeedsDetailsList(
                        surface: surface,
                        ink: ink,
                        muted: muted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.surface, required this.child});

  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTokens.separator(Theme.of(context).colorScheme),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({
    required this.state,
    required this.controller,
    required this.ink,
    required this.muted,
  });

  final CalendarImportState state;
  final CalendarImportController controller;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final CalendarConnectionStatus? status = state.status;
    if (status == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    final TextStyle title = AppFonts.ui(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    final TextStyle body = AppFonts.ui(fontSize: 14, height: 1.4, color: muted);

    if (!status.available) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Not available', style: title),
          const SizedBox(height: 6),
          Text(calendarReasonCopy(status.unavailableReason), style: body),
        ],
      );
    }

    if (state.phase == CalendarImportPhase.authorizing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CupertinoActivityIndicator(),
              const SizedBox(width: 10),
              Expanded(child: Text('Waiting for Google', style: title)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Finish in your browser using the same Google account you sign in to Docket with, '
            'then come back here.',
            style: body,
          ),
          const SizedBox(height: 14),
          DocketButton(
            label: 'Cancel',
            tone: DocketButtonTone.secondary,
            onPressed: controller.cancelAuthorizing,
          ),
        ],
      );
    }

    switch (status.state) {
      case CalendarLinkState.connected:
      case CalendarLinkState.syncing:
        final bool syncing =
            status.state == CalendarLinkState.syncing ||
            state.phase == CalendarImportPhase.syncing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Connected', style: title),
            if (status.accountEmail != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(status.accountEmail!, style: body),
            ],
            const SizedBox(height: 10),
            Text(_syncLine(status, syncing), style: body),
            if (status.importedCount > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '${status.importedCount} ${status.importedCount == 1 ? 'pass' : 'passes'} from your calendar'
                '${status.needsDetailsCount > 0 ? ', ${status.needsDetailsCount} need details' : ''}',
                style: body,
              ),
            ],
            if (status.lastErrorCode != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(calendarReasonCopy(status.lastErrorCode), style: body),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: DocketButton(
                    label: syncing ? 'Syncing' : 'Sync now',
                    leading: syncing
                        ? const CupertinoActivityIndicator(radius: 8)
                        : null,
                    onPressed: state.busy ? null : controller.syncNow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DocketButton(
                    label: 'Disconnect',
                    tone: DocketButtonTone.secondary,
                    onPressed: state.busy
                        ? null
                        : () => _confirmDisconnect(context),
                  ),
                ),
              ],
            ),
          ],
        );
      case CalendarLinkState.reconnectRequired:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Reconnect needed', style: title),
            const SizedBox(height: 6),
            Text(
              calendarReasonCopy(status.lastErrorCode ?? 'grant_revoked'),
              style: body,
            ),
            const SizedBox(height: 16),
            DocketButton(
              label: 'Reconnect Google Calendar',
              onPressed: state.busy ? null : controller.connect,
            ),
          ],
        );
      case CalendarLinkState.disconnected:
      case CalendarLinkState.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Not connected', style: title),
            const SizedBox(height: 6),
            Text(
              status.lastSuccessfulSyncAt != null
                  ? 'Passes imported earlier stay in your wallet. Connect again to resume syncing.'
                  : 'New bookings usually appear within an hour of the confirmation email.',
              style: body,
            ),
            const SizedBox(height: 16),
            DocketButton(
              label: 'Connect Google Calendar',
              leading: state.phase == CalendarImportPhase.loading
                  ? const CupertinoActivityIndicator(radius: 8)
                  : null,
              onPressed: state.busy ? null : controller.connect,
            ),
          ],
        );
    }
  }

  String _syncLine(CalendarConnectionStatus status, bool syncing) {
    if (syncing) return 'Checking your calendar now';
    final DateTime? last = status.lastSuccessfulSyncAt;
    if (last == null) return 'First sync is queued';
    return 'Last synced ${_relative(last)}';
  }

  static String _relative(DateTime at) {
    final Duration d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    HapticService.select();
    final bool? ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoAlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Docket stops checking your calendar and deletes its access. Passes already '
          'imported stay in your wallet.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.disconnect();
  }
}

/// Imported passes whose event lacked booking details. The rest of the wallet is
/// unaffected; adding a ticket here completes the pass in place.
class _NeedsDetailsList extends ConsumerWidget {
  const _NeedsDetailsList({
    required this.surface,
    required this.ink,
    required this.muted,
  });

  final Color surface;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<WalletPassItem> items =
        ref
            .watch(passListProvider)
            .valueOrNull
            ?.where((WalletPassItem p) => p.importInfo?.canAttachTicket ?? false)
            .toList(growable: false) ??
        const <WalletPassItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Needs details',
          style: AppFonts.ui(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        for (final WalletPassItem item in items) ...<Widget>[
          _Card(
            surface: surface,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        passTitle(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.ui(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Missing ${item.importInfo!.missingLabels.join(', ')}',
                        style: AppFonts.ui(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                DocketButton(
                  label: 'Add ticket',
                  compact: true,
                  expand: false,
                  tone: DocketButtonTone.secondary,
                  onPressed: () => _attach(context, ref, item),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _attach(
    BuildContext context,
    WidgetRef ref,
    WalletPassItem item,
  ) async {
    HapticService.select();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final String? path = picked?.files.single.path;
    if (path == null) return;
    final PassInputCategory category = switch (item.kind) {
      PassKind.train => PassInputCategory.train,
      PassKind.movie => PassInputCategory.movie,
      PassKind.bus => PassInputCategory.bus,
    };
    try {
      await ref
          .read(passIngestServiceProvider)
          .submitFile(
            file: File(path),
            category: category,
            attachToPassId: item.id,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Ticket added to the pass.')),
      );
      await ref.read(calendarImportProvider.notifier).refresh();
    } on PassIngestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not add that ticket. Try again.')),
      );
    }
  }
}
