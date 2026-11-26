import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/theme_time_picker.dart';
import '../../../../shared/widgets/pill_segmented.dart';
import '../../application/profile_avatar_shape_provider.dart';
import 'settings_rows.dart';

// ── Appearance: theme preference + schedule ────────────────────────────────

class ThemeAppearanceBlock extends ConsumerWidget {
  const ThemeAppearanceBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeControllerState themeState = ref.watch(themeControllerProvider);
    final ThemeSettings settings = themeState.settings;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    // Stronger secondary labels in dark mode so the block reads clearly.
    final Color muted = ink.withValues(alpha: isDark ? 0.62 : 0.55);
    final Color titleColor = isDark ? const Color(0xFFF2F2F7) : ink;

    final String? statusSubtitle = _themeStatusSubtitle(themeState);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SettingsRowIcon(
                    icon: Icons.brightness_6_rounded,
                    color: Color(0xFF6E40C9),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Theme',
                      style: AppFonts.ui(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (statusSubtitle != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    statusSubtitle,
                    style: AppFonts.ui(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      color: muted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _ThemeSegmentedControl(
                value: settings.preference,
                onChanged: (AppThemePreference next) {
                  HapticService.select();
                  ref
                      .read(themeControllerProvider.notifier)
                      .setPreference(next);
                },
              ),
            ],
          ),
        ),
        if (settings.preference == AppThemePreference.schedule) ...[
          const SettingsDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Schedule',
                  style: AppFonts.ui(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 10),
                _ScheduleKindSegmented(
                  value: settings.scheduleKind,
                  onChanged: (ScheduleKind kind) {
                    HapticService.select();
                    ref
                        .read(themeControllerProvider.notifier)
                        .setScheduleKind(kind);
                  },
                ),
              ],
            ),
          ),
          if (settings.scheduleKind == ScheduleKind.custom) ...[
            const SettingsDivider(),
            _ThemeTimeRow(
              title: 'Light from',
              minutes: settings.lightStartMinutes,
              onTap: () async {
                final int? picked = await showThemeTimePicker(
                  context: context,
                  title: 'Light from',
                  initialMinutes: settings.lightStartMinutes,
                );
                if (picked == null) return;
                HapticService.select();
                await ref
                    .read(themeControllerProvider.notifier)
                    .setLightStartMinutes(picked);
              },
            ),
            const SettingsDivider(),
            _ThemeTimeRow(
              title: 'Dark from',
              minutes: settings.lightEndMinutes,
              onTap: () async {
                final int? picked = await showThemeTimePicker(
                  context: context,
                  title: 'Dark from',
                  initialMinutes: settings.lightEndMinutes,
                );
                if (picked == null) return;
                HapticService.select();
                await ref
                    .read(themeControllerProvider.notifier)
                    .setLightEndMinutes(picked);
              },
            ),
          ],
        ],
      ],
    );
  }
}

String? _themeStatusSubtitle(ThemeControllerState state) {
  final ThemeSettings s = state.settings;
  if (s.preference == AppThemePreference.light) return 'Always light';
  if (s.preference == AppThemePreference.dark) return 'Always dark';
  if (s.preference == AppThemePreference.system) {
    final Brightness platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final String side = platform == Brightness.dark ? 'Dark' : 'Light';
    return 'Matches device · $side now';
  }

  final int start = s.effectiveLightStartMinutes;
  final int end = s.effectiveLightEndMinutes;
  final String range =
      '${formatMinutesOfDay(start)} – ${formatMinutesOfDay(end)}';

  if (s.scheduleKind == ScheduleKind.custom) {
    return 'Light $range';
  }

  // Sunrise–sunset uses fixed local day window (device clock).
  if (state.resolvedMode == ThemeMode.light) {
    return 'Light until ${formatMinutesOfDay(end)} · $range';
  }
  return 'Dark until ${formatMinutesOfDay(start)} · $range';
}

class _ThemeSegmentedControl extends StatelessWidget {
  const _ThemeSegmentedControl({required this.value, required this.onChanged});

  final AppThemePreference value;
  final ValueChanged<AppThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return PillSegmented<AppThemePreference>(
      value: value,
      segments: const <(AppThemePreference, String)>[
        (AppThemePreference.light, 'Light'),
        (AppThemePreference.dark, 'Dark'),
        (AppThemePreference.system, 'Device'),
        (AppThemePreference.schedule, 'Schedule'),
      ],
      onChanged: onChanged,
    );
  }
}

class _ScheduleKindSegmented extends StatelessWidget {
  const _ScheduleKindSegmented({required this.value, required this.onChanged});

  final ScheduleKind value;
  final ValueChanged<ScheduleKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return PillSegmented<ScheduleKind>(
      value: value,
      segments: const <(ScheduleKind, String)>[
        (ScheduleKind.sunriseSunset, 'Sunrise–sunset'),
        (ScheduleKind.custom, 'Custom'),
      ],
      onChanged: onChanged,
    );
  }
}

class _ThemeTimeRow extends StatelessWidget {
  const _ThemeTimeRow({
    required this.title,
    required this.minutes,
    required this.onTap,
  });

  final String title;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color titleColor = isDark ? const Color(0xFFF2F2F7) : ink;
    final Color muted = ink.withValues(alpha: isDark ? 0.62 : 0.55);

    return SettingsPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.ui(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: titleColor,
                  ),
                ),
              ),
              Text(
                formatMinutesOfDay(minutes),
                style: AppFonts.ui(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: isDark ? 0.55 : 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cycles profile mesh shape: Rounded (squircle) ↔ Circle.
class ProfileAvatarShapeRow extends StatelessWidget {
  const ProfileAvatarShapeRow({
    super.key,
    required this.shape,
    required this.onTap,
  });

  final ProfileAvatarShape shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color muted = ink.withValues(alpha: isDark ? 0.45 : 0.55);

    return SettingsPressScale(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              SettingsRowIcon(
                icon: shape == ProfileAvatarShape.circle
                    ? Icons.circle_outlined
                    : Icons.rounded_corner_rounded,
                color: const Color(0xFFAF52DE),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profile icon shape',
                      style: AppFonts.ui(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                    Text(
                      'Top bar account control',
                      style: AppFonts.ui(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                shape.label,
                style: AppFonts.ui(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: muted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: muted.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
