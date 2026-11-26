import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../notifications/application/notification_preferences_provider.dart';
import '../../../notifications/application/notification_service.dart';
import '../../../notifications/domain/notification_preferences.dart';
import '../../../notifications/presentation/notification_runtime.dart';
import '../../../tickets/domain/pass_status.dart';
import 'settings_rows.dart';

class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({
    super.key,
    required this.surface,
    required this.borderColor,
    required this.isDark,
  });
  final Color surface, borderColor;
  final bool isDark;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);
    ref.watch(notificationStatusProvider);
    final service = ref.read(notificationServiceProvider);
    final signedIn = ref.watch(
      authControllerProvider.select(
        (s) => s.realAccount && s.session.isSignedIn,
      ),
    );
    final push = signedIn && service.gateway.pushAvailable;
    final reason = !signedIn
        ? 'Sign in to receive updates'
        : !service.ready
        ? 'Checking availability'
        : 'Unavailable on this build';
    Widget toggle(
      String title,
      IconData icon,
      bool value,
      void Function(bool) change, {
      bool enabled = true,
      String? subtitle,
    }) => Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SettingsToggleRow(
          icon: icon,
          iconColor: Colors.grey,
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: change,
        ),
      ),
    );
    Future<void> time(bool start) async {
      final minutes = start ? settings.quietStart : settings.quietEnd;
      final chosen = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      );
      if (chosen == null) return;
      final value = chosen.hour * 60 + chosen.minute;
      await controller.set(
        controller.value.copyWith(
          quietStart: start ? value : null,
          quietEnd: start ? null : value,
        ),
      );
    }

    return SettingsSection(
      title: 'Notifications',
      surface: surface,
      borderColor: borderColor,
      isDark: isDark,
      children: [
        toggle(
          'Trip reminders',
          Icons.notifications_outlined,
          settings.tripReminders,
          (v) => controller.set(controller.value.copyWith(tripReminders: v)),
        ),
        if (settings.tripReminders)
          for (final kind in [
            PassKind.movie,
            PassKind.flight,
            PassKind.train,
            PassKind.bus,
          ]) ...[
            const SettingsDivider(),
            SettingsLinkRow(
              icon: switch (kind) {
                PassKind.movie => Icons.movie_outlined,
                PassKind.flight => Icons.flight_outlined,
                PassKind.train => Icons.train_outlined,
                PassKind.bus => Icons.directions_bus_outlined,
              },
              iconColor: Colors.grey,
              title:
                  '${kind.name[0].toUpperCase()}${kind.name.substring(1)} reminder',
              subtitle: _leadLabel(settings.leads[kind]!),
              onTap: () async {
                final minutes = await showModalBottomSheet<int>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final lead
                            in NotificationPreferences.choices[kind]!)
                          ListTile(
                            title: Text(
                              _leadLabel(lead),
                              style: AppFonts.ui(fontSize: 16),
                            ),
                            trailing: lead == settings.leads[kind]
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.pop(ctx, lead),
                          ),
                      ],
                    ),
                  ),
                );
                if (minutes != null) {
                  await controller.set(
                    controller.value.copyWith(
                      leads: {...controller.value.leads, kind: minutes},
                    ),
                  );
                }
              },
            ),
          ],
        const SettingsDivider(),
        toggle(
          'Booking updates',
          Icons.confirmation_number_outlined,
          settings.bookingUpdates,
          (v) => controller.set(controller.value.copyWith(bookingUpdates: v)),
          enabled: push,
          subtitle: push ? null : reason,
        ),
        const SettingsDivider(),
        toggle(
          'Live journey',
          Icons.route_outlined,
          settings.journeyLive,
          (v) => controller.set(controller.value.copyWith(journeyLive: v)),
          enabled: push,
          subtitle: push ? null : reason,
        ),
        const SettingsDivider(),
        toggle(
          'Quiet hours',
          Icons.bedtime_outlined,
          settings.quietEnabled,
          (v) => controller.set(controller.value.copyWith(quietEnabled: v)),
        ),
        if (settings.quietEnabled) ...[
          const SettingsDivider(),
          SettingsLinkRow(
            icon: Icons.schedule,
            iconColor: Colors.grey,
            title: 'Quiet hours start',
            subtitle: NotificationPreferences.clock(settings.quietStart),
            onTap: () => time(true),
          ),
          const SettingsDivider(),
          SettingsLinkRow(
            icon: Icons.schedule,
            iconColor: Colors.grey,
            title: 'Quiet hours end',
            subtitle: NotificationPreferences.clock(settings.quietEnd),
            onTap: () => time(false),
          ),
        ],
        if (service.ready && !service.permitted) ...[
          const SettingsDivider(),
          SettingsLinkRow(
            icon: Icons.notifications_off_outlined,
            iconColor: Colors.grey,
            title: 'Notifications are off',
            subtitle: 'Open system notification settings',
            onTap: () async {
              try {
                await service.gateway.openSettings();
              } catch (_) {}
            },
          ),
        ],
      ],
    );
  }

  static String _leadLabel(int minutes) => minutes == 0
      ? 'Off'
      : minutes < 60
      ? '$minutes min before'
      : '${minutes ~/ 60} ${minutes == 60 ? 'hour' : 'hours'} before';
}
